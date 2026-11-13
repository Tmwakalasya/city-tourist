import Testing
@testable import CityTourist

/// A request returns twenty places at most. Miami's landmarks came back as
/// eight, because twelve were also parks, museums or bars and were filed there.
struct CategorySlotTests {
    @Test func aRequestLeavesOutWhatWouldBeFiledElsewhere() {
        for category in PlaceCategory.allCases {
            for type in GooglePlacesService.excludedTypes(for: category) {
                let filed = GooglePlacesService.category(fromTypes: [type], fallback: category)
                // Everyday shops and places to stay are left out everywhere they're named.
                let unwanted = GooglePlacesService.isEveryday(types: [type])
                    || GooglePlacesService.wellnessLookalikes.contains(type)
                #expect(filed != category || unwanted,
                        "\(type) is left out of \(category) but would be filed there")
            }
        }
        #expect(GooglePlacesService.excludedTypes(for: .attraction).contains("park"))
        #expect(GooglePlacesService.excludedTypes(for: .attraction).contains("museum"))
        #expect(GooglePlacesService.excludedTypes(for: .relaxation).contains("hotel"))
    }

    @Test func aZooOrMarketIsSomethingToDoEvenAsATouristAttraction() {
        #expect(GooglePlacesService.category(fromTypes: ["zoo", "tourist_attraction", "park"], fallback: .attraction) == .activity)
        #expect(GooglePlacesService.category(fromTypes: ["market", "tourist_attraction"], fallback: .attraction) == .activity)
        #expect(GooglePlacesService.category(fromTypes: ["tourist_attraction", "park"], fallback: .attraction) == .nature)
        #expect(GooglePlacesService.category(fromTypes: ["tourist_attraction", "historical_landmark"], fallback: .nature) == .attraction)
    }
}

struct WellnessLookalikeTests {
    @Test func salonsGymsAndHotelsThatListASpaAreLeftOut() {
        #expect(!GooglePlacesService.isWellness(types: ["spa", "hair_salon", "establishment"]))
        #expect(!GooglePlacesService.isWellness(types: ["nail_salon", "massage_spa"]))
        #expect(!GooglePlacesService.isWellness(types: ["spa", "lodging", "hotel"]))
        #expect(!GooglePlacesService.isWellness(types: ["gym", "spa"]))
        #expect(GooglePlacesService.category(fromTypes: ["spa", "hair_care"], fallback: .relaxation) != .relaxation)
    }

    @Test func realSpasAndStudiosStay() {
        #expect(GooglePlacesService.isWellness(types: ["spa", "establishment"]))
        #expect(GooglePlacesService.isWellness(types: ["yoga_studio"]))
        #expect(GooglePlacesService.isWellness(types: ["sauna", "wellness_center"]))
    }
}

/// From the simulator: NAPA Auto Parts under Things to do and Dollar General
/// under Food in Palm Bay, and Casa Tua under Museums in Miami.
struct VisitorPlacesTests {
    @Test func whatAPlaceMainlyIsDecidesItsCategory() {
        // A restaurant that hangs art and has a bar.
        #expect(GooglePlacesService.category(primaryType: "italian_restaurant",
                                             fromTypes: ["italian_restaurant", "art_gallery", "bar", "restaurant"],
                                             fallback: .museum) == .food)
        #expect(GooglePlacesService.category(primaryType: "restaurant", fromTypes: ["restaurant", "wine_bar"], fallback: .nightlife) == .food)
        #expect(GooglePlacesService.category(primaryType: "bar_and_grill", fromTypes: ["bar_and_grill", "bar", "restaurant"], fallback: .food) == .nightlife)
        #expect(GooglePlacesService.category(primaryType: "video_arcade", fromTypes: ["video_arcade", "bar", "restaurant"], fallback: .nightlife) == .activity)
        #expect(GooglePlacesService.category(primaryType: "museum", fromTypes: ["museum", "cafe"], fallback: .food) == .museum)
    }

    @Test func anUnknownMainTypeFallsBackToTheOthers() {
        #expect(GooglePlacesService.category(primaryType: "fishing_pier", fromTypes: ["fishing_pier", "tourist_attraction"], fallback: .nature) == .attraction)
        #expect(GooglePlacesService.category(primaryType: nil, fromTypes: ["restaurant", "bar"], fallback: .food) == .nightlife)
    }

    @Test func everydayShopsAreLeftOutOfDiscovery() {
        #expect(GooglePlacesService.isEveryday(types: ["auto_parts_store", "market", "car_repair"]))
        #expect(GooglePlacesService.isEveryday(types: ["drugstore", "gift_shop", "discount_store", "food"]))
        #expect(GooglePlacesService.isEveryday(types: ["grocery_store", "supermarket", "market"]))
        #expect(GooglePlacesService.isEveryday(types: ["supermarket", "bakery", "florist"]))
        #expect(!GooglePlacesService.isEveryday(types: ["market", "tourist_attraction"]))
        #expect(!GooglePlacesService.isEveryday(types: ["shopping_mall"]))
        #expect(!GooglePlacesService.isEveryday(types: ["seafood_restaurant", "restaurant", "bar"]))
    }

    @Test func noRequestLeavesOutMoreTypesThanGoogleAllows() {
        for category in PlaceCategory.allCases {
            #expect(GooglePlacesService.excludedTypes(for: category).count <= 50)
        }
    }
}

extension PlacesAPITests {
    /// Asked for anything with a bar, half of Miami's twenty were restaurants.
    @Test func nightlifeAsksForPlacesThatAreMainlyBars() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.respond(json: Fixtures.nearbyLisbon)
        let service = GooglePlacesService(apiKey: "test", session: StubURLProtocol.makeSession())
        _ = try await service.nearby(city: SampleData.cities[0], category: .nightlife)

        let body = try #require(StubURLProtocol.recorded.first?.stubBody)
        #expect(body["includedTypes"] == nil)
        let primary = try #require(body["includedPrimaryTypes"] as? [String])
        #expect(primary.contains("bar") && primary.contains("night_club"))
        #expect((body["excludedTypes"] as? [String])?.contains("hotel") == true)
    }
}
