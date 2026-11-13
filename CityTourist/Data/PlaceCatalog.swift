import Foundation
import Observation
import CoreLocation

/// Every place the app has seen this session, keyed by id.
///
/// Itineraries persist only a `placeID`, so any screen rendering a saved stop
/// needs to resolve that id without knowing where it came from. The directory
/// starts seeded with the bundled sample set and takes on live results as they
/// arrive, so lookups keep working whether or not an API key is configured.
@MainActor
enum PlaceDirectory {
    /// Observable, so a view that looked up a place it didn't have yet redraws
    /// when the place arrives — a stop restored after a relaunch resolves a
    /// moment after the screen first renders.
    // fileprivate, not private: the macro's generated extension must see it.
    @MainActor
    @Observable
    fileprivate final class Storage {
        var byID: [String: Place]
        init(_ places: [Place]) {
            byID = Dictionary(uniqueKeysWithValues: places.map { ($0.id, $0) })
        }
    }

    private static let storage = Storage(SampleData.places)

    static func place(id: String) -> Place? { storage.byID[id] }

    static func register(_ places: [Place]) {
        guard !places.isEmpty else { return }
        // One mutation rather than one per place, so observers redraw once.
        storage.byID.merge(places.map { ($0.id, $0) }) { _, new in new }
    }
}

/// Loads and caches a city's places, live from Google when a key is present and
/// from the bundled sample set otherwise.
@MainActor
@Observable
final class PlaceCatalog {

    enum Source: Equatable {
        case sample
        case live(fetchedAt: Date)

        var isLive: Bool { if case .live = self { true } else { false } }
    }

    enum LoadState: Equatable {
        case idle, loading, loaded, failed(String)
    }

    private(set) var state: LoadState = .idle
    private(set) var source: Source = .sample

    /// Saved place ids being looked up right now.
    private(set) var resolvingPlaceIDs: Set<String> = []
    /// Saved place ids whose last lookup failed. The next `resolve` retries them.
    private(set) var failedPlaceIDs: Set<String> = []
    /// The failed ids that were never sent: this phone was over its request
    /// allowance. Trying again shortly will work.
    private(set) var pausedPlaceIDs: Set<String> = []

    private var cache: [String: [Place]] = [:]
    private var loadedToday: Set<String> = []

    /// Where one category of one city has got to beyond discovery's twenty.
    private struct More {
        var places: [Place] = []
        var nextPageToken: String?
        var pages = 0
        var isDone = false
        var isLoading = false
        var failed = false
    }
    private var more: [String: More] = [:]
    private static func moreKey(_ category: PlaceCategory, _ cityID: String) -> String { "\(cityID)|\(category.rawValue)" }

    private let makeService: () -> GooglePlacesService?
    private let makeEventbriteService: () -> EventbriteService?
    private let makeEventService: () -> TicketmasterService?

    /// Tests pass clients wired to a stubbed session.
    init(makeService: @escaping () -> GooglePlacesService? = { GooglePlacesService() },
         makeEventService: @escaping () -> TicketmasterService? = { TicketmasterService() },
         makeEventbriteService: @escaping () -> EventbriteService? = { EventbriteService() }) {
        self.makeEventbriteService = makeEventbriteService
        self.makeService = makeService
        self.makeEventService = makeEventService
    }

    var isLiveDataAvailable: Bool { Secrets.hasGooglePlacesKey }

    /// Places for a city — live results once they're in, sample data until then,
    /// followed by any that were loaded on reaching the end of a category.
    func places(in cityID: String) -> [Place] {
        (cache[cityID] ?? SampleData.places(in: cityID)) + morePlaces(in: cityID)
    }

    // MARK: More of a category

    /// A category shows twenty places or so. Reaching the end of the list asks
    /// for the next page, up to this many pages: each is a billed search, and
    /// past the third Google has nothing further to give.
    static let morePagesPerCategory = 3
    /// A page that mostly repeats what's on screen is followed by one more.
    private static let fewNewPlaces = 5

    /// The places loaded past discovery, in the order they arrived, so adding
    /// to a list never reshuffles what's above.
    func morePlaces(in cityID: String, category: PlaceCategory? = nil) -> [Place] {
        PlaceCategory.allCases
            .filter { category == nil || $0 == category }
            .flatMap { more[Self.moreKey($0, cityID)]?.places ?? [] }
    }

    func hasMore(of category: PlaceCategory, in city: City) -> Bool {
        // Only a category that came from Google has further pages to ask for.
        guard cache[city.id] != nil, isLoaded(category, in: city) else { return false }
        return more[Self.moreKey(category, city.id)]?.isDone != true
    }

    func isLoadingMore(of category: PlaceCategory, in city: City) -> Bool {
        more[Self.moreKey(category, city.id)]?.isLoading == true
    }

    func failedToLoadMore(of category: PlaceCategory, in city: City) -> Bool {
        more[Self.moreKey(category, city.id)]?.failed == true
    }

    /// What to search for to find more of a category.
    static func moreQuery(for category: PlaceCategory) -> String {
        switch category {
        case .attraction: "landmarks and sights"
        case .food:       "best restaurants"
        case .museum:     "museums and galleries"
        case .nature:     "parks and gardens"
        case .activity:   "things to do"
        case .nightlife:  "bars and nightlife"
        case .relaxation: "spas and wellness"
        }
    }

    /// Adds the next page of a category to the city's places.
    func loadMore(of category: PlaceCategory, in city: City) async {
        let key = Self.moreKey(category, city.id)
        guard hasMore(of: category, in: city), more[key]?.isLoading != true,
              let service = makeService() else { return }
        more[key, default: More()].isLoading = true
        more[key]?.failed = false
        defer { more[key]?.isLoading = false }

        let centre = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
        var added = 0
        // At most two searches for one arrival at the end of the list.
        for _ in 0..<2 {
            guard var progress = more[key], !progress.isDone else { return }
            do {
                let page = try await service.searchPlaces(query: Self.moreQuery(for: category), city: city,
                                                          pageToken: progress.nextPageToken, forVisitors: true,
                                                          only: category)
                var known = Set(places(in: city.id).map(\.id))
                let fresh = page.places.filter { place in
                    let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
                    return centre.distance(from: location) <= GooglePlacesService.discoveryRadiusMeters
                        && known.insert(place.id).inserted
                }
                progress.places += fresh
                progress.pages += 1
                progress.nextPageToken = page.nextPageToken
                progress.isDone = page.nextPageToken == nil || progress.pages >= Self.morePagesPerCategory
                more[key] = progress
                PlaceDirectory.register(fresh)
                added += fresh.count
                if added >= Self.fewNewPlaces { return }
            } catch {
                more[key]?.failed = true
                return
            }
        }
    }

    /// Search results resolve through the same directory as discovery, saved
    /// places and itinerary stops. They do not replace the discovery feed.
    /// The calling screen owns its query and loading state so searches on two
    /// screens cannot overwrite each other.
    func searchPlaces(query: String, city: City, pageToken: String? = nil,
                      forVisitors: Bool = false) async throws
        -> (places: [Place], nextPageToken: String?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return ([], nil) }
        try Task.checkCancellation()
        guard let service = makeService() else {
            guard pageToken == nil else { return ([], nil) }
            return (places(in: city.id).filter {
                ([$0.name, $0.neighborhood, $0.category.title] + $0.tags)
                    .joined(separator: " ").localizedStandardContains(trimmed)
            }, nil)
        }
        let result = try await service.searchPlaces(query: trimmed, city: city, pageToken: pageToken,
                                                    forVisitors: forVisitors)
        try Task.checkCancellation()
        CityDirectory.register(city)
        PlaceDirectory.register(result.places)
        return result
    }

    // MARK: Discovery

    /// What Explore opens with. Every category is a billed search and most
    /// visits never leave the first screen, so the others wait until their
    /// tab is opened, the end of "All" is reached, or a plan needs them.
    static let firstCategories: [PlaceCategory] = [.attraction, .food]

    private static func key(_ category: PlaceCategory, _ cityID: String) -> String { "\(cityID)|\(category.rawValue)" }
    private static func stamp(_ category: PlaceCategory, _ cityID: String) -> String { "\(key(category, cityID))|\(dayStamp)" }

    /// Fetches still under way, so two screens asking for the same category
    /// share one request instead of paying for two.
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var failedCategories: Set<String> = []

    func isLoaded(_ category: PlaceCategory, in city: City) -> Bool {
        loadedToday.contains(Self.stamp(category, city.id))
    }

    func isLoading(_ category: PlaceCategory, in city: City) -> Bool {
        inFlight[Self.key(category, city.id)] != nil
    }

    func failedToLoad(_ category: PlaceCategory, in city: City) -> Bool {
        failedCategories.contains(Self.key(category, city.id))
    }

    /// The categories of a city not asked for yet today, in display order.
    func unloadedCategories(in city: City) -> [PlaceCategory] {
        guard cache[city.id] != nil else { return [] }
        return PlaceCategory.allCases.filter { !isLoaded($0, in: city) }
    }

    func loadedCategories(in city: City) -> [PlaceCategory] {
        PlaceCategory.allCases.filter { isLoaded($0, in: city) }
    }

    /// Fetches today's data for a city: every category, or only the ones
    /// named. Cheap to call repeatedly: a category is asked for once per city
    /// per day. New places are added after the ones already there, so a list
    /// on screen doesn't reshuffle; `force` starts the city again with just
    /// these categories.
    func load(city: City, force: Bool = false, categories: [PlaceCategory] = PlaceCategory.allCases) async {
        guard makeService() != nil else {
            source = .sample
            state = .loaded
            return
        }
        let wanted = categories.filter { force || !isLoaded($0, in: city) }
        let mine = wanted.filter { force || inFlight[Self.key($0, city.id)] == nil }
        let others = wanted.compactMap { inFlight[Self.key($0, city.id)] }
        if !mine.isEmpty {
            let task = Task { await fetch(mine, in: city, replacing: force) }
            for category in mine { inFlight[Self.key(category, city.id)] = task }
            await task.value
            for category in mine where inFlight[Self.key(category, city.id)] == task {
                inFlight[Self.key(category, city.id)] = nil
            }
        }
        for task in others { await task.value }
    }

    private func fetch(_ categories: [PlaceCategory], in city: City, replacing: Bool) async {
        guard let service = makeService() else { return }
        if cache[city.id] == nil || replacing { state = .loading }
        for category in categories { failedCategories.remove(Self.key(category, city.id)) }
        do {
            let places = try await service.catalogue(for: city, categories: categories)
            // Asked again here, not before the request: another category may have arrived meanwhile.
            if replacing || cache[city.id] == nil {
                guard !places.isEmpty else {
                    // A valid key with no results still shouldn't blank the screen.
                    state = .failed("No places came back for \(city.name).")
                    return
                }
                cache[city.id] = places
                if replacing {
                    // A fresh catalogue starts each category's extra pages again.
                    more = more.filter { !$0.key.hasPrefix("\(city.id)|") }
                    loadedToday = loadedToday.filter { !$0.hasPrefix("\(city.id)|") }
                }
            } else {
                var known = Set(self.places(in: city.id).map(\.id))
                cache[city.id, default: []] += places.filter { known.insert($0.id).inserted }
            }
            PlaceDirectory.register(places)
            for category in categories { loadedToday.insert(Self.stamp(category, city.id)) }
            source = .live(fetchedAt: .now)
            state = .loaded
        } catch {
            for category in categories { failedCategories.insert(Self.key(category, city.id)) }
            // A city with places on screen keeps them; only an empty one reports the failure.
            if cache[city.id] == nil || replacing { state = .failed(error.localizedDescription) }
        }
    }

    /// Looks up any of these places the app doesn't already have, one Place
    /// Details call each.
    ///
    /// Trips and bookmarks persist place ids only — Google's terms allow
    /// keeping an id indefinitely but not the rest of a place — so after a
    /// relaunch anything outside the bundled samples has to be fetched again.
    /// Places already known, or already being fetched, cost nothing.
    ///
    /// `cityID` is the city the places belong to. Pass nil when it isn't known,
    /// and each place is assigned to the nearest known city instead.
    func resolve(_ placeIDs: some Sequence<String>, cityID: String?) async {
        let missing = Set(placeIDs).filter {
            PlaceDirectory.place(id: $0) == nil && !resolvingPlaceIDs.contains($0)
        }
        guard !missing.isEmpty else { return }

        // Each id goes back to the service it came from; without that
        // service's key, it can't be looked up at all.
        let google = makeService()
        let events = makeEventService()
        let eventbrite = makeEventbriteService()
        let unreachable = missing.filter { $0.hasPrefix("eb:") ? eventbrite == nil : ($0.hasPrefix(Place.eventIDPrefix) ? events == nil : google == nil) }
        failedPlaceIDs.formUnion(unreachable)
        let fetchable = missing.subtracting(unreachable)
        guard !fetchable.isEmpty else { return }

        resolvingPlaceIDs.formUnion(fetchable)
        failedPlaceIDs.subtract(fetchable)
        pausedPlaceIDs.subtract(fetchable)

        var found: [Place] = []
        await withTaskGroup(of: (id: String, place: Place?, paused: Bool).self) { group in
            for id in fetchable {
                group.addTask {
                    do {
                        if id.hasPrefix("eb:"), let eventbrite {
                            return (id, try await eventbrite.event(id: String(id.dropFirst(3)), cityID: cityID ?? ""), false)
                        }
                        if id.hasPrefix(Place.eventIDPrefix), let events {
                            let eventID = String(id.dropFirst(Place.eventIDPrefix.count))
                            return (id, try await events.event(id: eventID, cityID: cityID ?? ""), false)
                        }
                        guard let google else { return (id, nil, false) }
                        return (id, try await google.place(id: id, cityID: cityID ?? ""), false)
                    } catch {
                        let paused = GooglePlacesService.isRateLimited(error) || TicketmasterService.isRateLimited(error)
                        return (id, nil, paused)
                    }
                }
            }
            for await (id, place, paused) in group {
                guard var place else {
                    // Leaving the screen cancels the lookup; that isn't a failure.
                    if !Task.isCancelled {
                        failedPlaceIDs.insert(id)
                        if paused { pausedPlaceIDs.insert(id) }
                    }
                    continue
                }
                if cityID == nil { place.cityID = CityDirectory.nearest(to: place.coordinate).id }
                found.append(place)
            }
        }

        // Registered together rather than as each arrives: the timeline keys
        // its travel-time lookup on which places have resolved, and a trickle
        // would restart that lookup once per place.
        PlaceDirectory.register(found)
        resolvingPlaceIDs.subtract(fetchable)
    }

    /// Today's date, so a day-old cache refetches on next launch.
    private static var dayStamp: String { Calendar.current.dayStamp(for: .now) }
}

/// Every city the app knows about: the bundled samples plus any the user has
/// searched for. Trips store only a `cityID`, so this is what lets a trip to a
/// searched city still render its name and cover after a relaunch.
@MainActor
enum CityDirectory {
    private static var byID: [String: City] = Dictionary(
        uniqueKeysWithValues: SampleData.cities.map { ($0.id, $0) }
    )

    /// Falls back to the first sample city so callers never have to unwrap.
    /// In practice every city a trip references is registered before use.
    static func knownCity(id: String) -> City? { byID[id] }

    static func city(id: String) -> City {
        byID[id] ?? SampleData.cities[0]
    }

    static func register(_ cities: [City]) {
        for city in cities { byID[city.id] = city }
    }

    static func register(_ city: City) { byID[city.id] = city }

    /// The known city closest to a coordinate. Only used for bookmarks made
    /// before bookmarks recorded which city they came from.
    static func nearest(to coordinate: Coordinate) -> City {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        func distance(_ city: City) -> CLLocationDistance {
            CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
                .distance(from: target)
        }
        return byID.values.min { distance($0) < distance($1) } ?? SampleData.cities[0]
    }
}

/// Debounced city autocomplete backing the "Where to?" field.
@MainActor
@Observable
final class CitySearchModel {
    var query: String = ""
    private(set) var suggestions: [CitySuggestion] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    /// Groups the keystrokes and the eventual details call into one billable
    /// session; rotated once a city is picked.
    private var sessionToken = UUID().uuidString

    var isAvailable: Bool { Secrets.hasGooglePlacesKey }

    /// Shown before the user types anything.
    var popular: [City] { SampleData.cities }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            errorMessage = nil
            return
        }
        guard let service = GooglePlacesService() else {
            errorMessage = "Add a Google Places key to search any city."
            return
        }

        // Debounce — a cancelled task here means another keystroke landed.
        do { try await Task.sleep(for: .milliseconds(280)) } catch { return }
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        do {
            suggestions = try await service.autocompleteCities(input: trimmed, sessionToken: sessionToken)
            errorMessage = suggestions.isEmpty ? "No cities match “\(trimmed)”." : nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Resolves a suggestion to a full city and registers it for later lookups.
    func resolve(_ suggestion: CitySuggestion) async -> City? {
        guard let service = GooglePlacesService() else { return nil }
        do {
            let city = try await service.cityDetails(placeID: suggestion.id, sessionToken: sessionToken)
            CityDirectory.register(city)
            sessionToken = UUID().uuidString  // the billable session ends here
            return city
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
