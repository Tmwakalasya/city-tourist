import Testing
@testable import CityTourist

struct PlaceRankingTests {
    private func place(_ id: String, _ category: PlaceCategory, rating: Double, reviews: Int) -> Place {
        Place(id: id, name: id, cityID: "lisbon", category: category, neighborhood: "",
              rating: rating, reviewCount: reviews, priceLevel: 1, typicalMinutes: 60,
              blurb: "", about: "", coordinate: Coordinate(latitude: 38.71, longitude: -9.14), tags: [])
    }

    /// The Lisbon case that started this: a yoga studio's 4.9 from 324
    /// reviews topped Explore, above Belém Tower.
    @Test func aLandmarkOutranksASmallStudioWithAHigherRating() {
        let tower = place("tower", .attraction, rating: 4.5, reviews: 118_929)
        let taverna = place("taverna", .food, rating: 4.8, reviews: 1_800)
        let foodHall = place("food-hall", .food, rating: 4.4, reviews: 52_310)
        let studio = place("studio", .relaxation, rating: 4.9, reviews: 324)

        #expect(PlaceRanking.ranked([studio, foodHall, taverna, tower]).map(\.id)
                == ["tower", "taverna", "food-hall", "studio"])
    }

    @Test func aGreatSmallRestaurantBeatsAFamousAverageOne() {
        let small = place("small", .food, rating: 4.8, reviews: 1_800)
        let famous = place("famous", .food, rating: 4.1, reviews: 40_000)
        #expect(PlaceRanking.score(small) > PlaceRanking.score(famous))
    }

    @Test func aHandfulOfFiveStarReviewsIsNotEnough() {
        let fluke = place("fluke", .museum, rating: 5, reviews: 3)
        let established = place("established", .museum, rating: 4.5, reviews: 2_000)
        #expect(PlaceRanking.score(established) > PlaceRanking.score(fluke))
    }

    @Test func aPlaceWithoutReviewsIsTakenAsTypical() {
        let unknown = place("unknown", .food, rating: 0, reviews: 0)
        #expect(PlaceRanking.score(unknown) == PlaceRanking.typicalRating)
    }

    @Test func popularityCountsForMoreAtALandmarkThanAtARestaurant() {
        let landmark = place("landmark", .attraction, rating: 4.4, reviews: 50_000)
        let restaurant = place("restaurant", .food, rating: 4.4, reviews: 50_000)
        #expect(PlaceRanking.score(landmark) > PlaceRanking.score(restaurant))
    }

    @Test func tiesKeepAStableOrder() {
        let places = ["c", "a", "b"].map { place($0, .museum, rating: 4.5, reviews: 500) }
        #expect(PlaceRanking.ranked(places).map(\.id) == ["a", "b", "c"])
    }
}

struct GroomingIsNotWellnessTests {
    @Test func aSalonThatCallsItselfASpaIsLeftOut() {
        #expect(!GooglePlacesService.isWellness(types: ["spa", "hair_salon", "establishment"]))
        #expect(!GooglePlacesService.isWellness(types: ["beauty_salon", "spa"]))
        #expect(!GooglePlacesService.isWellness(types: ["nail_salon", "massage_spa"]))
        #expect(GooglePlacesService.category(fromTypes: ["spa", "hair_care"], fallback: .relaxation) != .relaxation)
    }

    @Test func realSpasAndStudiosStay() {
        #expect(GooglePlacesService.isWellness(types: ["spa", "establishment"]))
        #expect(GooglePlacesService.isWellness(types: ["yoga_studio"]))
        #expect(GooglePlacesService.isWellness(types: ["sauna", "wellness_center"]))
    }
}

struct MixedRankingTests {
    private func place(_ id: String, _ category: PlaceCategory, rating: Double, reviews: Int) -> Place {
        Place(id: id, name: id, cityID: "lisbon", category: category, neighborhood: "",
              rating: rating, reviewCount: reviews, priceLevel: 1, typicalMinutes: 60,
              blurb: "", about: "", coordinate: Coordinate(latitude: 38.71, longitude: -9.14), tags: [])
    }

    /// Live Lisbon ranked plainly gave ten landmarks before Manteigaria.
    @Test func everyKindListGetsToFoodBeforeTheTenthLandmark() throws {
        let landmarks = (0..<10).map { place("landmark-\($0)", .attraction, rating: 4.7, reviews: 30_000 + $0 * 10_000) }
        let tarts = place("tarts", .food, rating: 4.8, reviews: 11_055)
        let mixed = PlaceRanking.mixed(landmarks + [tarts])

        #expect(mixed.first?.id == "landmark-9", "the best place still comes first")
        #expect(try #require(mixed.firstIndex { $0.id == "tarts" }) < 4)
        #expect(Set(mixed.map(\.id)) == Set((landmarks + [tarts]).map(\.id)), "nothing is lost or repeated")
        #expect(mixed.count == 11)
    }

    @Test func oneKindAloneKeepsItsRankedOrder() {
        let museums = [("a", 4.5, 900), ("b", 4.8, 20_000), ("c", 4.2, 300)].map { place($0.0, .museum, rating: $0.1, reviews: $0.2) }
        #expect(PlaceRanking.mixed(museums).map(\.id) == PlaceRanking.ranked(museums).map(\.id))
    }
}

struct WellnessLookalikeTests {
    @Test func hotelsAndGymsWithASpaAreLeftOut() {
        #expect(!GooglePlacesService.isWellness(types: ["spa", "lodging", "hotel"]))
        #expect(!GooglePlacesService.isWellness(types: ["gym", "spa"]))
        #expect(!GooglePlacesService.isWellness(types: ["resort_hotel", "wellness_center"]))
    }
}

/// A request returns twenty places at most. Miami's landmarks came back as
/// eight, because twelve were also parks, museums or bars and were filed there.
struct CategorySlotTests {
    @Test func aRequestLeavesOutWhatWouldBeFiledElsewhere() {
        for category in PlaceCategory.allCases {
            for type in GooglePlacesService.excludedTypes(for: category) {
                let filed = GooglePlacesService.category(fromTypes: [type], fallback: category)
                #expect(filed != category, "\(type) is left out of \(category) but would be filed there")
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
