import Testing
import Foundation
@testable import CityTourist

@MainActor
struct AIRecommendationTests {
    private var places: [Place] { Array(SampleData.places(in: "lisbon").prefix(3)) }

    @Test func anInventedOrRepeatedPlaceIsRejected() throws {
        for ids in [["invented-place"], [places[0].id, places[0].id]] {
            let reply = AIRecommendationService.Reply(
                picks: ids.map { .init(id: $0, reason: "Nearby museum", caveat: "") }, summary: "A few options")
            #expect(throws: AIRecommendationService.Failure.self) {
                try AIRecommendationService.resolve(reply, candidates: places)
            }
        }
    }

    @Test func aVerifiedPickKeepsTheOriginalPlaceAndCanBeSavedOrPlanned() throws {
        let place = places[0]
        let reply = AIRecommendationService.Reply(
            picks: [.init(id: place.id, reason: "A landmark for a little culture.", caveat: "Check opening hours.")],
            summary: "One option to explore.")
        let result = try AIRecommendationService.resolve(reply, candidates: places)
        #expect(result.picks.first?.place == place)
        let store = AppStore(loadFromDisk: false)
        store.toggleSaved(result.picks[0].place)
        #expect(store.isSaved(place))
        let trip = store.createTrip(city: SampleData.cities[0], start: .now, end: .now, title: "AI test")
        store.addStop(place: result.picks[0].place, to: trip.id, dayIndex: 0, startMinute: 720)
        #expect(store.trip(id: trip.id)?.days.first?.stops.first?.placeID == place.id)
    }

    @Test func candidatePayloadExcludesKeysPhotosTripsAndDefaultPrices() throws {
        var place = places[0]
        place.photoName = "photos/not-for-the-model"
        place.imageURL = URL(string: "https://example.test/photo?key=not-for-the-model")
        let data = try JSONEncoder().encode(AIPlaceCandidate(place: place, city: SampleData.cities[0]))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["id"] as? String == place.id)
        #expect(object["distanceMetresFromCentre"] != nil)
        #expect(object["priceLevel"] == nil)
        #expect(object["photoURL"] == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains("not-for-the-model"))
    }

    @Test func emptySearchSkipsClaude() async {
        let model = AIRecommendations()
        var calledClaude = false
        await model.run(query: "coffee", find: { _ in [] }, choose: { _, _ in
            calledClaude = true
            return .init(picks: [], summary: "")
        })
        #expect(model.phase == .ready)
        #expect(!calledClaude)
        #expect(model.picks.isEmpty)
    }

    @Test func editingDuringARequestDiscardsItsLateReply() async {
        let model = AIRecommendations()
        await model.run(query: "coffee", find: { _ in places }, choose: { _, _ in
            model.reset()
            return .init(picks: [.init(place: places[0], reason: "Old", caveat: "")], summary: "Old")
        })
        #expect(model.phase == .idle)
        #expect(model.picks.isEmpty)
    }

    @Test func anOlderResponseCannotReplaceANewerRequest() async {
        let model = AIRecommendations()
        await model.run(query: "coffee", find: { _ in places }, choose: { _, _ in
            await model.run(query: "museums", find: { _ in places }, choose: { _, _ in
                .init(picks: [.init(place: places[1], reason: "New", caveat: "")], summary: "New")
            })
            return .init(picks: [.init(place: places[0], reason: "Old", caveat: "")], summary: "Old")
        })
        #expect(model.summary == "New")
        #expect(model.picks.first?.id == places[1].id)
    }

    @Test func longRequestsAreRejectedBeforeAnyNetworkWork() async {
        let model = AIRecommendations()
        var searched = false
        await model.run(query: String(repeating: "x", count: 301), find: { _ in
            searched = true
            return places
        }, choose: { _, _ in .init(picks: [], summary: "") })
        #expect(!searched)
        if case .failed = model.phase {} else { Issue.record("Expected a visible validation error") }
    }

    @Test func searchFailureIsNotPresentedAsNoMatches() async {
        let model = AIRecommendations()
        await model.run(query: "coffee", find: { _ in throw URLError(.notConnectedToInternet) },
                        choose: { _, _ in .init(picks: [], summary: "") })
        if case .failed = model.phase {} else { Issue.record("Expected a visible network error") }
    }

    @Test func iconicNightclubsOutrankSmallBarsGolfClubsAndCatalogMuseums() {
        let city = SampleData.cities[0]
        let liv = Place(
            id: "miami-liv", name: "LIV", cityID: city.id, category: .nightlife,
            neighborhood: "4441 Collins Ave, Miami Beach", rating: 3.6, reviewCount: 2650,
            priceLevel: 4, typicalMinutes: 180, blurb: "Night club", about: "Night club in Miami Beach.",
            coordinate: city.coordinate, tags: ["Night Club", "Bar"], isOpenNow: false
        )
        let smallWineBar = Place(
            id: "miami-wine", name: "Quiet Corner Wine", cityID: city.id, category: .nightlife,
            neighborhood: "Brickell", rating: 4.8, reviewCount: 38,
            priceLevel: 2, typicalMinutes: 90, blurb: "Wine bar", about: "Cozy wine bar.",
            coordinate: city.coordinate, tags: ["Wine Bar", "Bar"], isOpenNow: true
        )
        let golfClub = Place(
            id: "miami-golf", name: "Miami Beach Golf Club", cityID: city.id, category: .activity,
            neighborhood: "Miami Beach", rating: 4.7, reviewCount: 900,
            priceLevel: 3, typicalMinutes: 180, blurb: "Golf club", about: "Public golf club.",
            coordinate: city.coordinate, tags: ["Golf Course"], isOpenNow: true
        )
        let catalogMuseum = Place(
            id: "miami-museum", name: "Grand Art Museum", cityID: city.id, category: .museum,
            neighborhood: "Downtown", rating: 4.9, reviewCount: 5000,
            priceLevel: 2, typicalMinutes: 120, blurb: "Art museum", about: "Major museum.",
            coordinate: city.coordinate, tags: ["Museum"], isOpenNow: true
        )

        let queries = AIRecommendationService.searchQueries(for: "best clubs and nightlife tonight")
        #expect(queries.contains { $0.contains("nightclub") })
        #expect(!queries.contains { $0.contains("wine bar") })

        let ranked = AIRecommendationService.rankCandidates(
            [smallWineBar, liv, golfClub],
            catalog: [catalogMuseum],
            query: "clubs and nightlife",
            city: city
        )
        #expect(ranked.first?.id == "miami-liv")
        #expect(ranked.last?.id == "miami-golf")
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["CITYTOURIST_LIVE_AI_TEST"] == "1"))
    func livePlacesThroughTheServerReturnUsablePicks() async throws {
        let google = try #require(GooglePlacesService())
        let city = SampleData.cities[0]
        let candidates = try await google.searchPlaces(query: "Coffee and pastries", city: city).places
        #expect(!candidates.isEmpty)
        let result = try await AIRecommendationService().recommend(
            query: "Coffee and pastries", city: city, candidates: candidates)
        #expect(!result.picks.isEmpty)
        #expect(result.picks.count <= 3)
        #expect(result.picks.allSatisfy { pick in candidates.contains { $0.id == pick.id } })
    }
}

// Share the existing serialized URLProtocol suite to avoid races with Places
// and YouTube fixtures, whose session stub also has process-wide state.
extension PlacesAPITests {
    @Test func aiRelayRequestAndResponseUseOnlySearchCandidates() async throws {
        StubURLProtocol.reset()
        let place = SampleData.places(in: "lisbon")[0]
        StubURLProtocol.respond(json: """
        {"summary":"Try this landmark.","picks":[{"id":"\(place.id)","reason":"A cultural stop.","caveat":"Check opening hours."}]}
        """)
        let service = AIRecommendationService(session: StubURLProtocol.makeSession())
        let result = try await service.recommend(query: "a little culture", city: SampleData.cities[0], candidates: [place])
        let request = try #require(StubURLProtocol.recorded.first)
        #expect(request.url?.absoluteString == "https://citytourist.pages.dev/api/ai/concierge")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "x-api-key") == nil, "the key lives on the server")
        #expect(request.stubBody?["model"] == nil && request.stubBody?["system"] == nil,
                "the prompt and the model are the server's to choose")
        #expect(request.stubBody?["query"] as? String == "a little culture")
        #expect(result.picks.first?.place == place)
    }

    @Test func aiRelayFailureAndMalformedOutputAreErrors() async {
        for (status, json) in [(429, #"{"error":"That's all for today. Try again tomorrow."}"#),
                               (502, #"{"error":"upstream said sk-ant-leaked"}"#),
                               (503, #"{"error":"Busy right now."}"#),
                               (200, #"{"summary":"Try this","picks":[{"id":"invented","reason":"Great","caveat":""}]}"#),
                               (200, "not JSON")] {
            StubURLProtocol.reset()
            StubURLProtocol.respond(status: status, json: json)
            do {
                _ = try await AIRecommendationService(session: StubURLProtocol.makeSession())
                    .recommend(query: "coffee", city: SampleData.cities[0], candidates: SampleData.places(in: "lisbon"))
                Issue.record("The invalid response must not become successful recommendations")
            } catch {
                #expect(error is AIRecommendationService.Failure)
                #expect(!error.localizedDescription.contains("sk-ant"), "the server's words aren't shown")
            }
        }
    }

    @Test func aiConciergeRespectsPerDeviceDailyBudget() async throws {
        StubURLProtocol.reset()
        let place = SampleData.places(in: "lisbon")[0]
        let defaults = UserDefaults(suiteName: "AIRecommendationBudgetTests-\(UUID().uuidString)")!
        let budget = RequestBudget(
            name: "testAIConcierge",
            limits: .init(perMinute: 5, perDay: 2),
            defaults: defaults
        )
        let service = AIRecommendationService(session: StubURLProtocol.makeSession(), budget: budget)

        for _ in 0..<2 {
            StubURLProtocol.respond(json: """
            {"summary":"Try this landmark.","picks":[{"id":"\(place.id)","reason":"A cultural stop.","caveat":""}]}
            """)
            _ = try await service.recommend(query: "culture", city: SampleData.cities[0], candidates: [place])
        }

        do {
            _ = try await service.recommend(query: "culture", city: SampleData.cities[0], candidates: [place])
            Issue.record("Expected third request to be blocked by daily RequestBudget")
        } catch {
            #expect(AIRecommendationService.isRateLimited(error))
        }
    }
}
