import Foundation
import CoreLocation
import Observation

struct SavedCitySection: Identifiable {
    let id: String
    let title: String
    var placeIDs: [String]
}

@MainActor @Observable
final class SavedCityGroups {
    private var recovered: [String: String] = [:]
    private var attempted = Set<String>()
    private let geocoder = CLGeocoder()

    func sections(store: AppStore) -> [SavedCitySection] {
        var groups: [String: SavedCitySection] = [:]
        for id in store.savedPlaceIDs.sorted() {
            // Use persisted provenance. A legacy lookup may have guessed the nearest sample city.
            let cityID = store.savedPlaceCityIDs[id]
            let city = cityID.flatMap(CityDirectory.knownCity(id:))
            let name = city?.displayName ?? recovered[id]
            let key = city.map { "city:\($0.id)" } ?? name.map { "geocoded:\($0)" } ?? "unknown"
            if groups[key] == nil {
                groups[key] = SavedCitySection(id: key, title: name ?? L10n.text("Unknown Location"), placeIDs: [])
            }
            groups[key]?.placeIDs.append(id)
        }
        return groups.values.map { section in
            var sorted = section
            sorted.placeIDs.sort {
                let left = PlaceDirectory.place(id: $0)?.name ?? $0
                let right = PlaceDirectory.place(id: $1)?.name ?? $1
                return left.localizedStandardCompare(right) == .orderedAscending
            }
            return sorted
        }.sorted {
            if $0.id == "unknown" { return false }
            if $1.id == "unknown" { return true }
            let order = $0.title.localizedStandardCompare($1.title)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }
    }

    /// Serial geocoding avoids a burst of requests. Failed attempts remain safely under Unknown.
    func recover(store: AppStore, retry: Bool = false) async {
        if retry { attempted.removeAll() }
        for id in store.savedPlaceIDs.sorted() {
            guard !Task.isCancelled else { return }
            guard store.savedPlaceCityIDs[id].flatMap(CityDirectory.knownCity(id:)) == nil,
                  !attempted.contains(id), let place = PlaceDirectory.place(id: id),
                  place.coordinate.isValid else { continue }
            attempted.insert(id)
            do {
                let marks = try await geocoder.reverseGeocodeLocation(CLLocation(
                    latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
                try Task.checkCancellation()
                if let mark = marks.first, let city = mark.locality, !city.isEmpty {
                    recovered[id] = [city, mark.administrativeArea, mark.country].compactMap { $0 }.joined(separator: ", ")
                }
            } catch {
                if Task.isCancelled { attempted.remove(id); return }
            }
        }
    }
}
