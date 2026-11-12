import Testing
@testable import CityTourist

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
