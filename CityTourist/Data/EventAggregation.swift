import Foundation
import CoreLocation

/// A normalized event is a Place with EventInfo, preserving saved stops and share links.
typealias Event = Place

struct EventQuery: Hashable {
    let center: Coordinate
    let cityID: String
    let start: Date
    let end: Date
    var radiusMeters: Double = 25_000
    var isValid: Bool {
        center.isValid && start.timeIntervalSince1970.isFinite && end.timeIntervalSince1970.isFinite &&
        start <= end && radiusMeters.isFinite && (1...100_000).contains(radiusMeters)
    }
}
struct EventPage {
    let events: [Event]
    let nextCursor: String?
}
protocol EventProvider {
    var providerID: String { get }
    func page(query: EventQuery, cursor: String?) async throws -> EventPage
}

struct EventFeed {
    let query: EventQuery
    var events: [Event] = []
    var cursors: [String: String] = [:]
    var completed = Set<String>()
    var failed = Set<String>()
    var successful = Set<String>()
}

struct EventAggregator {
    let providers: [any EventProvider]
    func next(_ feed: EventFeed) async -> EventFeed {
        var result = feed
        let active = providers.filter { !feed.completed.contains($0.providerID) }
        await withTaskGroup(of: (String, EventPage?).self) { group in
            for provider in active {
                group.addTask {
                    do {
                        return (provider.providerID, try await provider.page(query: feed.query, cursor: feed.cursors[provider.providerID]))
                    } catch { return (provider.providerID, nil) }
                }
            }
            for await (id, page) in group {
                guard !Task.isCancelled else { continue }
                guard let page else { result.failed.insert(id); continue }
                result.failed.remove(id); result.successful.insert(id)
                result.events.append(contentsOf: page.events)
                if let cursor = page.nextCursor, cursor != feed.cursors[id] {
                    result.cursors[id] = cursor
                } else { result.completed.insert(id); result.cursors[id] = nil }
            }
        }
        result.events = Self.normalized(result.events)
        return result
    }

    static func normalized(_ events: [Event]) -> [Event] {
        func folded(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
        }
        // Stable provider preference makes results independent of network completion order.
        let sorted = events.sorted {
            let lhs = "\($0.event?.localDate ?? "")|\(String(format: "%04d", $0.event?.startMinute ?? 0))"
            let rhs = "\($1.event?.localDate ?? "")|\(String(format: "%04d", $1.event?.startMinute ?? 0))"
            if lhs != rhs { return lhs < rhs }
            if $0.eventProvider != $1.eventProvider { return $0.eventProvider == "Ticketmaster" }
            return $0.id < $1.id
        }
        var output: [Event] = [], seen = Set<String>()
        for event in sorted {
            guard let info = event.event, event.coordinate.isValid, (0..<1440).contains(info.startMinute),
                  seen.insert(event.id).inserted else { continue }
            let duplicate = output.contains { prior in
                guard let other = prior.event, other.localDate == info.localDate,
                      abs(other.startMinute - info.startMinute) <= 10,
                      folded(prior.name) == folded(event.name) else { return false }
                let distance = CLLocation(latitude: event.coordinate.latitude, longitude: event.coordinate.longitude)
                    .distance(from: CLLocation(latitude: prior.coordinate.latitude, longitude: prior.coordinate.longitude))
                return distance <= 300 && (folded(info.venue) == folded(other.venue) || distance <= 100)
            }
            if !duplicate { output.append(event) }
        }
        return output
    }
}

struct EventbriteService: EventProvider {
    let providerID = "eventbrite"
    let endpoint: URL
    var session: URLSession = .shared
    init?(session: URLSession = .shared) {
        guard let raw = Secrets.eventbriteProxyURL, let url = URL(string: raw),
              url.scheme == "https", url.host != nil else { return nil }
        self.endpoint = url; self.session = session
    }
    init(endpoint: URL, session: URLSession) { self.endpoint = endpoint; self.session = session }

    func page(query: EventQuery, cursor: String?) async throws -> EventPage {
        guard query.isValid else { throw URLError(.badURL) }
        let iso = ISO8601DateFormatter()
        var parameters = [
            URLQueryItem(name: "latitude", value: String(query.center.latitude)),
            URLQueryItem(name: "longitude", value: String(query.center.longitude)),
            URLQueryItem(name: "radiusMeters", value: String(query.radiusMeters)),
            URLQueryItem(name: "start", value: iso.string(from: query.start)),
            URLQueryItem(name: "end", value: iso.string(from: query.end))
        ]
        if let cursor { parameters.append(URLQueryItem(name: "cursor", value: cursor)) }
        let data = try await get(parameters)
        let wire = try JSONDecoder().decode(Response.self, from: data)
        return EventPage(events: wire.events.compactMap { $0.value?.place(cityID: query.cityID) }, nextCursor: wire.nextCursor)
    }
    func event(id: String, cityID: String) async throws -> Place {
        let data = try await get([URLQueryItem(name: "id", value: id)])
        let wire = try JSONDecoder().decode(Response.self, from: data)
        guard let event = wire.events.compactMap(\.value).first(where: { $0.id == id })?.place(cityID: cityID) else { throw URLError(.cannotParseResponse) }
        return event
    }
    private func get(_ parameters: [URLQueryItem]) async throws -> Data {
        guard endpoint.scheme == "https" else { throw URLError(.badURL) }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = parameters
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(for: URLRequest(url: url, timeoutInterval: 20))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count < 5_000_000 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
    private struct Response: Decodable {
        let events: [LossyElement<WireEvent>]
        let nextCursor: String?
    }
    private struct WireEvent: Decodable {
        let id: String?
        let name: String?
        let localDate: String?
        let startMinute: Int?
        let venue: String?
        let latitude: Double?
        let longitude: Double?
        let ticketURL: String?
        let imageURL: String?
        func place(cityID: String) -> Place? {
            guard let id, !id.isEmpty, let name, !name.isEmpty, let localDate,
                  let startMinute, (0..<1440).contains(startMinute), let venue,
                  let latitude, let longitude else { return nil }
            let coordinate = Coordinate(latitude: latitude, longitude: longitude)
            let date = DateFormatter(); date.locale = Locale(identifier: "en_US_POSIX")
            date.dateFormat = "yyyy-MM-dd"; date.isLenient = false
            guard coordinate.isValid, let parsed = date.date(from: localDate), date.string(from: parsed) == localDate else { return nil }
            func safeURL(_ value: String?) -> URL? {
                guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil else { return nil }
                return url
            }
            return Place(id: "eb:\(id)", name: name, cityID: cityID, category: .activity,
                         neighborhood: venue, rating: 0, reviewCount: 0, priceLevel: 1, typicalMinutes: 120,
                         blurb: venue, about: "", coordinate: coordinate, tags: ["Eventbrite"],
                         imageURL: safeURL(imageURL), event: EventInfo(ticketURL: safeURL(ticketURL), localDate: localDate,
                         startMinute: startMinute, venue: venue, kind: L10n.text("Events"), price: nil))
        }
    }
}
