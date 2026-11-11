import Testing
import Foundation
@testable import CityTourist

/// A drafted trip is only a proposal: what comes out has to work.
struct TripBuilderTests {
    private let city = City(id: "test-city", name: "Test City", country: "", tagline: "",
                            coordinate: Coordinate(latitude: 38.71, longitude: -9.14))
    /// A Monday, then the days after it.
    private func dates(_ count: Int) -> [Date] {
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12))!
        return (0..<count).map { Calendar.current.date(byAdding: .day, value: $0, to: monday)! }
    }
    /// Long before the trip, so no day is "today".
    private let before = Date(timeIntervalSince1970: 1_700_000_000)

    private func place(_ id: String, _ category: PlaceCategory = .museum, minutes: Int = 60,
                       hours: WeeklyHours? = .alwaysOpen, latitude: Double = 38.71) -> Place {
        Place(id: id, name: id, cityID: city.id, category: category, neighborhood: "Centre",
              rating: 4.6, reviewCount: 200, priceLevel: 1, typicalMinutes: minutes,
              blurb: "", about: "", coordinate: Coordinate(latitude: latitude, longitude: -9.14),
              tags: [], weeklyHours: hours)
    }

    /// Open the same hours on each of `days` (Sunday is 0).
    private func open(_ days: [Int], from: Int, to: Int) -> WeeklyHours {
        WeeklyHours(spans: days.map { .init(start: $0 * 1440 + from, end: $0 * 1440 + to) })
    }

    private func builder(days: Int, now: Date? = nil) -> TripBuilder {
        TripBuilder(city: city, dates: dates(days), now: now ?? before)
    }

    private func day(_ stops: (String, Int)...) -> TripBuilder.DraftDay {
        .init(theme: "Theme", stops: stops.map { .init(placeID: $0.0, start: $0.1, reason: "Why") })
    }

    @Test func aDraftThatWorksIsKeptAsDrafted() {
        let places = [place("a"), place("lunch", .food), place("b")]
        let result = builder(days: 1).build([day(("a", 540), ("lunch", 750), ("b", 900))], from: places)

        #expect(result.days[0].stops.map(\.place.id) == ["a", "lunch", "b"])
        #expect(result.days[0].stops.map(\.start) == [540, 750, 900])
        #expect(result.days[0].theme == "Theme")
        #expect(result.days[0].stops[0].reason == "Why")
        #expect(result.fixes.isEmpty)
        #expect(result.retimed == 0)
    }

    @Test func travelPushesAStopDraftedTooSoonAfterTheLast() {
        let near = place("near"), far = place("far", latitude: 38.755)
        let result = builder(days: 1).build([day(("near", 540), ("far", 600))], from: [near, far])

        let hop = TravelEstimate.minutes(from: near.coordinate, to: far.coordinate) + TripBuilder.buffer
        #expect(hop > 20, "far enough that the draft's back-to-back times can't work")
        #expect(result.days[0].stops[1].start == (600 + hop + 4) / 5 * 5)
        #expect(result.retimed == 1)
        #expect(result.fixes.isEmpty)
    }

    @Test func aPlaceShutThatDayMovesToADayItIsOpen() throws {
        let museum = place("museum", hours: open([0, 2, 3, 4, 5, 6], from: 600, to: 1080))  // not Mondays
        let places = [museum, place("cafe", .food), place("park", .nature)]
        let result = builder(days: 2).build([day(("museum", 600), ("cafe", 780)), day(("park", 600))], from: places)

        #expect(result.days[0].stops.map(\.place.id) == ["cafe"])
        #expect(Set(result.days[1].stops.map(\.place.id)) == ["museum", "park"])
        #expect(result.fixes == [.moved(museum, from: 0, to: 1, closedThatDay: true)])
        let moved = try #require(result.days[1].stops.first { $0.place.id == "museum" })
        #expect(HoursNote.make(on: dates(2)[1], startMinute: moved.start, durationMinutes: 60,
                               hours: museum.weeklyHours) == nil)
        let park = try #require(result.days[1].stops.first { $0.place.id == "park" })
        #expect(park.start == 600, "the day it joins keeps its own times")
    }

    @Test func aPlaceShutEveryDayOfTheTripIsLeftOutAndSaidSo() {
        let museum = place("museum", hours: open([2, 3, 4, 5, 6, 0], from: 600, to: 1080))
        let result = builder(days: 1).build([day(("museum", 600), ("cafe", 780))],
                                            from: [museum, place("cafe", .food)])

        #expect(result.days[0].stops.map(\.place.id) == ["cafe"])
        #expect(result.fixes == [.dropped(museum, from: 0, closedThatDay: true)])
    }

    @Test func aStopDraftedBeforeOpeningWaitsForTheDoor() {
        let late = place("late", hours: open(Array(0..<7), from: 660, to: 1080))
        let result = builder(days: 1).build([day(("late", 540))], from: [late])

        #expect(result.days[0].stops.map(\.start) == [660])
        #expect(result.retimed == 1)
        #expect(result.fixes.isEmpty)
    }

    @Test func aStopDraftedPastClosingSwapsWithAnEarlierOne() {
        let museum = place("museum", minutes: 120, hours: open(Array(0..<7), from: 600, to: 1020))
        let result = builder(days: 1).build([day(("park", 600), ("museum", 960))],
                                            from: [museum, place("park", .nature)])

        #expect(result.days[0].stops.map(\.place.id) == ["museum", "park"])
        #expect(result.days[0].stops.map(\.start) == [600, 960])
        #expect(result.fixes == [.reordered(day: 0)])
        #expect(result.retimed == 0, "a reorder is reported once, not as moved times too")
    }

    @Test func inventedAndRepeatedPlacesAndExtraDaysAreLeftOut() {
        var concert = place("concert")
        concert.event = EventInfo(ticketURL: nil, localDate: "2026-10-12", startMinute: 1200, venue: "Hall", kind: "Music", price: nil)
        let places = [place("a"), place("b"), concert]
        let result = builder(days: 2).build([
            day(("a", 540), ("made-up", 660), ("concert", 900)),
            day(("a", 540), ("b", 660)),
            day(("b", 540))
        ], from: places)

        #expect(result.days.count == 2)
        #expect(result.days[0].stops.map(\.place.id) == ["a"])
        #expect(result.days[1].stops.map(\.place.id) == ["b"])
        #expect(result.fixes.isEmpty)
    }

    @Test func aDayNeverHoldsMoreStopsThanThePlannerCanOrder() {
        let places = (0..<10).map { place("p\($0)", minutes: 30) }
        let draft = TripBuilder.DraftDay(stops: places.enumerated().map {
            .init(placeID: $1.id, start: 540 + $0 * 60)
        })
        let result = builder(days: 1).build([draft], from: places)

        #expect(result.days[0].stops.count == TripBuilder.maxStopsPerDay)
    }

    /// Whatever the draft, the trip that comes out passes the checks the
    /// trip screen itself would run on it.
    @Test func everyStopInABuiltTripIsOpenAndReachable() {
        let weekdays = open([1, 2, 3, 4, 5], from: 600, to: 1020)
        let places = [
            place("museum", minutes: 120, hours: open([0, 3, 4, 5, 6], from: 600, to: 1080)),
            place("gallery", minutes: 90, hours: weekdays, latitude: 38.74),
            place("market", .activity, minutes: 60, hours: open(Array(0..<7), from: 480, to: 840), latitude: 38.70),
            place("lunch", .food, hours: open(Array(0..<7), from: 720, to: 900)),
            place("dinner", .food, minutes: 90, hours: open(Array(0..<7), from: 1080, to: 1380), latitude: 38.72),
            place("park", .nature, latitude: 38.76),
            place("bar", .nightlife, minutes: 120, hours: open([4, 5, 6], from: 1200, to: 1560)),
            place("tower", .attraction, minutes: 45, hours: weekdays, latitude: 38.69)
        ]
        let draft = [
            day(("museum", 540), ("market", 600), ("lunch", 610), ("bar", 1260), ("gallery", 1000)),
            day(("tower", 480), ("park", 500), ("dinner", 1020)),
            day()
        ]
        let trip = dates(3)
        let result = builder(days: 3).build(draft, from: places)

        #expect(result.stopCount >= 6)
        #expect(Set(result.days.flatMap(\.stops).map(\.place.id)).count == result.stopCount)
        for (index, day) in result.days.enumerated() {
            for stop in day.stops {
                #expect(HoursNote.make(on: trip[index], startMinute: stop.start,
                                       durationMinutes: stop.place.typicalMinutes,
                                       hours: stop.place.weeklyHours) == nil,
                        "\(stop.place.id) on day \(index) at \(stop.start)")
            }
            for (a, b) in zip(day.stops, day.stops.dropFirst()) {
                let hop = TravelEstimate.minutes(from: a.place.coordinate, to: b.place.coordinate)
                #expect(b.start >= a.start + a.place.typicalMinutes + hop, "\(a.place.id) → \(b.place.id)")
            }
        }
        let accounted = result.stopCount + result.fixes.filter {
            if case .dropped = $0 { return true }
            return false
        }.count
        #expect(accounted == places.count, "each place is either planned or reported as left out")
    }

    @Test func todayIsNotPlannedForATimeAlreadyGone() {
        let afternoon = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: dates(1)[0])!
        let result = builder(days: 1, now: afternoon).build([day(("a", 540), ("b", 1000))],
                                                            from: [place("a"), place("b")])

        #expect(result.days[0].stops.first?.start == 915)
        #expect(result.days[0].stops.allSatisfy { $0.start >= 915 })
    }

    @Test func aStarterTripFillsEachDayWithoutRepeatingAPlace() {
        let places = (0..<12).map { place("museum-\($0)") } + (0..<3).map { place("lunch-\($0)", .food) }
        let result = builder(days: 3).starter(among: places)

        #expect(result.days.count == 3)
        #expect(result.days.allSatisfy { !$0.stops.isEmpty })
        #expect(Set(result.days.flatMap(\.stops).map(\.place.id)).count == result.stopCount)
        #expect(result.days.allSatisfy { $0.stops.filter { $0.place.category == .food }.count == 1 })
        #expect(result.fixes.isEmpty)
    }

    @Test func aBuiltDayBecomesItineraryStopsAtTheCheckedTimes() {
        let result = builder(days: 1).build([day(("a", 545))], from: [place("a", minutes: 75)])
        let stop = result.days[0].stops[0].itineraryStop

        #expect(stop.placeID == "a")
        #expect(stop.startMinute == 545)
        #expect(stop.durationMinutes == 75)
    }

    // MARK: What the traveller is told

    @Test func eachFixIsSaidInPlainWords() {
        let museum = place("Museum"), bar = place("Bar")
        let result = TripBuilder.Result(days: [], fixes: [
            .moved(museum, from: 0, to: 1, closedThatDay: true),
            .reordered(day: 2),
            .dropped(bar, from: 0, closedThatDay: false)
        ], retimed: 2)
        let notes = TripBuilderView.notes(for: result, dates: dates(3))

        #expect(notes == [
            "Moved Museum to Tuesday. It’s closed on Mondays.",
            "Reordered Wednesday so every place is open when you get there.",
            "Left out Bar. Its hours didn’t fit any day.",
            "Moved 2 start times to allow for travel or opening times."
        ])
        #expect(TripBuilderView.notes(for: .init(days: []), dates: dates(1)).isEmpty)
    }

    @Test func theRequestIsWhatWasTypedPlusWhatWasTicked() {
        #expect(TripBuilderView.request(typed: "  ", phrases: []) == TripBuilderView.defaultRequest)
        #expect(TripBuilderView.request(typed: "Vegetarian food", phrases: ["slow mornings", "a proper night out"])
                == "Vegetarian food I’d like slow mornings, a proper night out.")
        #expect(TripBuilderView.request(typed: String(repeating: "x", count: 900), phrases: []).count == 500)
    }

    // MARK: Candidates

    @Test func candidatesLeadWithTheSearchAndThenTakeTheBestOfEachKindInTurn() {
        let searched = (0..<10).map { place("found-\($0)") }
        var ticketed = place("gig", .nightlife)
        ticketed.event = EventInfo(ticketURL: nil, localDate: "2026-10-12", startMinute: 1200, venue: "Hall", kind: "Music", price: nil)
        let catalog = (0..<6).map { place("food-\($0)", .food) } + (0..<6).map { place("park-\($0)", .nature) }
            + [searched[0], ticketed]
        let picked = TripDraftService.candidates(searched: searched, catalog: catalog, limit: 12)

        #expect(picked.count == 12)
        #expect(picked.prefix(4).map(\.id) == ["found-0", "found-1", "found-2", "found-3"])
        #expect(picked.dropFirst(4).filter { $0.category == .food }.count == 6, "food comes round twice")
        #expect(picked.dropFirst(4).filter { $0.category == .nature }.count == 2)
        #expect(Set(picked.map(\.id)).count == 12)
        #expect(!picked.contains { $0.id == "gig" })
    }

    @Test func clockTimesReadAsMinutes() {
        #expect(TripDraftService.minutes(fromClock: "09:30") == 570)
        #expect(TripDraftService.minutes(fromClock: "9:05") == 545)
        #expect(TripDraftService.minutes(fromClock: "23:59") == 1439)
        #expect(TripDraftService.minutes(fromClock: "24:00") == nil)
        #expect(TripDraftService.minutes(fromClock: "late") == nil)
        #expect(TripDraftService.minutes(fromClock: "10:60") == nil)
    }
}

/// The steps of one build, with the search and the model stood in for.
@MainActor
struct TripBuildingTests {
    private let city = SampleData.cities[0]
    private var places: [Place] { SampleData.places(in: "lisbon") }
    private var builder: TripBuilder {
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12))!
        return TripBuilder(city: city, dates: [monday], now: Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func aDraftIsCheckedBeforeItIsShown() async {
        let model = TripBuilding()
        let places = places
        await model.run(builder: builder, find: { places }, draft: { found in
            .init(summary: "A day by the river.", days: [
                .init(theme: "Belém", stops: [
                    .init(placeID: found[0].id, start: 600, reason: "The postcard view."),
                    .init(placeID: found[1].id, start: 605, reason: "Next door."),
                    .init(placeID: "not-a-place", start: 900)
                ])
            ])
        })

        #expect(model.phase == .ready)
        #expect(model.followsRequest)
        #expect(model.summary == "A day by the river.")
        let stops = model.result?.days.first?.stops ?? []
        #expect(stops.map(\.place.id) == [places[0].id, places[1].id])
        #expect(stops[1].start >= 600 + places[0].typicalMinutes, "the second stop waits for the first to end")
    }

    @Test func withoutAModelTheTripIsAStarterPlan() async {
        let model = TripBuilding()
        let places = places
        await model.run(builder: builder, find: { places }, draft: nil)

        #expect(model.phase == .ready)
        #expect(!model.followsRequest)
        #expect((model.result?.stopCount ?? 0) > 0)
    }

    @Test func aFailedDraftSaysSoAndCanBecomeAStarterPlan() async {
        let model = TripBuilding()
        let places = places
        await model.run(builder: builder, find: { places }, draft: { _ in throw TripDraftService.Failure.declined })

        guard case .failed(let message) = model.phase else {
            Issue.record("expected a visible failure")
            return
        }
        #expect(message == TripDraftService.Failure.declined.errorDescription)
        #expect(model.result == nil)

        model.useStarter(builder: builder)
        #expect(model.phase == .ready)
        #expect(!model.followsRequest)
    }

    @Test func noPlacesIsAFailureNotAnEmptyTrip() async {
        let model = TripBuilding()
        var askedTheModel = false
        await model.run(builder: builder, find: { [] }, draft: { _ in
            askedTheModel = true
            return .init(summary: "", days: [])
        })

        #expect(!askedTheModel)
        if case .failed = model.phase {} else { Issue.record("expected a failure") }
    }

    @Test func aStopCanBeTakenOutOfThePlan() async throws {
        let model = TripBuilding()
        let places = places
        await model.run(builder: builder, find: { places }, draft: nil)
        let first = try #require(model.result?.days.first?.stops.first)
        let count = model.result?.stopCount ?? 0

        model.remove(first)

        #expect(model.result?.stopCount == count - 1)
    }
}

/// The request to the server and its reply, against the shared stub; see
/// `PlacesAPITests`.
extension PlacesAPITests {

    private var tripPlaces: [Place] { Array(SampleData.places(in: "lisbon").prefix(3)) }
    private var tripDates: [Date] {
        let monday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 12))!
        return [monday, Calendar.current.date(byAdding: .day, value: 1, to: monday)!]
    }

    private func tripDrafts(budget: RequestBudget = .unlimited) -> TripDraftService {
        TripDraftService(session: StubURLProtocol.makeSession(), budget: budget)
    }

    private static let draftedTrip = """
    { "summary": "Two easy days by the river.", "days": [
        { "theme": "Belém", "stops": [
            { "id": "p2", "start": "09:30", "reason": "Cloisters before the crowds." },
            { "id": "p9", "start": "11:00", "reason": "Never sent." },
            { "id": "p1", "start": "soon", "reason": "No time." } ] },
        { "theme": "Pastries", "stops": [ { "id": "p3", "start": "10:00", "reason": "Warm from the oven." } ] } ] }
    """

    @Test func aTripDraftRequestCarriesTheTripAndNothingPrivate() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(json: Self.draftedTrip)
        var places = tripPlaces
        places[0].photoName = "places/secret/photos/not-for-the-model"

        _ = try await tripDrafts().draft(request: "Slow mornings", city: SampleData.cities[0],
                                         dates: tripDates, candidates: places)

        let sent = try #require(StubURLProtocol.recorded.first)
        #expect(sent.url?.absoluteString == "https://citytourist.pages.dev/api/ai/trip")
        #expect(sent.httpMethod == "POST")
        #expect(sent.value(forHTTPHeaderField: "x-api-key") == nil, "the key lives on the server")
        #expect(sent.value(forHTTPHeaderField: "Authorization") == nil)

        let payload = try #require(sent.stubBody)
        #expect(payload["model"] == nil && payload["system"] == nil && payload["messages"] == nil,
                "the prompt and the model are the server's to choose")
        let message = String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
        #expect(payload["request"] as? String == "Slow mornings")
        #expect(payload["language"] as? String == "English")
        let days = try #require(payload["days"] as? [[String: Any]])
        #expect(days.map { $0["weekday"] as? String } == ["Monday", "Tuesday"])
        #expect(days.first?["date"] as? String == "2026-10-12")
        let sentPlaces = try #require(payload["places"] as? [[String: Any]])
        #expect(sentPlaces.map { $0["id"] as? String } == ["p1", "p2", "p3"])
        #expect(sentPlaces.first?["name"] as? String == places[0].name)
        #expect(!message.contains("not-for-the-model"))
        #expect(!message.contains(places[0].id), "Google's ids stay in the app")
    }

    @Test func aDraftedTripComesBackAsPlacesAndTimes() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(json: Self.draftedTrip)

        let draft = try await tripDrafts().draft(request: "Slow mornings", city: SampleData.cities[0],
                                                 dates: tripDates, candidates: tripPlaces)

        #expect(draft.summary == "Two easy days by the river.")
        #expect(draft.days.map(\.theme) == ["Belém", "Pastries"])
        #expect(draft.days[0].stops == [.init(placeID: tripPlaces[1].id, start: 570,
                                              reason: "Cloisters before the crowds.")],
                "an id that wasn't sent and a time that isn't one are left out")
        #expect(draft.days[1].stops.map(\.placeID) == [tripPlaces[2].id])
    }

    @Test func aDeclinedCutOffOrUnreadableDraftIsAnError() async {
        for (status, json, expected) in [
            (422, #"{"error":"That request couldn't be planned."}"#, TripDraftService.Failure.declined),
            (200, String(Self.draftedTrip.prefix(80)), .invalidReply),
            (200, "Here is your trip!", .invalidReply),
            (200, "{}", .invalidReply)
        ] {
            StubURLProtocol.reset()
            StubURLProtocol.respond(status: status, json: json)
            await #expect(throws: expected) {
                _ = try await tripDrafts().draft(request: "x", city: SampleData.cities[0],
                                                 dates: tripDates, candidates: tripPlaces)
            }
        }
    }

    @Test func aServerFailureIsReportedWithoutTheServersWords() async {
        for status in [429, 502, 503] {
            StubURLProtocol.reset()
            StubURLProtocol.respond(status: status, json: #"{"error":"upstream said sk-ant-leaked"}"#)

            do {
                _ = try await tripDrafts().draft(request: "x", city: SampleData.cities[0],
                                                 dates: tripDates, candidates: tripPlaces)
                Issue.record("a \(status) should fail")
            } catch {
                #expect(!error.localizedDescription.contains("sk-ant"))
                #expect(error.localizedDescription.localizedCaseInsensitiveContains("try again"))
            }
        }
    }

    /// Everything in the bundle can be read out of the app, so a key that
    /// spends money for whoever holds it must never be in it.
    @Test func noClaudeKeyShipsInTheApp() throws {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist") else { return }
        // A Bool on its own line: a failed expectation prints what it compared,
        // and that must never be the file's contents.
        let holdsClaudeKey = String(decoding: try Data(contentsOf: url), as: UTF8.self).contains("sk-ant-")
        #expect(!holdsClaudeKey,
                "Secrets.plist holds a Claude key. Remove that row: the key belongs to the server (launch/README.md).")
    }

    @Test func aTripDraftOverThePhonesAllowanceSendsNothing() async {
        StubURLProtocol.reset()
        StubURLProtocol.respond(json: Self.draftedTrip)
        let spent = RequestBudget(name: "test", limits: .init(perMinute: 0, perDay: 0), defaults: nil)

        await #expect(throws: TripDraftService.Failure.rateLimited) {
            _ = try await tripDrafts(budget: spent).draft(request: "x", city: SampleData.cities[0],
                                                          dates: tripDates, candidates: tripPlaces)
        }
        #expect(StubURLProtocol.recorded.isEmpty)
    }

    @Test func anOfflineTripDraftIsHandedBack() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let budget = RequestBudget(name: "test", limits: .init(perMinute: 1, perDay: 1), defaults: nil)
        let service = tripDrafts(budget: budget)

        await #expect(throws: URLError.self) {
            _ = try await service.draft(request: "x", city: SampleData.cities[0],
                                        dates: tripDates, candidates: tripPlaces)
        }
        StubURLProtocol.respond(json: Self.draftedTrip)
        let draft = try await service.draft(request: "x", city: SampleData.cities[0],
                                            dates: tripDates, candidates: tripPlaces)
        #expect(!draft.days.isEmpty, "back online, the one draft left still goes out")
    }

    @Test func onlyAWeekAndSixtyPlacesAreSent() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(json: Self.draftedTrip)
        let monday = tripDates[0]
        let fortnight = (0..<14).map { Calendar.current.date(byAdding: .day, value: $0, to: monday)! }
        let many = (0..<80).map { index -> Place in
            var place = tripPlaces[0]
            place.id = "place-\(index)"
            return place
        }

        _ = try await tripDrafts().draft(request: "x", city: SampleData.cities[0], dates: fortnight, candidates: many)

        let payload = try #require(StubURLProtocol.recorded.first?.stubBody)
        #expect((payload["days"] as? [Any])?.count == TripDraftService.maxDays)
        #expect((payload["places"] as? [Any])?.count == TripDraftService.maxCandidates)
    }
}
