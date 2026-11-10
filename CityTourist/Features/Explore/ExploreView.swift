import SwiftUI

struct ExploreView: View {
    @Environment(AppStore.self) private var store
    @Environment(PlaceCatalog.self) private var catalog
    @Environment(EventCatalog.self) private var eventCatalog

    @State private var category: PlaceCategory?
    @State private var isSearchPresented = false
    @State private var isPlaceSearchPresented = false
    @State private var isMapPresented = false
    @State private var placeToAdd: Place?
    @State private var selectedEvent: Place?
    @State private var isAIPrototypePresented = false

    private var city: City { store.browsingCity }

    private var results: [Place] {
        catalog.places(in: store.browsingCityID)
            .filter { category == nil || $0.category == category }
            .sorted { $0.rating > $1.rating }
    }

    private var cityEvents: [Place] {
        guard category == nil || category == .activity || category == .nightlife else { return [] }
        return eventCatalog.events(in: store.browsingCityID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metric.cardGap) {
                    header

                    aiPreviewButton

                    if !cityEvents.isEmpty || eventCatalog.hasFailure(cityID: city.id) {
                        happeningSection
                    }

                    if catalog.state == .loading && results.isEmpty {
                        loadingPlaceholder
                    } else if results.isEmpty {
                        EmptyStateView(
                            symbol: "magnifyingglass",
                            title: "No places match",
                            message: String(localized: "Try a different category, or clear the filters to see everything in \(city.name).", bundle: L10n.bundle, locale: L10n.locale),
                            actionTitle: "Clear filters"
                        ) {
                            withAnimation { category = nil }
                        }
                        .padding(.top, 60)
                    } else {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, place in
                            NavigationLink(value: place) {
                                ListingCard(
                                    place: place,
                                    isSaved: store.isSaved(place),
                                    // Airbnb badges its top result; ours flags the highest rated.
                                    badge: index == 0 && category == nil ? "Traveller favourite" : nil,
                                    onAddToTrip: { placeToAdd = place }
                                ) {
                                    store.toggleSaved(place)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 90)
            }
            .background(Palette.canvas)
            .scrollIndicators(.hidden)
            .refreshable {
                async let placesLoad: () = catalog.load(city: city, force: true)
                async let eventsLoad: () = eventCatalog.load(city: city, force: true)
                _ = await (placesLoad, eventsLoad)
            }
            .safeAreaInset(edge: .top, spacing: 0) { searchHeader }
            .overlay(alignment: .bottom) { mapButton }
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .sheet(isPresented: $isSearchPresented) { SearchSheet() }
            .sheet(isPresented: $isPlaceSearchPresented) {
                PlaceSearchView(city: city, onChangeCity: { store.browse($0) })
            }
            .sheet(item: $placeToAdd) { AddToItinerarySheet(place: $0) }
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    EventDetailView(place: event)
                }
            }
            .sheet(isPresented: $isAIPrototypePresented) { AIRecommendationsView(city: city) }
            .fullScreenCover(isPresented: $isMapPresented) {
                CityMapView(city: city, places: results)
            }
            .task(id: store.browsingCityID) {
                async let placesLoad: () = catalog.load(city: city)
                async let eventsLoad: () = eventCatalog.load(city: city)
                _ = await (placesLoad, eventsLoad)
            }
        }
    }

    private var happeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Happening in \(city.name)")
                            .sectionTitleStyle()
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Brand.rausch)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Brand.rausch.opacity(0.12), in: Capsule())
                    }
                    Text("Upcoming concerts, games & live shows over the next 2 weeks")
                        .captionStyle()
                }
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(cityEvents) { event in
                        Button { selectedEvent = event } label: {
                            EventCard(place: event, showsDate: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                if eventCatalog.hasFailure(cityID: city.id) {
                    Text("Some event providers could not load. Available events are shown.").captionStyle()
                }
                if eventCatalog.hasMore(cityID: city.id) {
                    Button(eventCatalog.hasFailure(cityID: city.id) ? "Retry events" : "More events") {
                        Task { await eventCatalog.loadMore(city: city) }
                    }.disabled(eventCatalog.isLoading(cityID: city.id))
                }
            }
        }
    }

    // MARK: Header

    private var aiPreviewButton: some View {
        Button { isAIPrototypePresented = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        LinearGradient(colors: [Brand.rausch, Brand.rauschDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Find your kind of place")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text("AI")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(Brand.rausch)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Brand.rausch.opacity(0.12), in: Capsule())
                    }
                    Text("Describe a craving, mood, or free hour in \(city.name)")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Brand.rausch.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("exploreAIPrototype")
    }

    private var searchHeader: some View {
        VStack(spacing: 10) {
            SearchPill(
                title: city.name,
                subtitle: pillSubtitle,
                action: { isSearchPresented = true },
                onPlaceSearch: { isPlaceSearchPresented = true }
            )
            .padding(.horizontal, Metric.gutter)

            CategoryRail(selection: $category)

            Hairline()
        }
        .padding(.top, 8)
        .background(.bar)
    }

    private var pillSubtitle: String {
        catalog.state == .loading ? "Finding places…" : "Switch city or dates · \(results.count) places"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category?.title ?? "Top rated in \(city.name)")
                    .sectionTitleStyle()
                if !city.tagline.isEmpty {
                    Text(city.tagline)
                        .metaStyle()
                }
            }
            dataSourceNote
        }
        .padding(.top, 18)
    }

    /// Tells you where these results came from, and lets you retry a failure.
    @ViewBuilder
    private var dataSourceNote: some View {
        switch catalog.state {
        case .failed(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Showing sample places — \(message)")
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Try again") {
                        Task { await catalog.load(city: city, force: true) }
                    }
                    .font(.caption.weight(.semibold))
                    .underline()
                }
            }
            .foregroundStyle(Brand.rausch)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.rausch.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))

        case .loaded where catalog.source.isLive:
            Label("Live from Google Places · updated today", systemImage: "dot.radiowaves.up.forward")
                .font(.caption.weight(.medium))
                .foregroundStyle(Brand.babu)

        case .loaded where !catalog.source.isLive, .idle where !catalog.isLiveDataAvailable:
            Label("Sample places · explore a sample city",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(Palette.inkFaint)

        default:
            EmptyView()
        }
    }

    /// Skeleton cards while the first fetch is in flight.
    private var loadingPlaceholder: some View {
        VStack(spacing: Metric.cardGap) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .fill(Palette.surface)
                        .aspectRatio(Metric.photoAspect, contentMode: .fit)
                    RoundedRectangle(cornerRadius: 4).fill(Palette.surface).frame(width: 180, height: 14)
                    RoundedRectangle(cornerRadius: 4).fill(Palette.surface).frame(width: 120, height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
        .shimmer()
    }

    private var mapButton: some View {
        CapsuleActionButton(title: "Map", systemImage: "map") {
            isMapPresented = true
        }
        .padding(.bottom, 12)
    }
}

/// Slow sheen across skeleton content while it loads.
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .offset(x: phase * 320)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
    }
}

private extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

#Preview {
    ExploreView().environment(AppStore(loadFromDisk: false))
        .environment(PlaceCatalog())
        .environment(EventCatalog())
}
