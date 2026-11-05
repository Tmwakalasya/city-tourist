import Foundation
import Observation

/// Short videos for each place page, from YouTube.
///
/// A look-up spends 100 of the key's 10,000 daily units, so results are kept
/// on disk by place id for a week (YouTube's policies allow keeping API data
/// up to 30 days), and a place with none is asked about again the next day.
/// Only YouTube's data and Google's place id are stored, never place content.
@MainActor
@Observable
final class PlaceShorts {
    enum State: Equatable {
        case loading
        case loaded([PlaceShort])
        case failed(String)
    }

    struct Entry: Codable {
        var fetched: Date
        var shorts: [PlaceShort]
    }

    static let keepFor: TimeInterval = 7 * 24 * 60 * 60
    static let keepEmptyFor: TimeInterval = 24 * 60 * 60

    private var states: [String: State] = [:]
    @ObservationIgnored private var cache: [String: Entry] = [:]
    @ObservationIgnored private let makeService: () -> YouTubeService?
    @ObservationIgnored private let cacheURL: URL?
    @ObservationIgnored private let now: () -> Date

    /// Without a key there are no videos, only the links out.
    let isAvailable: Bool

    /// Tests pass a client wired to a stubbed session, and no cache file or
    /// one of their own.
    init(makeService: @escaping () -> YouTubeService? = { YouTubeService() },
         cacheURL: URL? = URL.cachesDirectory.appending(path: "youtube-shorts.json"),
         now: @escaping () -> Date = Date.init) {
        self.makeService = makeService
        self.cacheURL = cacheURL
        self.now = now
        isAvailable = makeService() != nil
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data) {
            cache = stored
        }
    }

    func state(for place: Place) -> State? { states[place.id] }

    /// From the cache while it's fresh, otherwise one look-up. Leaving the
    /// page cancels it without recording a failure.
    func load(_ place: Place) async {
        guard place.event == nil else { return }
        switch states[place.id] {
        case .loading, .loaded: return
        case .failed, nil: break
        }
        if let entry = cache[place.id], isFresh(entry) {
            states[place.id] = .loaded(entry.shorts)
            return
        }
        guard let service = makeService() else { return }

        states[place.id] = .loading
        do {
            let shorts = try await service.shorts(for: place, in: CityDirectory.city(id: place.cityID))
            states[place.id] = .loaded(shorts)
            cache[place.id] = Entry(fetched: now(), shorts: shorts)
            save()
        } catch {
            if Task.isCancelled {
                states[place.id] = nil
            } else {
                states[place.id] = .failed(YouTubeService.isRateLimited(error)
                    ? "Videos are paused on this phone for a while. Try again later."
                    : "Videos couldn’t load right now.")
            }
        }
    }

    private func isFresh(_ entry: Entry) -> Bool {
        now().timeIntervalSince(entry.fetched) < (entry.shorts.isEmpty ? Self.keepEmptyFor : Self.keepFor)
    }

    private func save() {
        guard let cacheURL else { return }
        cache = cache.filter { isFresh($0.value) }
        try? JSONEncoder().encode(cache).write(to: cacheURL, options: .atomic)
    }

    // MARK: Links out

    /// TikTok has no search API for apps, so its own search opens instead.
    nonisolated static func tikTokURL(for place: Place, in city: City) -> URL {
        var components = URLComponents(string: "https://www.tiktok.com/search")!
        components.queryItems = [URLQueryItem(name: "q", value: "\(place.name) \(city.name)")]
        return components.url!
    }

    /// Category-tailored TikTok search angles so users can check the crowd,
    /// dress code, best dishes, or sunset views with a single tap.
    nonisolated static func vibeAngles(for place: Place) -> [(label: String, suffix: String)] {
        switch place.category {
        case .nightlife:
            return [
                ("Vibe check", "nightlife vibe"),
                ("Crowd & DJ", "crowd DJ"),
                ("Dress code", "dress code line"),
                ("Inside", "inside night out")
            ]
        case .food:
            return [
                ("Vibe check", "food review"),
                ("Must-order", "best dishes menu"),
                ("Ambiance", "inside patio vibe"),
                ("Honest review", "worth it review")
            ]
        case .museum, .attraction:
            return [
                ("Vibe check", "walkthrough"),
                ("Highlights", "best things to see"),
                ("Tips", "tips before you go")
            ]
        case .nature, .activity:
            return [
                ("Vibe check", "views"),
                ("Golden hour", "sunset"),
                ("Tips", "what to know")
            ]
        }
    }

    /// Deep-links into TikTok's video search tab with a category/vibe suffix.
    nonisolated static func tikTokVibeURL(for place: Place, in city: City, angleSuffix: String = "") -> URL {
        var components = URLComponents(string: "https://www.tiktok.com/search/video")!
        let base = "\(place.name) \(city.name)"
        let query = angleSuffix.isEmpty ? base : "\(base) \(angleSuffix)"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url!
    }

    /// Mobile YouTube Shorts search URL for a place + vibe angle.
    nonisolated static func youTubeShortsSearchURL(for place: Place, in city: City, angleSuffix: String = "") -> URL {
        var components = URLComponents(string: "https://m.youtube.com/results")!
        let base = YouTubeService.searchQuery(for: place, in: city)
        let query = angleSuffix.isEmpty ? "\(base) #shorts" : "\(base) \(angleSuffix) #shorts"
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        return components.url!
    }

    /// The place's name as a hashtag page, "#wynwoodwalls".
    nonisolated static func instagramURL(for place: Place) -> URL? {
        let tag = place.name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard !tag.isEmpty else { return nil }
        return URL(string: "https://www.instagram.com/explore/tags/\(tag)/")
    }

    /// Fetches real short-form video clips for a specific place + vibe angle
    /// (e.g. "CASA NEOS Miami crowd DJ #shorts") without spending API quota,
    /// so every Vibe Check angle pill plays accurate vertical clips in-app.
    nonisolated static func fetchLiveVibeShorts(
        for place: Place,
        in city: City,
        angleSuffix: String = "",
        session: URLSession = .shared
    ) async -> [PlaceShort] {
        var components = URLComponents(string: "https://www.youtube.com/results")!
        let base = YouTubeService.searchQuery(for: place, in: city)
        let query = angleSuffix.isEmpty ? "\(base) #shorts" : "\(base) \(angleSuffix) #shorts"
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8)
        else { return [] }

        return parseInitialDataShorts(from: html, place: place, city: city)
    }

    nonisolated private static func parseInitialDataShorts(from html: String, place: Place, city: City) -> [PlaceShort] {
        let marker = "var ytInitialData = "
        guard let startRange = html.range(of: marker) else { return [] }
        let afterMarker = html[startRange.upperBound...]
        guard let endRange = afterMarker.range(of: ";</script>") else { return [] }
        let jsonString = String(afterMarker[..<endRange.lowerBound])
        guard let jsonData = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: jsonData)
        else { return [] }

        var raw: [PlaceShort] = []
        var seen = Set<String>()

        func walk(_ node: Any) {
            guard raw.count < 16 else { return }
            if let dict = node as? [String: Any] {
                if let vr = dict["videoRenderer"] as? [String: Any],
                   let vid = vr["videoId"] as? String,
                   seen.insert(vid).inserted {
                    let title = extractRunsText(vr["title"])
                    let channel = extractRunsText(vr["ownerText"]).isEmpty ? "Shorts" : extractRunsText(vr["ownerText"])
                    if !title.isEmpty {
                        raw.append(PlaceShort(
                            id: vid,
                            title: title,
                            channel: channel,
                            thumbnailURL: URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg"),
                            views: nil,
                            seconds: 45
                        ))
                    }
                } else if let rr = dict["reelItemRenderer"] as? [String: Any],
                          let vid = rr["videoId"] as? String,
                          seen.insert(vid).inserted {
                    let title = (rr["headline"] as? [String: Any])?["simpleText"] as? String ?? ""
                    if !title.isEmpty {
                        raw.append(PlaceShort(
                            id: vid,
                            title: title,
                            channel: "Shorts",
                            thumbnailURL: URL(string: "https://i.ytimg.com/vi/\(vid)/hqdefault.jpg"),
                            views: nil,
                            seconds: 45
                        ))
                    }
                } else {
                    for value in dict.values { walk(value) }
                }
            } else if let array = node as? [Any] {
                for item in array { walk(item) }
            }
        }

        walk(root)
        let matched = raw.filter {
            YouTubeService.isAccurateMatch(for: place, in: city, text: "\($0.title) \($0.channel)")
        }
        return Array((matched.isEmpty ? raw : matched).prefix(8))
    }

    nonisolated private static func extractRunsText(_ value: Any?) -> String {
        guard let dict = value as? [String: Any] else { return "" }
        if let simple = dict["simpleText"] as? String { return simple }
        guard let runs = dict["runs"] as? [[String: Any]] else { return "" }
        return runs.compactMap { $0["text"] as? String }.joined()
    }
}
