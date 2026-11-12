import Foundation

/// How good a place is for a visitor, as one number every list shares.
///
/// Star ratings alone put a 4.9 from three hundred reviews above a landmark
/// with a hundred thousand. Review counts alone give every city the same
/// crowded top ten. So the score is the rating, pulled toward a typical one
/// until enough reviews back it, plus a bonus for popularity that grows ever
/// more slowly: a hundred thousand reviews isn't a hundred times better than
/// a thousand. How much popularity counts depends on the kind of place:
/// visitors want the famous landmarks, but the best meal is often somewhere
/// small.
enum PlaceRanking {
    /// What a place is taken to be before it has reviews.
    static let typicalRating = 4.3
    /// The number of reviews at which a place's own rating counts as much as
    /// the typical one.
    static let reviewsToTrust = 250.0

    static func popularityWeight(_ category: PlaceCategory) -> Double {
        switch category {
        case .attraction, .nightlife: 0.15
        case .museum, .nature, .activity: 0.12
        case .food: 0.10
        case .relaxation: 0.05
        }
    }

    static func score(_ place: Place) -> Double {
        let count = Double(max(0, place.reviewCount))
        let rating = count > 0 ? min(5, max(0, place.rating)) : typicalRating
        let trusted = (rating * count + typicalRating * reviewsToTrust) / (count + reviewsToTrust)
        return trusted + popularityWeight(place.category) * log10(1 + count)
    }

    /// Best first. Ties go by id, so the order never shuffles between loads.
    static func ranked(_ places: [Place]) -> [Place] {
        places.map { (place: $0, score: score($0)) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.place.id < $1.place.id }
            .map(\.place)
    }

    /// How much each place of a kind already listed costs the next one.
    static let repeatCost = 0.1

    /// For a list of every kind: best first, but each place of a kind already
    /// listed costs the next one of that kind a little, so the list doesn't
    /// run to ten landmarks before the first meal.
    static func mixed(_ places: [Place]) -> [Place] {
        var queues = Dictionary(grouping: ranked(places), by: \.category)
        var listed: [PlaceCategory: Int] = [:]
        var result: [Place] = []
        result.reserveCapacity(places.count)
        func adjusted(_ kind: PlaceCategory) -> Double? {
            guard let head = queues[kind]?.first else { return nil }
            return score(head) - repeatCost * Double(listed[kind, default: 0])
        }
        while true {
            var best: (kind: PlaceCategory, value: Double, id: String)?
            for kind in PlaceCategory.allCases {
                guard let value = adjusted(kind), let id = queues[kind]?.first?.id else { continue }
                if best == nil || value > best!.value || (value == best!.value && id < best!.id) {
                    best = (kind, value, id)
                }
            }
            guard let kind = best?.kind else { return result }
            result.append(queues[kind]!.removeFirst())
            listed[kind, default: 0] += 1
        }
    }
}
