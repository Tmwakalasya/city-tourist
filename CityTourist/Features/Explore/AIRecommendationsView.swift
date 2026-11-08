import SwiftUI

struct AIRecommendationsView: View {
    let city: City
    @Environment(AppStore.self) private var store
    @Environment(PlaceCatalog.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @State private var model = AIRecommendations()
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var openNowOnly = false
    @State private var walkableOnly = false
    @State private var hidePlanned = true
    @State private var requestID = UUID()
    @State private var placeToAdd: Place?
    @State private var placeForVibeCheck: Place?
    @FocusState private var isEditing: Bool

    private let ideas: [(title: String, prompt: String, symbol: String)] = [
        ("Iconic nightlife & clubs", "High-energy clubs, famous DJ venues, and iconic late-night hotspots to go out tonight", "sparkles"),
        ("Morning coffee & pastry", "A relaxed café or bakery with great coffee, pastries, and neighbourhood charm", "cup.and.saucer"),
        ("Standout local dining", "An iconic, well-loved local restaurant for a memorable meal", "fork.knife"),
        ("Golden-hour viewpoint", "Somewhere scenic outdoors for a late-afternoon walk or sunset view", "sun.and.horizon"),
        ("Rainy-day culture", "An inspiring museum, gallery, or indoor cultural stop worth a couple of hours", "building.columns")
    ]

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Places already scheduled in an upcoming trip to this city.
    private var plannedPlaceIDs: Set<String> {
        let stops = store.upcomingTrips
            .filter { $0.cityID == city.id }
            .flatMap { $0.days.flatMap(\.stops) }
        return Set(stops.map(\.placeID))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    introduction
                    composer
                    if model.phase == .idle { inspiration }
                    response
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(Palette.canvas)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Find your next stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.tint(Brand.rausch)
                }
            }
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .sheet(item: $placeToAdd) { AddToItinerarySheet(place: $0) }
            .sheet(item: $placeForVibeCheck) { VibeCheckSheet(place: $0) }
            .task(id: city.id) {
                await catalog.load(city: city)
            }
            .task(id: requestID) {
                guard !submittedQuery.isEmpty else { return }
                let effectiveQuery = contextualizedQuery(for: submittedQuery)
                await model.run(query: effectiveQuery, find: { _ in
                    let catalogPlaces = catalog.places(in: city.id)
                    var searched: [Place] = []
                    if catalog.isLiveDataAvailable {
                        let queries = AIRecommendationService.searchQueries(for: submittedQuery)
                        var batches = Array(repeating: [Place](), count: queries.count)
                        for (idx, q) in queries.enumerated() {
                            if let page = try? await catalog.searchPlaces(query: q, city: city) {
                                batches[idx] = page.places
                            }
                        }
                        searched = AIRecommendationService.interleave(batches)
                        if searched.isEmpty {
                            searched = try await catalog.searchPlaces(query: submittedQuery, city: city).places
                        }
                    }
                    return AIRecommendationService.rankCandidates(
                        searched,
                        catalog: catalogPlaces,
                        query: submittedQuery,
                        openNowOnly: openNowOnly,
                        maxDistanceKm: walkableOnly ? 3.0 : nil,
                        city: city,
                        excluding: hidePlanned ? plannedPlaceIDs : []
                    )
                }, choose: { text, places in
                    try await AIRecommendationService().recommend(query: text, city: city, candidates: places)
                })
            }
            .onChange(of: query) { _, _ in
                submittedQuery = ""
                requestID = UUID()
                model.reset()
            }
            .onDisappear { model.reset() }
        }
        .presentationDetents([.large])
    }

    private func contextualizedQuery(for base: String) -> String {
        var suffixes: [String] = []
        if openNowOnly { suffixes.append("prefer places open now") }
        if walkableOnly { suffixes.append("within 3 km of city centre") }
        guard !suffixes.isEmpty else { return String(base.prefix(300)) }
        let combined = "\(base) (\(suffixes.joined(separator: ", ")))"
        return String(combined.prefix(300))
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("AI CONCIERGE").tracking(1.3)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Brand.rausch)

            Text("Your kind of \(city.name).")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.8)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Describe a craving, a vibe, or a gap in your day — we’ll rank the best local fits.")
                .metaStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("A relaxed café for coffee and pastries…", text: $query, axis: .vertical)
                .lineLimit(3...5)
                .font(.body)
                .focused($isEditing)
                .accessibilityIdentifier("aiPreferenceInput")

            FlowLayout(spacing: 8) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) { openNowOnly.toggle() }
                    if !submittedQuery.isEmpty { submit() }
                } label: {
                    Chip(title: "Open now", systemImage: "clock", isSelected: openNowOnly)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.snappy(duration: 0.18)) { walkableOnly.toggle() }
                    if !submittedQuery.isEmpty { submit() }
                } label: {
                    Chip(title: "Near centre (<3 km)", systemImage: "figure.walk", isSelected: walkableOnly)
                }
                .buttonStyle(.plain)

                if !plannedPlaceIDs.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { hidePlanned.toggle() }
                        if !submittedQuery.isEmpty { submit() }
                    } label: {
                        Chip(title: "Skip planned", systemImage: "calendar.badge.minus", isSelected: hidePlanned)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Label(city.name, systemImage: "mappin.circle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Text("\(query.count)/300").font(.caption)
                    .foregroundStyle(query.count > 300 ? Brand.rausch : Palette.inkFaint)
            }
            PrimaryButton(title: "Find my places",
                          isEnabled: (3...300).contains(trimmed.count) && !model.isLoading) {
                submit()
            }
            .accessibilityIdentifier("aiFindPlaces")
        }
        .padding(18)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Brand.rausch.opacity(0.25), lineWidth: 1)
        }
        .shadow(color: Brand.rausch.opacity(0.06), radius: 16, y: 6)
    }

    private var inspiration: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("START WITH AN IDEA")
                .font(.caption.weight(.semibold)).tracking(0.9)
                .foregroundStyle(Palette.inkMuted)
            ForEach(ideas, id: \.title) { idea in
                Button {
                    query = idea.prompt
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: idea.symbol)
                            .foregroundStyle(Brand.rausch)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.title).font(.subheadline.weight(.semibold))
                            Text(idea.prompt)
                                .font(.caption)
                                .foregroundStyle(Palette.inkMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.left").font(.footnote)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Text(catalog.isLiveDataAvailable
                 ? "Your request and public place details are sent to Claude when you tap Find my places."
                 : "Using sample places. Your request and sample details are sent to Claude when you tap Find my places.")
                .captionStyle()
        }
    }

    @ViewBuilder
    private var response: some View {
        switch model.phase {
        case .idle: EmptyView()
        case .searching, .choosing:
            HStack(spacing: 14) {
                ProgressView().tint(Brand.rausch)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.phase == .searching ? "Searching \(city.name) & local favourites…" : "Ranking the strongest matches…")
                        .cardTitleStyle()
                    Text("Checking ratings, reviews, neighborhood & hours.").captionStyle()
                }
            }
            .padding(.vertical, 12)
            Button("Cancel") { cancel() }.font(.subheadline).tint(Palette.inkMuted)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                Label("Couldn’t find your picks", systemImage: "exclamationmark.circle").cardTitleStyle()
                Text(message).metaStyle()
                SecondaryButton(title: "Try again", systemImage: "arrow.clockwise") { submit() }
            }
        case .ready:
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(model.picks.isEmpty ? "Let’s try another idea" : "Top picks for you").sectionTitleStyle()
                    Spacer()
                    if !model.picks.isEmpty {
                        Text("\(model.picks.count) \(model.picks.count == 1 ? "pick" : "picks")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.rausch)
                    }
                }
                if !model.summary.isEmpty { Text(model.summary).metaStyle() }
                ForEach(Array(model.picks.enumerated()), id: \.element.id) { index, pick in
                    pickCard(pick, number: index + 1)
                }
                if !model.picks.isEmpty {
                    Text(catalog.isLiveDataAvailable
                         ? "Places from Google Maps · curated by Claude. Distances are straight-line from the city centre."
                         : "Sample places · curated by Claude. Distances are straight-line from the city centre.")
                        .captionStyle()
                }
            }
            .accessibilityIdentifier("aiRecommendationResults")
        }
    }

    private func pickCard(_ pick: AIPlacePick, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: pick.place) {
                PlacePhoto(place: pick.place)
                    .frame(height: 165)
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            Text("0\(number)").font(.caption.weight(.bold))
                                .foregroundStyle(Palette.onPhotoInk)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Palette.onPhoto, in: Capsule())
                            Text(pick.place.category.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.onPhotoInk)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Palette.onPhoto.opacity(0.9), in: Capsule())
                        }
                        .padding(12)
                    }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        NavigationLink(value: pick.place) {
                            Text(pick.place.name).font(.headline).foregroundStyle(Palette.ink)
                        }
                        .buttonStyle(.plain)
                        HStack(spacing: 5) {
                            Text(pick.place.neighborhood).captionStyle().lineLimit(1)
                            Text("·").foregroundStyle(Palette.inkFaint)
                            Text("\(distance(for: pick.place)) km from centre").captionStyle()
                            if let open = pick.place.openLabel {
                                Text("·").foregroundStyle(Palette.inkFaint)
                                Text(open)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(pick.place.isOpenNow == false ? Brand.rausch : Brand.babu)
                            }
                        }
                    }
                    Spacer(minLength: 8)
                    if pick.place.rating > 0 {
                        RatingLabel(rating: pick.place.rating, reviewCount: pick.place.reviewCount, size: 12)
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(Brand.rausch)
                        .padding(.top, 2)
                    Text(pick.reason)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !pick.caveat.isEmpty {
                    Label(pick.caveat, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                HStack(spacing: 10) {
                    Button { store.toggleSaved(pick.place) } label: {
                        Label(store.isSaved(pick.place) ? "Saved" : "Save",
                              systemImage: store.isSaved(pick.place) ? "heart.fill" : "heart")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.isSaved(pick.place) ? Brand.rausch : Palette.ink)

                    Button { placeForVibeCheck = pick.place } label: {
                        Label("Vibe check", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(Palette.ink)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button { placeToAdd = pick.place } label: {
                        Label("Add to trip", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(.white)
                            .background(Brand.rausch, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Palette.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Palette.hairline, lineWidth: 1)
        }
    }

    private func distance(for place: Place) -> String {
        let metres = AIPlaceCandidate(place: place, city: city).distanceMetresFromCentre
        return (Double(metres) / 1000).formatted(.number.precision(.fractionLength(1)))
    }

    private func submit() {
        guard (3...300).contains(trimmed.count), !model.isLoading else { return }
        isEditing = false
        submittedQuery = trimmed
        requestID = UUID()
    }

    private func cancel() {
        submittedQuery = ""
        requestID = UUID()
        model.reset()
    }
}
