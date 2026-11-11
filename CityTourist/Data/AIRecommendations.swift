import Foundation
import CoreLocation
import Observation

/// Only public place facts leave the app. Photos (whose URLs contain a key),
/// saved trips and the user's location are deliberately absent from this DTO.
struct AIPlaceCandidate: Encodable {
    let id: String
    let name: String
    let category: String
    let area: String
    let description: String
    let tags: [String]
    let rating: Double?
    let reviewCount: Int
    let distanceMetresFromCentre: Int
    let isOpenNow: Bool?
    let todayHours: String?
    let typicalMinutes: Int

    init(place: Place, city: City) {
        id = place.id
        name = String(place.name.prefix(200))
        category = place.category.title
        area = String(place.neighborhood.prefix(250))
        tags = Array(place.tags.prefix(6)).map { String($0.prefix(60)) }
        rating = place.reviewCount > 0 ? place.rating : nil
        reviewCount = max(0, place.reviewCount)
        let centre = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        distanceMetresFromCentre = Int(centre.distance(from: location).rounded())
        isOpenNow = place.isOpenNow
        todayHours = place.todayHours.map { String($0.prefix(120)) }
        typicalMinutes = max(15, min(600, place.typicalMinutes))
        description = Self.buildDescription(for: place)
        // Place.priceLevel currently defaults to 2 when Google omits it.
        // Do not present that fallback to the model as a verified price.
    }

    private static func buildDescription(for place: Place) -> String {
        let base = (place.about.isEmpty ? place.blurb : place.about).trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        if !base.isEmpty {
            parts.append(base.hasSuffix(".") ? base : "\(base).")
        }
        let lowerTags = place.tags.map { $0.localizedLowercase }
        if lowerTags.contains(where: { $0.contains("night club") || $0.contains("nightclub") }) {
            parts.append("High-energy nightclub and late-night dance venue in \(place.neighborhood).")
        } else if place.category == .nightlife {
            parts.append("Evening nightlife, drinks, and social spot in \(place.neighborhood).")
        }
        if place.reviewCount >= 1_000 {
            // The count goes in its own field; here it would be quoted back.
            parts.append("Flagship city icon and premier hotspot.")
        } else if place.reviewCount >= 300 {
            parts.append("Well-known, popular local standout.")
        }
        if let hours = place.todayHours, !hours.isEmpty {
            parts.append("Today's hours: \(hours).")
        }
        return String(parts.joined(separator: " ").prefix(500))
    }
}

struct AIPlacePick: Identifiable {
    var id: String { place.id }
    let place: Place
    let reason: String
    let caveat: String
}

struct AIRecommendationResult {
    let picks: [AIPlacePick]
    let summary: String
}

/// Asks City Tourist's own server (`launch/functions/api/ai`) to pick from
/// places the app found. The server holds the Claude key, the prompt and the
/// model; no key is in the app.
struct AIRecommendationService {
    var session: URLSession = .shared
    var budget: RequestBudget? = nil
    var endpoint = AIRecommendationService.endpoint
    static let endpoint = Secrets.aiBaseURL.appending(path: "concierge")

    struct Reply: Decodable {
        struct Pick: Decodable {
            let id: String
            let reason: String
            let caveat: String
        }
        let picks: [Pick]
        let summary: String
    }

    enum Failure: LocalizedError {
        case unavailable, invalidReply, rateLimited, rejected(String)
        var errorDescription: String? {
            switch self {
            case .unavailable: return "AI Concierge can’t be reached right now. Check your connection and try again."
            case .invalidReply: return "The suggestions couldn’t be verified against these places. Please try again."
            case .rateLimited: return "AI Concierge has reached today’s 15-search beta limit on this device. Try again tomorrow."
            case .rejected(let message): return message
            }
        }
    }

    static func isRateLimited(_ error: Error) -> Bool {
        if case Failure.rateLimited = error { return true }
        return false
    }

    /// Expands a natural-language craving or mood into focused search terms
    /// so Google Places Text Search returns iconic venues and scene leaders
    /// instead of literal full-sentence keyword matches.
    static func searchQueries(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let lower = trimmed.localizedLowercase

        var extra: [String] = []
        let isClubVibe = ["club", "nightlife", "party", "dance", "dancing", "dj", "night out", "go out", "going out", "late night", "after hours", "rave", "liv", "vip", "bottle", "turnt", "lit"].contains { lower.contains($0) }
        let isBarVibe = ["bar", "cocktail", "drink", "rooftop", "lounge", "speakeasy", "happy hour", "pub"].contains { lower.contains($0) }
        let isWineVibe = ["wine", "vino", "sommelier"].contains { lower.contains($0) }

        if isClubVibe {
            extra.append("famous nightclub dance club DJ")
            extra.append("iconic nightlife club lounge")
            extra.append("popular late night club party")
        } else if isWineVibe {
            extra.append("best wine bar tasting room")
        } else if isBarVibe {
            extra.append("best cocktail bar rooftop lounge")
            extra.append("iconic bar speakeasy nightlife")
        } else if lower.contains("night") || lower.contains("tonight") || lower.contains("evening") {
            extra.append("iconic nightlife club cocktail bar")
            extra.append("famous late night lounge club")
        }

        if ["coffee", "cafe", "café", "pastry", "pastries", "bakery", "espresso", "matcha", "croissant", "brunch", "breakfast"].contains(where: { lower.contains($0) }) {
            extra.append("specialty coffee bakery cafe")
            extra.append("iconic local cafe brunch")
        }
        if ["culture", "museum", "art", "gallery", "history", "rain", "indoor", "architecture"].contains(where: { lower.contains($0) }) {
            extra.append("museum art gallery cultural landmark")
        }
        if ["outdoor", "park", "walk", "view", "scenic", "sunset", "golden hour", "beach", "waterfront"].contains(where: { lower.contains($0) }) {
            extra.append("scenic viewpoint park garden beach")
        }
        if ["food", "lunch", "dinner", "eat", "restaurant", "dining", "local", "bistro", "seafood", "steak", "taco", "sushi", "cuban", "date night"].contains(where: { lower.contains($0) }) {
            extra.append("iconic local restaurant best dining")
            extra.append("famous must try restaurant")
        }
        if ["quiet", "read", "relax", "calm", "hidden"].contains(where: { lower.contains($0) }) {
            extra.append("quiet garden bookshop cafe")
        }

        var result = [trimmed]
        for item in extra where !result.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
            result.append(item)
            if result.count == 4 { break }
        }
        return result
    }

    /// Round-robin interleaves multiple search batches by rank index so the #1
    /// Google match from each targeted query lands at the front of the pool.
    static func interleave(_ batches: [[Place]]) -> [Place] {
        var result: [Place] = []
        var seen = Set<String>()
        let maxCount = batches.map(\.count).max() ?? 0
        for index in 0..<maxCount {
            for batch in batches where index < batch.count {
                let place = batch[index]
                if seen.insert(place.id).inserted {
                    result.append(place)
                }
            }
        }
        return result
    }

    /// Ranks candidates so iconic, scene-defining venues (high review counts +
    /// top Google relevance) and strong local favourites beat 1-review flukes
    /// or unrelated catalog items.
    static func rankCandidates(_ primary: [Place], catalog: [Place], query: String,
                               openNowOnly: Bool = false, maxDistanceKm: Double? = nil,
                               city: City, excluding: Set<String> = []) -> [Place] {
        let centre = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
        var primaryRanks: [String: Int] = [:]
        for (idx, place) in primary.enumerated() where primaryRanks[place.id] == nil {
            primaryRanks[place.id] = idx
        }
        let lowerQuery = query.localizedLowercase
        let words = Set(
            lowerQuery
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        )

        var seen = Set<String>()
        let combined = (primary + catalog).filter { place in
            guard !excluding.contains(place.id), seen.insert(place.id).inserted else { return false }
            if openNowOnly, place.isOpenNow == false { return false }
            if let maxDistanceKm {
                let loc = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                if centre.distance(from: loc) > maxDistanceKm * 1000 { return false }
            }
            return true
        }

        return combined.sorted { a, b in
            score(a, primaryRanks: primaryRanks, lowerQuery: lowerQuery, words: words)
                > score(b, primaryRanks: primaryRanks, lowerQuery: lowerQuery, words: words)
        }
    }

    private static func score(_ place: Place, primaryRanks: [String: Int], lowerQuery: String, words: Set<String>) -> Double {
        let isNightlifeQuery = ["club", "nightlife", "party", "dance", "dancing", "dj", "night", "bar", "cocktail", "rooftop", "lounge", "go out", "going out", "liv", "vip", "late"].contains { lowerQuery.contains($0) }
        let isClubSpecific = ["club", "nightlife", "party", "dance", "dancing", "dj", "rave", "liv", "vip", "bottle", "after hours", "go out", "going out"].contains { lowerQuery.contains($0) }

        let text = "\(place.name) \(place.blurb) \(place.about) \(place.category.title) \(place.tags.joined(separator: " "))".localizedLowercase

        // Filter out false-positive "clubs" (golf/country/yacht/wholesale) on nightlife searches.
        if isNightlifeQuery {
            let nonNightlifeClub = ["golf", "country club", "yacht club", "tennis", "sam's club", "sams club", "wholesale", "boys & girls", "rotary"].contains { text.contains($0) }
            if nonNightlifeClub { return -50 }
        }

        // 1. Primary search matches always rank in a higher tier than fallback catalog items.
        let searchTier: Double
        if let rank = primaryRanks[place.id] {
            searchTier = 20.0 + max(0, 2.0 - Double(rank) * 0.08)
        } else {
            searchTier = 0.0
        }

        // 2. Institutional prominence (review count) + rating quality.
        // World-famous nightclubs (like LIV or Club Space) often carry 3.5–4.1 ratings
        // due to door policies/cover charges alongside 2,000+ reviews.
        let prominence = place.reviewCount > 0 ? log10(Double(max(1, place.reviewCount))) * 1.15 : 0.0
        let quality: Double
        if place.reviewCount == 0 {
            quality = 2.4
        } else if isNightlifeQuery && place.category == .nightlife && place.rating >= 3.4 {
            quality = min(4.5, place.rating) * 0.45
        } else {
            let weight = min(1.0, log10(Double(max(1, place.reviewCount)) + 1) / 3.0)
            quality = place.rating * (0.60 + 0.40 * weight)
        }

        // 3. Category & tag alignment with user intent.
        var intentBoost = 0.0
        if isNightlifeQuery && place.category == .nightlife {
            intentBoost += 2.5
        }
        if isClubSpecific && (text.contains("night club") || text.contains("nightclub")) {
            intentBoost += 2.5
        }

        let keywordHits = Double(words.filter { text.contains($0) }.count) * 0.45
        return searchTier + prominence + quality + intentBoost + keywordHits
    }

    func recommend(query: String, city: City, candidates: [Place]) async throws -> AIRecommendationResult {
        try Task.checkCancellation()
        let activeBudget = budget ?? (session === URLSession.shared ? .aiConcierge : .unlimited)
        guard activeBudget.spend() else { throw Failure.rateLimited }

        let bounded = Array(candidates.prefix(20))
        let candidateDTOs = bounded.map { AIPlaceCandidate(place: $0, city: city) }

        struct Payload: Encodable {
            let query: String
            let city: String
            let candidates: [AIPlaceCandidate]
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Payload(
            query: query, city: city.displayName,
            candidates: candidateDTOs
        ))
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError where [.cannotConnectToHost, .cannotFindHost, .notConnectedToInternet].contains(error.code) {
            activeBudget.refund()
            throw Failure.unavailable
        }
        catch let error as URLError {
            activeBudget.refund()
            throw error
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw Failure.invalidReply }
        guard http.statusCode == 200 else {
            if TripDraftService.neverReachedTheModel(status: http.statusCode) { activeBudget.refund() }
            throw Self.failure(status: http.statusCode)
        }
        guard data.count <= 16_384, let reply = try? JSONDecoder().decode(Reply.self, from: data) else {
            throw Failure.invalidReply
        }
        return try Self.resolve(reply, candidates: bounded)
    }

    /// Only a short message of our own is shown, never the server's.
    private static func failure(status: Int) -> Failure {
        switch status {
        // Everyone's allowance for the day, or this network's for the hour.
        case 429: .rejected("AI Concierge has had all the requests it can take for now. Try again later.")
        case 500...599: .rejected("AI Concierge is busy right now. Try again in a minute.")
        default: .rejected("Suggestions couldn’t load. Please try again.")
        }
    }

    /// An invented, repeated or unsent id invalidates the whole response.
    static func resolve(_ reply: Reply, candidates: [Place]) throws -> AIRecommendationResult {
        guard reply.picks.count <= 3, reply.summary.count <= 240 else { throw Failure.invalidReply }
        var seen = Set<String>()
        let picks = try reply.picks.map { pick -> AIPlacePick in
            guard seen.insert(pick.id).inserted,
                  let place = candidates.first(where: { $0.id == pick.id }),
                  !pick.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  pick.reason.count <= 240, pick.caveat.count <= 180 else { throw Failure.invalidReply }
            return AIPlacePick(place: place, reason: pick.reason, caveat: pick.caveat)
        }
        return AIRecommendationResult(picks: picks, summary: reply.summary)
    }
}

/// Each sheet owns its request. Editing, dismissing, or replacing a request
/// invalidates old work even if an underlying operation ignores cancellation.
@MainActor @Observable
final class AIRecommendations {
    enum Phase: Equatable { case idle, searching, choosing, ready, failed(String) }
    private(set) var phase: Phase = .idle
    private(set) var picks: [AIPlacePick] = []
    private(set) var summary = ""
    private var generation = UUID()

    var isLoading: Bool { phase == .searching || phase == .choosing }

    func reset() {
        generation = UUID()
        phase = .idle
        picks = []
        summary = ""
    }

    func run(query: String,
             find: (String) async throws -> [Place],
             choose: (String, [Place]) async throws -> AIRecommendationResult) async {
        reset()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...300).contains(trimmed.count) else {
            phase = .failed("Describe what you’d like in 3–300 characters.")
            return
        }
        let current = generation
        phase = .searching
        do {
            var seen = Set<String>()
            let candidates = try await find(trimmed).filter { seen.insert($0.id).inserted }
            guard current == generation, !Task.isCancelled else { return }
            guard !candidates.isEmpty else {
                summary = "No places came back for that search. Try a simpler description or another idea."
                phase = .ready
                return
            }
            phase = .choosing
            let result = try await choose(trimmed, Array(candidates.prefix(20)))
            guard current == generation, !Task.isCancelled else { return }
            picks = result.picks
            summary = result.summary
            phase = .ready
        } catch {
            guard current == generation, !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }
}
