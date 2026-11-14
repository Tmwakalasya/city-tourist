import Testing
import Foundation
@testable import CityTourist

/// Short videos on place pages: matching, durations and the links out.
@MainActor
struct PlaceShortsTests {

    @Test func youTubeDurationsReadAsSeconds() {
        #expect(YouTubeService.seconds(fromISO8601: "PT45S") == 45)
        #expect(YouTubeService.seconds(fromISO8601: "PT1M5S") == 65)
        #expect(YouTubeService.seconds(fromISO8601: "PT2M") == 120)
        #expect(YouTubeService.seconds(fromISO8601: "PT1H2M3S") == 3723)
        #expect(YouTubeService.seconds(fromISO8601: "P0D") == nil, "a live stream has no length")
        #expect(YouTubeService.seconds(fromISO8601: "PTM") == nil)
    }

    @Test func aVideoMustNameThePlace() {
        #expect(YouTubeService.isAbout("Wynwood Walls", text: "Day out #wynwoodwalls #miami"))
        #expect(YouTubeService.isAbout("Wynwood Walls", text: "Exploring Wynwood!"), "half the name is enough")
        #expect(YouTubeService.isAbout("Pastéis de Belém", text: "Trying PASTEIS DE BELEM in Lisbon"))
        #expect(!YouTubeService.isAbout("Wynwood Walls", text: "Miami Beach sunset"))
        #expect(!YouTubeService.isAbout("IHOP", text: "Best breakfast in Miami"))
        #expect(!YouTubeService.isAbout("The Bar", text: "the bar"), "nothing distinctive to match")
    }

    @Test func tikTokAndInstagramOpenTheirOwnSearch() throws {
        let place = try #require(SampleData.places(in: "lisbon").first)
        let city = SampleData.cities[0]

        let tikTok = URLComponents(url: PlaceShorts.tikTokURL(for: place, in: city), resolvingAgainstBaseURL: false)
        #expect(tikTok?.host == "www.tiktok.com")
        #expect(tikTok?.queryItems?.first?.value == "\(place.name) \(city.name)")
        #expect(PlaceShorts.instagramURL(for: place)?.absoluteString
                == "https://www.instagram.com/explore/tags/belemtower/")
    }

    @Test func popularDishesGenerationForFoodVenues() throws {
        // 1. Curated Restaurants & Cafés
        let belem = try #require(SampleData.place(id: "lis-pasteis-belem"))
        let belemItems = PopularDishesService.popularItems(for: belem)
        #expect(belemItems.count == 5)
        #expect(belemItems.contains { $0.name == "Pastel de Belém" && $0.imageURL != nil && $0.price != nil })
        #expect(PopularDishesService.hasItems(for: belem))
        #expect(PopularDishesService.venueKind(for: belem) == .restaurantCafe)

        let contramar = try #require(SampleData.place(id: "mex-contramar"))
        let contramarItems = PopularDishesService.popularItems(for: contramar)
        #expect(contramarItems.count == 5)
        #expect(contramarItems.contains { $0.name == "Tostadas de Atún Fresco" && $0.imageURL != nil && $0.price != nil })
        #expect(PopularDishesService.venueKind(for: contramar) == .restaurantCafe)

        // 2. Curated Bars & Nightlife
        let pensao = try #require(SampleData.place(id: "lis-pensao-amor"))
        let pensaoItems = PopularDishesService.popularItems(for: pensao)
        #expect(pensaoItems.count == 5)
        #expect(pensaoItems.contains { $0.name.contains("Amor") && $0.imageURL != nil && $0.price != nil })
        #expect(PopularDishesService.hasItems(for: pensao))
        #expect(PopularDishesService.venueKind(for: pensao) == .barNightlife)

        let pontocho = try #require(SampleData.place(id: "kyo-pontocho"))
        let pontochoItems = PopularDishesService.popularItems(for: pontocho)
        #expect(pontochoItems.count == 5)
        #expect(pontochoItems.contains { $0.name.contains("Yakitori") && $0.imageURL != nil })
        #expect(PopularDishesService.venueKind(for: pontocho) == .barNightlife)

        // 3. Curated Culinary Hubs
        let lxfactory = try #require(SampleData.place(id: "lis-lx-factory"))
        let lxItems = PopularDishesService.popularItems(for: lxfactory)
        #expect(lxItems.count == 5)
        #expect(lxItems.contains { $0.name.contains("Landeau") })
        #expect(PopularDishesService.venueKind(for: lxfactory) == .culinaryHub)

        let gion = try #require(SampleData.place(id: "kyo-gion"))
        let gionItems = PopularDishesService.popularItems(for: gion)
        #expect(gionItems.count == 5)
        #expect(gionItems.contains { $0.name.contains("Matcha") && $0.imageURL != nil })
        #expect(PopularDishesService.venueKind(for: gion) == .culinaryHub)

        let timeout = try #require(SampleData.place(id: "lis-timeout"))
        #expect(PopularDishesService.venueKind(for: timeout) == .culinaryHub)

        // 4. Live / Google Places dining venues (e.g. Hygge Kaffe)
        let hyggeKaffe = Place(
            id: "lis-hygge-kaffe",
            name: "Hygge Kaffe",
            cityID: "lisbon",
            category: .food,
            neighborhood: "Saldanha",
            rating: 4.6,
            reviewCount: 840,
            priceLevel: 2,
            typicalMinutes: 45,
            blurb: "Nordic specialty coffee & brunch cafe",
            about: "Danish inspired cozy cafe serving flat whites and cinnamon buns.",
            coordinate: Coordinate(latitude: 38.7330, longitude: -9.1480),
            tags: ["Coffee", "Cafe", "Brunch"]
        )
        #expect(PopularDishesService.hasItems(for: hyggeKaffe))
        let hyggeAngles = PlaceShorts.vibeAngles(for: hyggeKaffe)
        #expect(hyggeAngles.contains { $0.label == "Must-order" })
        let hyggeItems = PopularDishesService.popularItems(for: hyggeKaffe)
        #expect(hyggeItems.count == 5)
        #expect(hyggeItems.contains { $0.name.contains("Cinnamon") && $0.imageURL != nil })
        #expect(PopularDishesService.venueKind(for: hyggeKaffe) == .restaurantCafe)

        // 5. Vibe angles include Must-order for food, bars, and culinary places
        let belemAngles = PlaceShorts.vibeAngles(for: belem)
        #expect(belemAngles.contains { $0.label == "Must-order" })

        let pensaoAngles = PlaceShorts.vibeAngles(for: pensao)
        #expect(pensaoAngles.contains { $0.label == "Must-order" })

        let gionAngles = PlaceShorts.vibeAngles(for: gion)
        #expect(gionAngles.contains { $0.label == "Must-order" })

        // 6. Non-menu venues return empty and do not have Must-order
        let tower = try #require(SampleData.place(id: "lis-belem-tower"))
        #expect(PopularDishesService.popularItems(for: tower).isEmpty)
        #expect(!PopularDishesService.hasItems(for: tower))
        let towerAngles = PlaceShorts.vibeAngles(for: tower)
        #expect(!towerAngles.contains { $0.label == "Must-order" })
    }

    @Test func realReviewsForSampleVenues() async throws {
        let belem = try #require(SampleData.place(id: "lis-pasteis-belem"))
        let reviews = await PlaceReviewsService.fetchReviews(for: belem)
        #expect(!reviews.isEmpty)
        #expect(reviews.allSatisfy { $0.rating >= 4 })
        #expect(reviews.allSatisfy { !$0.author.isEmpty && !$0.comment.isEmpty })
    }

    @Test func countryBasedCurrencyResolution() {
        // Country symbol resolution
        #expect(PopularDishesService.currencySymbol(for: "Portugal") == "€")
        #expect(PopularDishesService.currencySymbol(for: "Spain") == "€")
        #expect(PopularDishesService.currencySymbol(for: "France") == "€")
        #expect(PopularDishesService.currencySymbol(for: "Italy") == "€")
        #expect(PopularDishesService.currencySymbol(for: "Germany") == "€")
        #expect(PopularDishesService.currencySymbol(for: "Japan") == "¥")
        #expect(PopularDishesService.currencySymbol(for: "Mexico") == "$ MXN")
        #expect(PopularDishesService.currencySymbol(for: "United Kingdom") == "£")
        #expect(PopularDishesService.currencySymbol(for: "Canada") == "$ CAD")
        #expect(PopularDishesService.currencySymbol(for: "Australia") == "$ AUD")
        #expect(PopularDishesService.currencySymbol(for: "Switzerland") == "CHF")
        #expect(PopularDishesService.currencySymbol(for: "United States") == "$")

        // Currency resolution for places by country
        let lisbonPlace = Place(
            id: "test-lisbon-cafe",
            name: "Hygge Kaffe",
            cityID: "lisbon",
            category: .food,
            neighborhood: "R. Tomás Ribeiro 95B, Lisboa",
            rating: 4.6,
            reviewCount: 500,
            priceLevel: 2,
            typicalMinutes: 45,
            blurb: "Nordic cafe",
            about: "Danish cafe in Lisbon",
            coordinate: Coordinate(latitude: 38.7330, longitude: -9.1480),
            tags: ["Coffee", "Cafe"]
        )
        #expect(PopularDishesService.country(for: lisbonPlace) == "Portugal")
        #expect(PopularDishesService.currency(for: lisbonPlace) == "€")
        let lisbonItems = PopularDishesService.popularItems(for: lisbonPlace)
        #expect(lisbonItems.allSatisfy { $0.price?.contains("€") == true })

        let londonPlace = Place(
            id: "test-london-pub",
            name: "The Churchill Arms",
            cityID: "london",
            category: .nightlife,
            neighborhood: "Kensington, London, UK",
            rating: 4.5,
            reviewCount: 1200,
            priceLevel: 2,
            typicalMinutes: 60,
            blurb: "Historic pub",
            about: "Famous floral pub serving real ales",
            coordinate: Coordinate(latitude: 51.5074, longitude: -0.1950),
            tags: ["Pub", "Beer"]
        )
        #expect(PopularDishesService.country(for: londonPlace) == "United Kingdom")
        #expect(PopularDishesService.currency(for: londonPlace) == "£")
        let londonItems = PopularDishesService.popularItems(for: londonPlace)
        #expect(londonItems.allSatisfy { $0.price?.contains("£") == true })

        let tokyoPlace = Place(
            id: "test-tokyo-ramen",
            name: "Afuri Ramen",
            cityID: "tokyo",
            category: .food,
            neighborhood: "Ebisu, Tokyo, Japan",
            rating: 4.7,
            reviewCount: 2000,
            priceLevel: 2,
            typicalMinutes: 40,
            blurb: "Yuzu ramen shop",
            about: "Delicate chicken broth with yuzu citrus",
            coordinate: Coordinate(latitude: 35.6467, longitude: 139.7101),
            tags: ["Ramen", "Noodles"]
        )
        #expect(PopularDishesService.country(for: tokyoPlace) == "Japan")
        #expect(PopularDishesService.currency(for: tokyoPlace) == "¥")
        let tokyoItems = PopularDishesService.popularItems(for: tokyoPlace)
        #expect(tokyoItems.allSatisfy { $0.price?.contains("¥") == true })

        let nyPlace = Place(
            id: "test-ny-pizza",
            name: "Joe's Pizza",
            cityID: "new-york",
            category: .food,
            neighborhood: "Greenwich Village, New York, NY, USA",
            rating: 4.8,
            reviewCount: 3500,
            priceLevel: 1,
            typicalMinutes: 30,
            blurb: "Classic NY slice joint",
            about: "Fresh hot plain and pepperoni slices",
            coordinate: Coordinate(latitude: 40.7306, longitude: -74.0021),
            tags: ["Pizza", "Italian"]
        )
        #expect(PopularDishesService.country(for: nyPlace) == "United States")
        #expect(PopularDishesService.currency(for: nyPlace) == "$")
        let nyItems = PopularDishesService.popularItems(for: nyPlace)
        #expect(nyItems.allSatisfy { $0.price?.contains("$") == true })
    }
}

/// YouTube's two calls, against the shared stub; see `PlacesAPITests`.
extension PlacesAPITests {

    private enum YouTubeFixtures {
        /// Relevance order: a long tour, the match, an unrelated video, a
        /// hashtag-only match, a channel, and a live stream.
        static let search = """
        { "items": [
            { "id": { "videoId": "long1" } }, { "id": { "videoId": "good1" } },
            { "id": { "videoId": "other" } }, { "id": { "videoId": "tag1" } },
            { "id": { "channelId": "chan" } }, { "id": { "videoId": "live1" } } ] }
        """

        /// Not in the search's order, as YouTube doesn't promise one.
        static let videos = """
        { "items": [
            { "id": "tag1", "snippet": { "title": "Lisbon day 2", "description": "#belemtower #lisbon",
                "channelTitle": "Kendle", "liveBroadcastContent": "none" },
              "contentDetails": { "duration": "PT1M5S" }, "statistics": {} },
            { "id": "other", "snippet": { "title": "Lisbon food tour", "channelTitle": "Eats",
                "liveBroadcastContent": "none" },
              "contentDetails": { "duration": "PT50S" }, "statistics": { "viewCount": "900" } },
            { "id": "good1", "snippet": { "title": "Belem Tower at sunset", "channelTitle": "angel",
                "liveBroadcastContent": "none",
                "thumbnails": { "high": { "url": "https://i.ytimg.com/vi/good1/hqdefault.jpg" } } },
              "contentDetails": { "duration": "PT45S" }, "statistics": { "viewCount": "240100" } },
            { "id": "long1", "snippet": { "title": "Belém Tower full tour", "channelTitle": "Guide",
                "liveBroadcastContent": "none" },
              "contentDetails": { "duration": "PT12M3S" }, "statistics": { "viewCount": "5" } },
            { "id": "live1", "snippet": { "title": "Belém Tower live cam", "channelTitle": "Cam",
                "liveBroadcastContent": "live" },
              "contentDetails": { "duration": "P0D" }, "statistics": {} } ] }
        """

        /// Answers each call from its own fixture.
        static func respond(search: String = search, videos: String = videos) {
            StubURLProtocol.handler = { request in
                let body = request.url?.path.hasSuffix("/search") == true ? search : videos
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
                                               headerFields: ["Content-Type": "application/json"])!
                return (response, Data(body.utf8))
            }
        }
    }

    private var belemTower: Place { SampleData.places(in: "lisbon")[0] }
    private var lisbon: City { SampleData.cities[0] }

    private func youTube(budget: RequestBudget = .unlimited) -> YouTubeService {
        YouTubeService(apiKey: "test-key", session: StubURLProtocol.makeSession(), budget: budget)
    }

    @Test func youTubeSearchesForShortEmbeddableVideosOfThePlace() async throws {
        StubURLProtocol.reset()
        YouTubeFixtures.respond()

        _ = try await youTube().shorts(for: belemTower, in: lisbon)

        let search = try #require(StubURLProtocol.recorded.first)
        let query = URLComponents(url: search.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name == name }?.value }
        #expect(search.url?.path == "/youtube/v3/search")
        #expect(value("q") == "\(belemTower.name) Lisbon")
        #expect(value("type") == "video")
        #expect(value("videoDuration") == "short")
        #expect(value("videoEmbeddable") == "true")
        #expect(value("key") == nil, "the key goes in a header, not the URL")
        #expect(search.value(forHTTPHeaderField: "X-Goog-Api-Key") == "test-key")
        #expect(search.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier") == Bundle.main.bundleIdentifier)

        let details = try #require(StubURLProtocol.recorded.last)
        let ids = URLComponents(url: details.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "id" }?.value
        #expect(details.url?.path == "/youtube/v3/videos")
        #expect(ids == "long1,good1,other,tag1,live1")
    }

    @Test func youTubeKeepsRelevanceOrderAndOnlyShortVideosOfThePlace() async throws {
        StubURLProtocol.reset()
        YouTubeFixtures.respond()

        let shorts = try await youTube().shorts(for: belemTower, in: lisbon)

        #expect(shorts.map(\.id) == ["good1", "tag1"],
                "no long tour, unrelated video, channel or live stream; search order kept")
        #expect(shorts.first?.views == 240_100)
        #expect(shorts.first?.seconds == 45)
        #expect(shorts.first?.channel == "angel")
        #expect(shorts.first?.thumbnailURL?.absoluteString == "https://i.ytimg.com/vi/good1/hqdefault.jpg")
        #expect(shorts.last?.views == nil)
    }

    @Test func noYouTubeResultsSkipTheDetailsCall() async throws {
        StubURLProtocol.reset()
        YouTubeFixtures.respond(search: #"{ "items": [] }"#)

        let shorts = try await youTube().shorts(for: belemTower, in: lisbon)

        #expect(shorts.isEmpty)
        #expect(StubURLProtocol.recorded.count == 1)
    }

    @Test func youTubeOverThePhonesAllowanceSendsNothing() async {
        StubURLProtocol.reset()
        YouTubeFixtures.respond()
        let spent = RequestBudget(name: "test", limits: .init(perMinute: 0, perDay: 0), defaults: nil)

        do {
            _ = try await youTube(budget: spent).shorts(for: belemTower, in: lisbon)
            Issue.record("an exhausted allowance should stop the search")
        } catch {
            #expect(YouTubeService.isRateLimited(error))
        }
        #expect(StubURLProtocol.recorded.isEmpty)
    }

    @Test func anOfflineYouTubeSearchIsHandedBack() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let budget = RequestBudget(name: "test", limits: .init(perMinute: 1, perDay: 1), defaults: nil)
        let service = youTube(budget: budget)

        await #expect(throws: YouTubeService.ServiceError.self) {
            _ = try await service.shorts(for: belemTower, in: lisbon)
        }
        YouTubeFixtures.respond()
        let shorts = try await service.shorts(for: belemTower, in: lisbon)
        #expect(!shorts.isEmpty, "back online, the one look-up left still goes out")
    }

    /// A place is looked up once a week, even across launches; one with no
    /// videos is asked about again the next day.
    @MainActor
    @Test func shortsAreKeptForAWeekAndNoneForADay() async throws {
        StubURLProtocol.reset()
        YouTubeFixtures.respond()
        let file = URL.temporaryDirectory.appending(path: "shorts-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: file) }
        var now = Date(timeIntervalSince1970: 1_800_000_000)
        func store() -> PlaceShorts {
            PlaceShorts(makeService: { self.youTube() }, cacheURL: file, now: { now })
        }

        await store().load(belemTower)
        #expect(StubURLProtocol.recorded.count == 2)

        let relaunched = store()
        await relaunched.load(belemTower)
        #expect(StubURLProtocol.recorded.count == 2, "a relaunch reads the week's results from disk")
        guard case .loaded(let shorts) = relaunched.state(for: belemTower) else {
            Issue.record("expected the cached videos")
            return
        }
        #expect(shorts.map(\.id) == ["good1", "tag1"])

        now += 8 * 24 * 60 * 60
        YouTubeFixtures.respond(search: #"{ "items": [] }"#)
        await store().load(belemTower)
        #expect(StubURLProtocol.recorded.count == 3, "after a week it looks again")

        now += 2 * 60 * 60
        await store().load(belemTower)
        #expect(StubURLProtocol.recorded.count == 3, "none found is remembered for the day")
        now += 24 * 60 * 60
        await store().load(belemTower)
        #expect(StubURLProtocol.recorded.count == 4)
    }

    @MainActor
    @Test func aFailedLookUpSaysSoAndCanBeTriedAgain() async {
        StubURLProtocol.reset()
        StubURLProtocol.respond(status: 403, json: "{}")
        let shorts = PlaceShorts(makeService: { self.youTube() }, cacheURL: nil)

        await shorts.load(belemTower)
        guard case .failed(let message) = shorts.state(for: belemTower) else {
            Issue.record("expected a visible failure")
            return
        }
        #expect(!message.isEmpty)

        YouTubeFixtures.respond()
        await shorts.load(belemTower)
        #expect(shorts.state(for: belemTower) != nil)
        if case .loaded = shorts.state(for: belemTower) {} else { Issue.record("Try again should load") }
    }

    @MainActor
    @Test func withoutAKeyThereAreNoVideosOnlyLinks() async {
        StubURLProtocol.reset()
        let shorts = PlaceShorts(makeService: { nil }, cacheURL: nil)

        await shorts.load(belemTower)

        #expect(!shorts.isAvailable)
        #expect(shorts.state(for: belemTower) == nil)
        #expect(StubURLProtocol.recorded.isEmpty)
    }
}
