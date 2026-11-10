import SwiftUI
import CoreLocation

/// The same place search from Explore and from a day being planned. Search
/// is submitted explicitly; editing or clearing the field cancels old work.
struct PlaceSearchView: View {
    let city: City
    var title = "Search places"
    var initialCategory: PlaceCategory? = nil
    var excludedPlaceIDs: Set<String> = []
    var onAdd: ((Place) -> Void)? = nil
    /// Set where the city is the searcher's to change, as in Explore: the
    /// heading then switches city without leaving the search, and typing a
    /// city's name offers to go there. A trip's day stays in the trip's city.
    var onChangeCity: ((City) -> Void)? = nil

    @Environment(AppStore.self) private var store
    @Environment(PlaceCatalog.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: PlaceCategory?
    @State private var matches: [Place] = []
    @State private var state: PlaceCatalog.LoadState = .idle
    @State private var submittedQuery = ""
    @State private var requestPageToken: String?
    @State private var nextPageToken: String?
    @State private var requestID = UUID()
    @State private var isChoosingCity = false
    @State private var citySearch = CitySearchModel()
    @State private var resolvingCityID: String?

    /// Cities worth offering for what's been typed: not the one already
    /// being searched, and few enough to sit above the results.
    nonisolated static func cityMatches(_ suggestions: [CitySuggestion], besides city: City, limit: Int = 2) -> [CitySuggestion] {
        Array(suggestions.filter { $0.id != city.id }.prefix(limit))
    }

    private var cityMatches: [CitySuggestion] {
        guard onChangeCity != nil, trimmedQuery.count >= 3 else { return [] }
        return Self.cityMatches(citySearch.suggestions, besides: city)
    }

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasQuery: Bool { !trimmedQuery.isEmpty }
    private var visiblePlaces: [Place] {
        let catalogPlaces = catalog.places(in: city.id).sorted { $0.rating > $1.rating }
        let candidates: [Place]
        if hasQuery {
            if state == .idle {
                let q = trimmedQuery.localizedLowercase
                candidates = catalogPlaces.filter {
                    $0.name.localizedLowercase.contains(q)
                        || $0.neighborhood.localizedLowercase.contains(q)
                        || $0.blurb.localizedLowercase.contains(q)
                        || $0.category.title.localizedLowercase.contains(q)
                }
            } else {
                candidates = matches
            }
        } else {
            candidates = catalogPlaces
        }
        return candidates.filter {
            !excludedPlaceIDs.contains($0.id) && (category == nil || $0.category == category)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        if onChangeCity != nil {
                            Button { isChoosingCity = true } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("Around \(city.name)").sectionTitleStyle()
                                    Image(systemName: "chevron.down")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(Brand.rausch)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(L10n.text("Search in another city"))
                            .accessibilityIdentifier("placeSearchCity")
                        } else {
                            Text("Around \(city.name)").sectionTitleStyle()
                        }
                        Text(catalog.isLiveDataAvailable
                             ? L10n.format("Find a name, food or activity within %@ of the city centre.", store.distance(50_000))
                             : "Searching sample places. Live search is unavailable.").captionStyle()
                    }
                    if hasQuery {
                        searchContent
                    } else {
                        browseContent
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.vertical, 16)
            }
            .background(Palette.canvas)
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search places near \(city.name)")
            .onSubmit(of: .search) { submit() }
            .onChange(of: query) { _, _ in resetSearch() }
            .onChange(of: city.id) { _, _ in
                // What was typed carries over to the new city, and a search
                // already made is made again there.
                let wasSearched = !submittedQuery.isEmpty
                category = nil
                resetSearch()
                if wasSearched { submit() }
            }
            .task(id: query) {
                guard onChangeCity != nil else { return }
                citySearch.query = trimmedQuery.count >= 3 ? trimmedQuery : ""
                await citySearch.search()
            }
            .sheet(isPresented: $isChoosingCity) {
                NavigationStack {
                    ScrollView {
                        CitySearchView(recents: store.recentCities, selection: city) { picked in
                            isChoosingCity = false
                            onChangeCity?(picked)
                        }
                        .padding(Metric.gutter)
                    }
                    .background(Palette.canvas)
                    .navigationTitle("Search in another city")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Cancel") { isChoosingCity = false }.foregroundStyle(Palette.ink)
                        }
                    }
                }
            }
            .navigationTitle(L10n.text(title))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Brand.rausch)
                }
            }
            .task(id: city.id) {
                category = initialCategory
                await catalog.load(city: city)
            }
            .task(id: requestID) { await runSearch() }
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        CategoryRail(selection: $category)
        if catalog.state == .loading && visiblePlaces.isEmpty {
            ProgressView("Finding suggestions…").padding(.vertical, 24)
        }
        if case .failed = catalog.state {
            Text("Suggestions couldn’t load. You can still search for a place above.").metaStyle()
        }
        if visiblePlaces.isEmpty && catalog.state != .loading {
            Text("Search for somewhere you have in mind, or try another category.").metaStyle()
        }
        placeRows
    }

    /// "Austin" typed while searching Miami most likely means go to Austin.
    private var cityRows: some View {
        ForEach(cityMatches) { match in
            Button {
                Task { await go(to: match) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.elevated, in: Circle())
                        .overlay { Circle().strokeBorder(Palette.hairline, lineWidth: 1) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Explore \(match.name)").cardTitleStyle().lineLimit(1)
                        if !match.region.isEmpty { Text(match.region).captionStyle().lineLimit(1) }
                    }
                    Spacer(minLength: 8)
                    if resolvingCityID == match.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(resolvingCityID != nil)
        }
    }

    /// The name typed was the city's, so it isn't carried over as a search.
    private func go(to match: CitySuggestion) async {
        resolvingCityID = match.id
        defer { resolvingCityID = nil }
        guard let picked = await citySearch.resolve(match) else { return }
        query = ""
        onChangeCity?(picked)
    }

    @ViewBuilder
    private var searchContent: some View {
        if state == .idle {
            cityRows
            Button {
                submit()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Brand.rausch, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Search near \(city.name) for “\(trimmedQuery)”")
                            .cardTitleStyle()
                            .lineLimit(1)
                        Text(trimmedQuery.count < 2
                             ? "Enter at least two characters"
                             : (catalog.isLiveDataAvailable ? "Tap or press Search on keyboard" : "Search sample places"))
                            .captionStyle()
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
                .opacity(trimmedQuery.count >= 2 ? 1 : 0.5)
            }
            .buttonStyle(.plain)
            .disabled(trimmedQuery.count < 2)

            if !visiblePlaces.isEmpty {
                Text("Matching suggestions in \(city.name)")
                    .captionStyle()
                    .padding(.top, 4)
                placeRows
            }
        } else {
            placeRows
            switch state {
            case .loading:
                ProgressView(matches.isEmpty ? "Searching places…" : "Finding more places…")
                    .padding(.vertical, 20)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 12) {
                    Text("Couldn’t search places").cardTitleStyle()
                    Text(L10n.text(message)).metaStyle()
                    SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") {
                        state = .loading
                        requestID = UUID()
                    }
                }
            case .loaded:
                if visiblePlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(matches.isEmpty ? "No matches nearby" : "Already on this day").sectionTitleStyle()
                        Text(matches.isEmpty
                             ? "Try a different name or a broader search near \(city.name)."
                             : "The matching places are already in your itinerary. Try another search.").metaStyle()
                    }
                }
                if let nextPageToken {
                    SecondaryButton(title: "More results") {
                        requestPageToken = nextPageToken
                        state = .loading
                        requestID = UUID()
                    }
                }
                if catalog.isLiveDataAvailable {
                    Text("Results from Google Maps").captionStyle()
                }
            case .idle:
                EmptyView()
            }
        }
    }

    private var placeRows: some View {
        ForEach(visiblePlaces) { place in
            HStack(alignment: .center, spacing: 12) {
                NavigationLink(value: place) {
                    HStack(alignment: .top, spacing: 12) {
                        PlacePhoto(place: place, showsGlyph: false)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(place.name).cardTitleStyle().lineLimit(2)
                            Text(place.neighborhood).captionStyle().lineLimit(2)
                            Text(distanceLabel(for: place)).captionStyle()
                            if place.reviewCount > 0 { RatingLabel(rating: place.rating, size: 12) }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let onAdd {
                    Button { onAdd(place) } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Add \(place.name) to this day")
                } else {
                    Button { store.toggleSaved(place) } label: {
                        Image(systemName: store.isSaved(place) ? "heart.fill" : "heart")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(store.isSaved(place) ? "Unsave \(place.name)" : "Save \(place.name)")
                }
            }
            .tint(Brand.rausch)
            Hairline()
        }
    }

    private func distanceLabel(for place: Place) -> String {
        let centre = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        return L10n.format("%@ from city centre · straight-line", store.distance(centre.distance(from: location)))
    }

    private func resetSearch() {
        requestID = UUID()
        submittedQuery = ""
        requestPageToken = nil
        nextPageToken = nil
        matches = []
        state = .idle
    }

    private func submit() {
        guard trimmedQuery.count >= 2, state != .loading else { return }
        submittedQuery = trimmedQuery
        matches = []
        requestPageToken = nil
        nextPageToken = nil
        state = .loading
        requestID = UUID()
    }

    private func runSearch() async {
        guard state == .loading, !submittedQuery.isEmpty else { return }
        let currentRequest = requestID
        do {
            let page = try await catalog.searchPlaces(query: submittedQuery, city: city, pageToken: requestPageToken)
            guard !Task.isCancelled, currentRequest == requestID else { return }
            var seen = Set(matches.map(\.id))
            matches += page.places.filter { seen.insert($0.id).inserted }
            nextPageToken = page.nextPageToken
            state = .loaded
        } catch {
            guard !Task.isCancelled, currentRequest == requestID else { return }
            state = .failed(error.localizedDescription)
        }
    }
}
