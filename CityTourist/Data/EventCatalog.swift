import Foundation
import Observation

/// Session-only cache. Each provider owns an independent cursor; failures never erase another's results.
@MainActor @Observable
final class EventCatalog {
    private var cityFeeds: [String: EventFeed] = [:]
    private var tripFeeds: [Trip.ID: EventFeed] = [:]
    private var loadingCities = Set<String>()
    private var loadingTrips = Set<Trip.ID>()
    private let makeService: () -> TicketmasterService?
    private let makeEventbrite: () -> EventbriteService?

    init(makeService: @escaping () -> TicketmasterService? = { TicketmasterService() },
         makeEventbrite: @escaping () -> EventbriteService? = { EventbriteService() }) {
        self.makeService = makeService; self.makeEventbrite = makeEventbrite
    }
    private var aggregator: EventAggregator {
        var providers: [any EventProvider] = []
        if let service = makeService() { providers.append(service) }
        if let service = makeEventbrite() { providers.append(service) }
        return EventAggregator(providers: providers)
    }
    func events(for trip: Trip, on date: Date) -> [Place] {
        allEvents(for: trip).filter { $0.event?.localDate == WeatherService.dayKey(for: date) }
    }
    func allEvents(for trip: Trip) -> [Place] {
        let days = Set(trip.days.map { WeatherService.dayKey(for: $0.date) })
        return (tripFeeds[trip.id]?.events ?? []).filter { $0.event.map { days.contains($0.localDate) } ?? false }
    }
    func events(in cityID: String) -> [Place] {
        guard let feed = cityFeeds[cityID] else { return [] }
        let first = WeatherService.dayKey(for: feed.query.start), last = WeatherService.dayKey(for: feed.query.end)
        return feed.events.filter { $0.event.map { $0.localDate >= first && $0.localDate <= last } ?? false }
    }
    func isLoading(cityID: String) -> Bool { loadingCities.contains(cityID) }
    func hasMore(cityID: String) -> Bool {
        guard let feed = cityFeeds[cityID] else { return false }
        return aggregator.providers.contains { !feed.completed.contains($0.providerID) }
    }
    func hasMore(trip: Trip) -> Bool {
        guard let feed = tripFeeds[trip.id] else { return false }
        return aggregator.providers.contains { !feed.completed.contains($0.providerID) }
    }
    func hasFailure(cityID: String) -> Bool { !(cityFeeds[cityID]?.failed.isEmpty ?? true) }
    func hasFailure(trip: Trip) -> Bool { !(tripFeeds[trip.id]?.failed.isEmpty ?? true) }

    func load(city: City, force: Bool = false) async {
        guard !loadingCities.contains(city.id) else { return }
        if !force, let feed = cityFeeds[city.id], feed.failed.isEmpty { return }
        loadingCities.insert(city.id)
        defer { loadingCities.remove(city.id) }
        let service = aggregator
        guard !service.providers.isEmpty else { return }
        let start = Date.now, end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start
        let previous = cityFeeds[city.id]
        let initial = force ? nil : previous
        let feed = await service.next(initial ?? EventFeed(query: EventQuery(center: city.coordinate, cityID: city.id, start: start, end: end)))
        guard !Task.isCancelled else { return }
        // A failed refresh keeps the last rendered results.
        var final = feed
        if force, !feed.failed.isEmpty, let previous {
            let retained = previous.events.filter { feed.failed.contains($0.id.hasPrefix("eb:") ? "eventbrite" : "ticketmaster") }
            final.events = EventAggregator.normalized(feed.events + retained)
        }
        cityFeeds[city.id] = final
        PlaceDirectory.register(final.events)
    }
    func loadMore(city: City) async {
        guard !loadingCities.contains(city.id), let feed = cityFeeds[city.id] else { return }
        loadingCities.insert(city.id)
        defer { loadingCities.remove(city.id) }
        let result = await aggregator.next(feed)
        guard !Task.isCancelled else { return }
        cityFeeds[city.id] = result; PlaceDirectory.register(result.events)
    }
    func load(trip: Trip, city: City, more: Bool = false) async {
        guard !loadingTrips.contains(trip.id) else { return }
        let query = EventQuery(center: city.coordinate, cityID: city.id, start: trip.startDate, end: trip.endDate)
        let existing = tripFeeds[trip.id].flatMap { $0.query == query ? $0 : nil }
        if !more, let existing, existing.failed.isEmpty { return }
        loadingTrips.insert(trip.id)
        defer { loadingTrips.remove(trip.id) }
        let service = aggregator
        guard !service.providers.isEmpty else { return }
        let result = await service.next(existing ?? EventFeed(query: query))
        guard !Task.isCancelled else { return }
        tripFeeds[trip.id] = result; PlaceDirectory.register(result.events)
    }
}
