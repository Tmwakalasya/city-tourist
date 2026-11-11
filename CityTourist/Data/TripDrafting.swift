import Foundation
import Observation

/// What the model is told about a place: public facts under a short id.
/// Photos (whose URLs carry a key), saved places, other trips and the
/// traveller's location never leave the app.
struct TripDraftPlace: Encodable {
    /// "p1", "p2"… in the order sent. Short ids cost less than Google's and
    /// can't be half-remembered into a different real place.
    let id: String
    let name: String
    let kind: String
    let area: String
    let about: String
    let rating: Double?
    let reviews: Int
    /// A typical visit.
    let minutes: Int
    /// Weekdays it's shut all day, so fewer drafts need fixing afterwards.
    let closed: [String]

    init(place: Place, number: Int) {
        id = "p\(number)"
        name = String(place.name.prefix(120))
        kind = place.category.rawValue
        area = String(place.neighborhood.prefix(80))
        about = String((place.blurb.isEmpty ? place.about : place.blurb).prefix(140))
        rating = place.reviewCount > 0 ? place.rating : nil
        reviews = max(0, place.reviewCount)
        minutes = min(1440, place.typicalMinutes)
        closed = place.weeklyHours.map { hours in
            (0..<7).filter { hours.day($0).isClosedAllDay }.map { HoursNote.weekdayNames[$0] }
        } ?? []
    }
}

/// Asks Claude to draft a trip from the traveller's own words and a list of
/// real places. The draft is only a proposal: `TripBuilder` checks every stop
/// against opening hours and travel time before anyone sees it.
///
/// The request goes to City Tourist's own server (`launch/functions/api/ai`),
/// which holds the Claude key, the prompt and the model. No key is in the app.
struct TripDraftService {

    struct Draft: Equatable {
        var summary: String
        var days: [TripBuilder.DraftDay]
    }

    enum Failure: LocalizedError, Equatable {
        case invalidReply
        /// This phone has used its allowance for now; see `RequestBudget`.
        case rateLimited
        /// The model's safeguards turned the request down.
        case declined
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case .invalidReply: "The plan came back in a form the app couldn’t read. Try again."
            case .rateLimited: "You’ve reached today’s AI limit on this device. Try again tomorrow, or build a starter plan without it."
            case .declined: "That request couldn’t be planned. Try describing the trip another way."
            case .rejected(let message): message
            }
        }
    }

    static let endpoint = Secrets.aiBaseURL.appending(path: "trip")
    /// Enough for a week of full days with a choice left over.
    static let maxCandidates = 60
    /// Longer trips get their first week drafted; the rest stays open.
    static let maxDays = 7

    private let endpoint: URL
    private let session: URLSession
    private let budget: RequestBudget

    /// The app's own: the shared session and this phone's daily allowance.
    /// Tests pass a stubbed session and their own budget.
    init(endpoint: URL = TripDraftService.endpoint, session: URLSession = .shared,
         budget: RequestBudget = .aiConcierge) {
        self.endpoint = endpoint
        self.session = session
        self.budget = budget
    }

    // MARK: Candidates

    /// Search terms worth running for a request, beyond the city's own feed.
    static func searchTerms(for request: String) -> [String] {
        Array(AIRecommendationService.searchQueries(for: request).dropFirst().prefix(3))
    }

    /// The places offered to the model: what the request's own searches found
    /// first, then the city's best of each kind in turn, so there are always
    /// places to eat among the sights.
    static func candidates(searched: [Place], catalog: [Place], limit: Int = maxCandidates) -> [Place] {
        var seen = Set<String>()
        func usable(_ place: Place) -> Bool {
            place.event == nil && place.typicalMinutes > 0 && !seen.contains(place.id)
        }
        var result: [Place] = []
        for place in searched where usable(place) && result.count < limit / 3 {
            seen.insert(place.id)
            result.append(place)
        }

        // Sparse ratings shrink toward 4.0, as in `FirstDayPlanner`.
        func quality(_ place: Place) -> Double {
            let count = Double(max(0, place.reviewCount))
            return (place.rating * count + 4 * 50) / (count + 50)
        }
        var byKind = Dictionary(uniqueKeysWithValues: PlaceCategory.allCases.map { kind in
            (kind, catalog.filter { $0.category == kind && usable($0) }
                .sorted { (quality($0), $0.id) > (quality($1), $1.id) })
        })
        // Food comes round twice: every day needs two meals but only so many sights.
        let turns = [PlaceCategory.food] + PlaceCategory.allCases
        while result.count < limit, byKind.values.contains(where: { !$0.isEmpty }) {
            for kind in turns where byKind[kind]?.isEmpty == false && result.count < limit {
                guard let place = byKind[kind]?.removeFirst() else { continue }
                if seen.insert(place.id).inserted { result.append(place) }
            }
        }
        return result
    }

    // MARK: Draft

    /// One request, one allowance. `candidates` beyond `maxCandidates` and
    /// `dates` beyond `maxDays` aren't sent.
    func draft(request: String, city: City, dates: [Date], candidates: [Place],
               language: String = "English", calendar: Calendar = .current) async throws -> Draft {
        guard budget.spend() else { throw Failure.rateLimited }
        let places = Array(candidates.prefix(Self.maxCandidates))

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        // The model thinks before it answers and the answer is a whole trip.
        urlRequest.timeoutInterval = 90
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try Self.body(request: request, city: city,
                                            dates: Array(dates.prefix(Self.maxDays)),
                                            places: places, language: language, calendar: calendar)

        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            // Never reached the server, so nothing was spent.
            budget.refund()
            throw error
        }
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidReply }
        guard http.statusCode == 200 else { throw Self.failure(status: http.statusCode) }

        guard data.count <= 65_536, let reply = try? JSONDecoder().decode(Reply.self, from: data)
        else { throw Failure.invalidReply }
        return Self.resolve(reply, places: places)
    }

    /// Only a short message of our own is shown, never the server's.
    private static func failure(status: Int) -> Failure {
        switch status {
        // The model's safeguards turned the request down.
        case 422: .declined
        // Everyone's allowance for the day, or this network's for the hour.
        case 429: .rejected("The trip builder has had all the requests it can take for now. Try again later.")
        case 500...599: .rejected("The trip builder is busy right now. Try again in a minute.")
        default: .rejected("The trip couldn’t be drafted. Try again.")
        }
    }

    // MARK: Wire format

    struct Reply: Decodable {
        struct Day: Decodable {
            struct Stop: Decodable {
                let id: String
                let start: String
                let reason: String
            }
            let theme: String
            let stops: [Stop]
        }
        let summary: String
        let days: [Day]
    }

    /// Short ids back to places and clock times to minutes. A stop with an id
    /// that wasn't sent, or a time that isn't one, is left out; `TripBuilder`
    /// deals with repeats and everything else.
    static func resolve(_ reply: Reply, places: [Place]) -> Draft {
        let days = reply.days.map { day in
            TripBuilder.DraftDay(
                theme: String(day.theme.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60)),
                stops: day.stops.compactMap { stop in
                    guard stop.id.hasPrefix("p"), let number = Int(stop.id.dropFirst()),
                          places.indices.contains(number - 1),
                          let start = minutes(fromClock: stop.start) else { return nil }
                    return TripBuilder.DraftStop(
                        placeID: places[number - 1].id, start: start,
                        reason: String(stop.reason.trimmingCharacters(in: .whitespacesAndNewlines).prefix(160)))
                })
        }
        return Draft(summary: String(reply.summary.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240)),
                     days: days)
    }

    /// "09:30" → 570. Nil for anything that isn't a time of day.
    static func minutes(fromClock clock: String) -> Int? {
        let parts = clock.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    private static func body(request: String, city: City, dates: [Date], places: [Place],
                             language: String, calendar: Calendar) throws -> Data {
        struct Payload: Encodable {
            struct Day: Encodable {
                let day: Int
                let date: String
                let weekday: String
            }
            let request: String
            let city: String
            /// The app's language, which the plan's own words are written in.
            let language: String
            let days: [Day]
            let places: [TripDraftPlace]
        }
        let payload = Payload(
            request: request,
            city: city.displayName,
            language: language,
            days: dates.enumerated().map { index, date in
                let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
                return .init(day: index + 1,
                             date: String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0),
                             weekday: HoursNote.weekdayNames[(parts.weekday ?? 1) - 1])
            },
            places: places.enumerated().map { TripDraftPlace(place: $1, number: $0 + 1) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(payload)
    }
}

/// One build of a trip: find places, draft, check. Each screen owns its own,
/// and starting again discards a reply that arrives late.
@MainActor
@Observable
final class TripBuilding {
    enum Phase: Equatable {
        case idle, finding, drafting, checking, ready
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var result: TripBuilder.Result?
    private(set) var summary = ""
    /// False when the plan is a starter from the places alone.
    private(set) var followsRequest = false
    /// Kept after a failure, so a starter plan doesn't search again.
    private(set) var candidates: [Place] = []
    private var generation = UUID()

    var isWorking: Bool { [.finding, .drafting, .checking].contains(phase) }

    func reset() {
        generation = UUID()
        phase = .idle
        result = nil
        summary = ""
        followsRequest = false
    }

    /// `draft` is nil when there's no model to ask; the plan is then a starter.
    func run(builder: TripBuilder,
             find: () async throws -> [Place],
             draft: (([Place]) async throws -> TripDraftService.Draft)?) async {
        reset()
        let current = generation
        phase = .finding
        do {
            let found = try await find()
            guard current == generation, !Task.isCancelled else { return }
            candidates = found
            guard !found.isEmpty else {
                phase = .failed("No places could be loaded for this city. Check your connection and try again.")
                return
            }
            guard let draft else {
                useStarter(builder: builder)
                return
            }
            phase = .drafting
            let drafted = try await draft(found)
            guard current == generation, !Task.isCancelled else { return }
            phase = .checking
            let built = builder.build(drafted.days, from: found)
            guard built.stopCount > 0 else {
                phase = .failed("Nothing in that plan fit the opening hours. Try again, or build a starter plan.")
                return
            }
            result = built
            summary = drafted.summary
            followsRequest = true
            phase = .ready
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    /// A plan from the places already found, without the model.
    func useStarter(builder: TripBuilder) {
        let built = builder.starter(among: candidates)
        guard built.stopCount > 0 else {
            phase = .failed("No day fits these places’ opening hours. Try other dates.")
            return
        }
        result = built
        summary = ""
        followsRequest = false
        phase = .ready
    }

    func remove(_ stop: TripBuilder.Stop) {
        guard var current = result else { return }
        for index in current.days.indices {
            current.days[index].stops.removeAll { $0.id == stop.id }
        }
        result = current
    }
}
