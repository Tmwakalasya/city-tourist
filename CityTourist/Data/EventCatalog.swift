import Foundation
import Observation

/// What's on near a trip's city during its dates.
///
/// Fetched once, when the trip is opened, and kept for the session:
/// Ticketmaster's terms allow caching only for as long as the service needs
/// it, and expect requests to answer what someone is doing. Without a
/// Ticketmaster key there are simply no events.
@MainActor
@Observable
final class EventCatalog {
    /// trip id → day key → events that day, earliest first.
    private var byTrip: [Trip.ID: [String: [Place]]] = [:]
    private var loading: Set<Trip.ID> = []
    /// city id → upcoming events over the next 14 days for the Explore feed.
    private var byCity: [String: [Place]] = [:]
    private var loadingCities: Set<String> = []

    private let makeService: () -> TicketmasterService?

    /// Tests pass a client wired to a stubbed session.
    init(makeService: @escaping () -> TicketmasterService? = { TicketmasterService() }) {
        self.makeService = makeService
    }

    func events(for trip: Trip, on date: Date) -> [Place] {
        byTrip[trip.id]?[WeatherService.dayKey(for: date)] ?? []
    }

    /// All events across any day of the trip, ordered chronologically.
    func allEvents(for trip: Trip) -> [Place] {
        guard let map = byTrip[trip.id] else { return [] }
        return map.keys.sorted().flatMap { map[$0] ?? [] }
    }

    /// Upcoming events in a city over the next two weeks, for Explore.
    func events(in cityID: String) -> [Place] {
        byCity[cityID] ?? []
    }

    func isLoading(cityID: String) -> Bool {
        loadingCities.contains(cityID)
    }

    /// Loads the next 14 days of live events around a city for the Explore screen.
    func load(city: City, force: Bool = false) async {
        guard (force || byCity[city.id] == nil),
              !loadingCities.contains(city.id),
              let service = makeService() else { return }
        loadingCities.insert(city.id)
        defer { loadingCities.remove(city.id) }

        let start = Date.now
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start
        guard let found = try? await service.events(near: city.coordinate, cityID: city.id,
                                                     from: start, to: end)
        else { return }

        let todayKey = WeatherService.dayKey(for: start)
        var seen = Set<String>()
        let upcoming = found
            .filter { place in
                guard let info = place.event, info.localDate >= todayKey else { return false }
                let dedupeKey = "\(place.name.localizedLowercase)|\(info.localDate)"
                return seen.insert(dedupeKey).inserted
            }
            .sorted { a, b in
                let da = a.event?.localDate ?? ""
                let db = b.event?.localDate ?? ""
                if da != db { return da < db }
                return (a.event?.startMinute ?? 0) < (b.event?.startMinute ?? 0)
            }

        PlaceDirectory.register(upcoming)
        byCity[city.id] = Array(upcoming.prefix(20))
    }

    /// Once per trip per session. A failed fetch isn't remembered, so opening
    /// the trip again tries again.
    func load(trip: Trip, city: City) async {
        guard byTrip[trip.id] == nil, !loading.contains(trip.id), let service = makeService() else { return }
        loading.insert(trip.id)
        defer { loading.remove(trip.id) }

        guard let found = try? await service.events(near: city.coordinate, cityID: city.id,
                                                     from: trip.startDate, to: trip.endDate)
        else { return }

        // The search window runs a day either side; keep only the trip's days.
        let days = Set(trip.days.map { WeatherService.dayKey(for: $0.date) })
        let onTrip = found.filter { $0.event.map { days.contains($0.localDate) } ?? false }
        // Registered so a stop added from one resolves straight away.
        PlaceDirectory.register(onTrip)
        byTrip[trip.id] = Dictionary(grouping: onTrip) { $0.event?.localDate ?? "" }
            .mapValues { $0.sorted { ($0.event?.startMinute ?? 0) < ($1.event?.startMinute ?? 0) } }
    }
}
