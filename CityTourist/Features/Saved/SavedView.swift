import SwiftUI

struct SavedView: View {
    @Environment(AppStore.self) private var store
    @Environment(PlaceCatalog.self) private var catalog
    @State private var selectedCityID: String?
    @State private var placeToAdd: Place?

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var savedCities: [City] {
        var seen = Set<String>()
        return store.savedPlaces.compactMap { place in
            guard seen.insert(place.cityID).inserted else { return nil }
            return CityDirectory.city(id: place.cityID)
        }
    }

    private var filteredPlaces: [Place] {
        guard let selectedCityID else { return store.savedPlaces }
        return store.savedPlaces.filter { $0.cityID == selectedCityID }
    }

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
            .task { await resolveSaved() }
        }
    }

    /// Only ids are kept on disk, so places saved in an earlier session are
    /// fetched again the first time this tab needs them.
    private func resolveSaved() async {
        for (cityID, placeIDs) in store.savedPlaceIDsByCity {
            await catalog.resolve(placeIDs, cityID: cityID)
        }
    }

    /// Saved places that haven't resolved yet: loading, or failed to load.
    @ViewBuilder
    private var unresolvedNote: some View {
        let missing = store.savedPlaceIDs.filter { PlaceDirectory.place(id: $0) == nil }
        let noun = missing.count == 1 ? "place" : "places"

        if !missing.isEmpty {
            Group {
                if missing.allSatisfy(catalog.failedPlaceIDs.contains) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold))
                        Text("Couldn't load \(missing.count) saved \(noun).")
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
                        Text("Loading \(missing.count) saved \(noun)…").captionStyle()
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
            if savedCities.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { selectedCityID = nil }
                        } label: {
                            Chip(title: "All (\(store.savedPlaces.count))", isSelected: selectedCityID == nil)
                        }
                        .buttonStyle(.plain)

                        ForEach(savedCities) { city in
                            let count = store.savedPlaces.filter { $0.cityID == city.id }.count
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { selectedCityID = city.id }
                            } label: {
                                Chip(title: "\(city.name) (\(count))", isSelected: selectedCityID == city.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metric.gutter)
                }
                .scrollClipDisabled()
                .padding(.top, 8)
            }
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(filteredPlaces) { place in
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
                                            label: "Add \(place.name) to trip",
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
                                    Text(CityDirectory.city(id: place.cityID).name).captionStyle()
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
            .padding(.horizontal, Metric.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    SavedView().environment(AppStore(loadFromDisk: false))
        .environment(PlaceCatalog())
}
