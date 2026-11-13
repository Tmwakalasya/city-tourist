import Foundation
import Testing
@testable import CityTourist

/// Reaching the end of a category in Explore asks for another page. These
/// share `PlacesAPITests`' suite because they share its stubbed session.
@MainActor
extension PlacesAPITests {
    private var lisbon: City { SampleData.cities[0] }

    private func liveCatalog() -> PlaceCatalog {
        PlaceCatalog(makeService: { GooglePlacesService(apiKey: "test-key", session: StubURLProtocol.makeSession()) })
    }

    private func place(_ id: String, primary: String = "restaurant", types: [String] = ["restaurant"],
                       latitude: Double = 38.71) -> String {
        """
        { "id": "\(id)", "displayName": { "text": "\(id)" }, "rating": 4.5, "userRatingCount": 100,
          "location": { "latitude": \(latitude), "longitude": -9.14 },
          "primaryType": "\(primary)", "types": \(types.map { "\"\($0)\"" }) }
        """
    }

    /// Answers discovery with the Lisbon fixture and each text search with the next of `pages`.
    private func stub(pages: [String]) {
        var remaining = pages
        StubURLProtocol.handler = { request in
            let isSearch = request.url!.absoluteString.contains("searchText")
            let json = isSearch ? (remaining.isEmpty ? #"{ "places": [] }"# : remaining.removeFirst()) : Fixtures.nearbyLisbon
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
    }

    private var searches: [URLRequest] {
        StubURLProtocol.recorded.filter { $0.url!.absoluteString.contains("searchText") }
    }

    @Test func theNextPageAddsOnlyNewPlacesOfThatCategoryNearby() async throws {
        StubURLProtocol.reset()
        let fresh = (1...6).map { place("more-\($0)") }
        stub(pages: ["""
        { "places": [\((fresh + [
            place("place-time-out"),
            place("a-museum", primary: "museum", types: ["museum"]),
            place("a-supermarket", primary: "supermarket", types: ["supermarket", "bakery"]),
            place("an-office", primary: "corporate_office", types: ["corporate_office"]),
            place("far-away", latitude: 39.5)
        ]).joined(separator: ","))] }
        """])
        let catalog = liveCatalog()
        await catalog.load(city: lisbon)
        let before = catalog.places(in: lisbon.id)
        #expect(catalog.hasMore(of: .food, in: lisbon))

        await catalog.loadMore(of: .food, in: lisbon)

        let added = catalog.morePlaces(in: lisbon.id, category: .food)
        #expect(added.map(\.id) == (1...6).map { "more-\($0)" },
                "not the place already listed, the museum, the supermarket, the office or the one in another town")
        #expect(catalog.places(in: lisbon.id) == before + added, "what was listed stays where it was")
        #expect(PlaceDirectory.place(id: "more-1") != nil)
        #expect(!catalog.hasMore(of: .food, in: lisbon), "no further page was offered")
        #expect(catalog.hasMore(of: .museum, in: lisbon), "each category keeps its own place")
        #expect(searches.count == 1)

        await catalog.loadMore(of: .food, in: lisbon)
        #expect(searches.count == 1, "nothing more to ask for")
    }

    @Test func aPageOfRepeatsIsFollowedByOneMoreAndThreePagesIsTheEnd() async throws {
        StubURLProtocol.reset()
        func page(_ ids: [String], next: String?) -> String {
            #"{ "places": [\#(ids.map { place($0) }.joined(separator: ","))]\#(next.map { #", "nextPageToken": "\#($0)""# } ?? "") }"#
        }
        stub(pages: [
            page(["place-time-out", "more-1"], next: "two"),
            page(["more-2", "more-3"], next: "three"),
            page(["more-4"], next: "four"),
            page(["never-asked-for"], next: nil)
        ])
        let catalog = liveCatalog()
        await catalog.load(city: lisbon)

        await catalog.loadMore(of: .food, in: lisbon)
        #expect(searches.count == 2, "one new place wasn't worth stopping for")
        #expect(searches.last?.stubBody?["pageToken"] as? String == "two")
        #expect(catalog.hasMore(of: .food, in: lisbon))

        await catalog.loadMore(of: .food, in: lisbon)
        #expect(searches.count == 3)
        #expect(!catalog.hasMore(of: .food, in: lisbon), "three pages is the limit")
        #expect(catalog.morePlaces(in: lisbon.id).map(\.id) == ["more-1", "more-2", "more-3", "more-4"])
    }

    @Test func aFailedPageCanBeTriedAgainAndARefreshStartsOver() async throws {
        StubURLProtocol.reset()
        var fail = true
        StubURLProtocol.handler = { request in
            let isSearch = request.url!.absoluteString.contains("searchText")
            let status = isSearch && fail ? 500 : 200
            let json = isSearch ? #"{ "places": [\#(place("more-1"))] }"# : Fixtures.nearbyLisbon
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
        let catalog = liveCatalog()
        await catalog.load(city: lisbon)

        await catalog.loadMore(of: .food, in: lisbon)
        #expect(catalog.failedToLoadMore(of: .food, in: lisbon))
        #expect(catalog.hasMore(of: .food, in: lisbon))

        fail = false
        await catalog.loadMore(of: .food, in: lisbon)
        #expect(!catalog.failedToLoadMore(of: .food, in: lisbon))
        #expect(catalog.morePlaces(in: lisbon.id).map(\.id) == ["more-1"])

        await catalog.load(city: lisbon, force: true)
        #expect(catalog.morePlaces(in: lisbon.id).isEmpty)
        #expect(catalog.hasMore(of: .food, in: lisbon))
    }

    @Test func aCityOnSampleDataHasNothingMoreToAskFor() async {
        let catalog = PlaceCatalog(makeService: { nil })
        await catalog.load(city: lisbon)
        #expect(!catalog.hasMore(of: .food, in: lisbon))
    }
}

/// Every category is a billed search, and seven on every launch was two
/// thirds of the Google bill.
@MainActor
extension PlacesAPITests {
    /// The categories asked for so far, by the first type each request names.
    private var nearbySearches: [String] {
        StubURLProtocol.recorded
            .filter { $0.url!.absoluteString.contains("searchNearby") }
            .compactMap { request in
                let body = request.stubBody
                return ((body?["includedTypes"] ?? body?["includedPrimaryTypes"]) as? [String])?.first
            }
    }

    /// Answers each category's search with one place of its own.
    private func stubOnePlacePerCategory() {
        StubURLProtocol.handler = { request in
            let body = request.stubBody
            let type = ((body?["includedTypes"] ?? body?["includedPrimaryTypes"]) as? [String])?.first ?? "none"
            let json = """
            { "places": [ { "id": "a-\(type)", "displayName": { "text": "\(type)" }, "rating": 4.5,
                "location": { "latitude": 38.71, "longitude": -9.14 }, "primaryType": "\(type)", "types": ["\(type)"] } ] }
            """
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
        }
    }

    @Test func aCityOpensWithTwoSearchesAndAsksForTheRestOnlyWhenWanted() async throws {
        StubURLProtocol.reset()
        stubOnePlacePerCategory()
        let city = SampleData.cities[0]
        let catalog = PlaceCatalog(makeService: { GooglePlacesService(apiKey: "test-key", session: StubURLProtocol.makeSession()) })

        await catalog.load(city: city, categories: PlaceCatalog.firstCategories)
        #expect(Set(nearbySearches) == ["tourist_attraction", "restaurant"])
        #expect(catalog.state == .loaded)
        #expect(catalog.unloadedCategories(in: city).count == 5)
        #expect(!catalog.hasMore(of: .museum, in: city), "a category not opened yet has no next page")
        let opening = catalog.places(in: city.id)

        // Opening a tab asks for that one category, and adds below what's there.
        await catalog.load(city: city, categories: [.museum])
        #expect(nearbySearches.count == 3)
        #expect(Array(catalog.places(in: city.id).prefix(opening.count)) == opening)
        #expect(catalog.places(in: city.id).last?.id == "a-museum")

        // Asking again costs nothing.
        await catalog.load(city: city, categories: PlaceCatalog.firstCategories + [.museum])
        #expect(nearbySearches.count == 3)

        // A plan needs the whole city: only the four not yet asked for.
        await catalog.load(city: city)
        #expect(nearbySearches.count == 7)
        #expect(catalog.unloadedCategories(in: city).isEmpty)
        #expect(Set(catalog.places(in: city.id).map(\.id)).count == 7)
    }

    @Test func twoScreensAskingForTheSameCategoryShareOneRequest() async throws {
        StubURLProtocol.reset()
        stubOnePlacePerCategory()
        let city = SampleData.cities[0]
        let catalog = PlaceCatalog(makeService: { GooglePlacesService(apiKey: "test-key", session: StubURLProtocol.makeSession()) })

        async let explore: () = catalog.load(city: city, categories: PlaceCatalog.firstCategories)
        async let today: () = catalog.load(city: city, categories: PlaceCatalog.firstCategories)
        async let plan: () = catalog.load(city: city)
        _ = await (explore, today, plan)

        #expect(nearbySearches.count == 7, "each category once, however many screens asked")
        #expect(Set(catalog.places(in: city.id).map(\.id)).count == 7)
    }

    @Test func aRefreshAsksAgainOnlyForWhatWasOpened() async throws {
        StubURLProtocol.reset()
        stubOnePlacePerCategory()
        let city = SampleData.cities[0]
        let catalog = PlaceCatalog(makeService: { GooglePlacesService(apiKey: "test-key", session: StubURLProtocol.makeSession()) })
        await catalog.load(city: city, categories: PlaceCatalog.firstCategories)

        await catalog.load(city: city, force: true, categories: catalog.loadedCategories(in: city))

        #expect(nearbySearches.count == 4)
        #expect(catalog.places(in: city.id).count == 2)
        #expect(catalog.loadedCategories(in: city) == PlaceCatalog.firstCategories)
    }
}
