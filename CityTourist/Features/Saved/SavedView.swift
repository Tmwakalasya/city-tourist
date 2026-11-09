import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @Environment(PlaceCatalog.self) private var catalog
    @State private var grouping = SavedCityGroups()
    @State private var collapsed = Set<String>()
    @State private var placeToAdd: Place?

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                // Keyed on ids, not resolved places: after a relaunch the
                // places are still on their way and this isn't empty.
                if store.savedPlaceIDs.isEmpty {
                    VStack {
                        Spacer()
                        EmptyStateView(
                            symbol: "heart",
                            title: "Nothing saved yet",
                            message: "Tap the heart on any place to keep it here while you decide which day it belongs to."
                        )
                        Spacer()
                    }
                } else {
                    grid
                }
            }
            .background(Palette.canvas)
            .navigationTitle("Saved")
            .navigationDestination(for: Place.self) { PlaceDetailView(place: $0) }
            .sheet(item: $placeToAdd) { AddToItinerarySheet(place: $0) }
            .task(id: store.savedPlaceIDs.sorted()) { await resolveSaved() }
        }
    }

    /// Only ids are kept on disk, so places saved in an earlier session are
    /// fetched again the first time this tab needs them.
    private func resolveSaved() async {
        for (cityID, placeIDs) in store.savedPlaceIDsByCity {
            await catalog.resolve(placeIDs, cityID: cityID)
        }
        await grouping.recover(store: store)
    }

    /// Saved places that haven't resolved yet: loading, or failed to load.
    @ViewBuilder
    private var unresolvedNote: some View {
        let missing = store.savedPlaceIDs.filter { PlaceDirectory.place(id: $0) == nil }

        if !missing.isEmpty {
            Group {
                if missing.allSatisfy(catalog.failedPlaceIDs.contains) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                        Text(L10n.format("Couldn't load %lld saved places.", missing.count))
                            .font(.caption)
                        Button("Try again") { Task { await resolveSaved() } }
                            .font(.caption.weight(.semibold))
                            .underline()
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Brand.rausch)
                    .padding(10)
                    .background(Brand.rausch.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(L10n.format("Loading %lld saved places…", missing.count)).captionStyle()
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
        }
    }

    private var grid: some View {
        ScrollView {
            unresolvedNote
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: [.sectionHeaders]) {
                ForEach(grouping.sections(store: store)) { section in
                    Section {
                        if !collapsed.contains(section.id) {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(section.placeIDs, id: \.self) { id in
                                    if let place = PlaceDirectory.place(id: id) {
                                        savedCard(place)
                                    } else {
                                        Label("Place unavailable", systemImage: "mappin.slash")
                                            .captionStyle().frame(minHeight: 80)
                                    }
                                }
                            }
                        }
                    } header: {
                        Button {
                            withAnimation {
                                if !collapsed.insert(section.id).inserted { collapsed.remove(section.id) }
                            }
                        } label: {
                            HStack {
                                Text(section.title).font(.headline)
                                Text("(\(section.placeIDs.count))").foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: collapsed.contains(section.id) ? "chevron.down" : "chevron.up")
                            }
                            .padding(.vertical, 14).background(Palette.canvas)
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(L10n.text(collapsed.contains(section.id) ? "Collapsed" : "Expanded"))
                    }
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 40)
        }
        .refreshable {
            await resolveSaved()
            await grouping.recover(store: store, retry: true)
        }
        .scrollIndicators(.hidden)
    }

    private func savedCard(_ place: Place) -> some View {
        NavigationLink(value: place) {
            VStack(alignment: .leading, spacing: 8) {
                PlacePhoto(place: place)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 0) {
                            PhotoActionButton(
                                systemImage: "calendar.badge.plus",
                                label: String(localized: "Add \(place.name) to trip", bundle: L10n.bundle, locale: L10n.locale),
                                size: 13
                            ) {
                                placeToAdd = place
                            }
                            HeartButton(isSaved: true, size: 20) { store.toggleSaved(place) }
                        }
                        .padding(6)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(place.category.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.onPhotoInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.onPhoto.opacity(0.9), in: Capsule())
                            .padding(10)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).cardTitleStyle().lineLimit(1)
                    HStack(spacing: 4) {
                        Text(store.savedPlaceCityIDs[place.id].flatMap(CityDirectory.knownCity(id:))?.name ?? L10n.text("Unknown Location")).captionStyle()
                        if !place.neighborhood.isEmpty {
                            Text("·").foregroundStyle(Palette.inkFaint)
                            Text(place.neighborhood).captionStyle().lineLimit(1)
                        }
                    }
                    if place.rating > 0 {
                        RatingLabel(rating: place.rating, size: 12)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SavedView().environment(AppStore(loadFromDisk: false))
        .environment(PlaceCatalog())
}
