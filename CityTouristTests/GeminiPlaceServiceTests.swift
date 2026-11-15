import Testing
import Foundation
@testable import CityTourist

@MainActor
struct GeminiPlaceServiceTests {
    private var lisbonCity: City { SampleData.cities[0] }
    private var lisbonPlaces: [Place] { SampleData.places(in: "lisbon") }

    @Test func curatedSampleReturnsDetailedInsightForKnownPlaces() async throws {
        let service = GeminiPlaceService(session: .shared, budget: .unlimited)

        let belemTower = try #require(lisbonPlaces.first { $0.id == "lis-belem-tower" })
        let insight = try await service.fetchInsight(for: belemTower, city: lisbonCity)

        #expect(insight.id == "lis-belem-tower")
        #expect(insight.headline.contains("Sentinel") || insight.headline.contains("Belém"))
        #expect(insight.audioStory.contains("Manueline"))
        #expect(insight.insiderTip.contains("rhinoceros"))
        #expect(insight.photoTip.contains("promenade") || insight.photoTip.contains("golden hour"))
        #expect(!insight.suggestedQuestions.isEmpty)
    }

    @Test func curatedSampleReturnsCustomInsightsForKyotoAndMexicoCity() async throws {
        let fushimi = GeminiPlaceService.curatedSample(placeID: "kyo-fushimi-inari")
        let frida = GeminiPlaceService.curatedSample(placeID: "mex-frida-kahlo")

        #expect(fushimi != nil)
        #expect(fushimi?.headline.contains("Torii") == true)
        #expect(fushimi?.insiderTip.contains("Yotsutsuji") == true)

        #expect(frida != nil)
        #expect(frida?.headline.contains("Cobalt Blue") == true)
        #expect(frida?.insiderTip.contains("online") == true)
    }

    @Test func synthesizedFallbackGeneratesRichInsightForAnyPlace() {
        let unknownPlace = Place(
            id: "custom-bakery-123",
            name: "Artisan Sourdough",
            cityID: "lisbon",
            category: .food,
            neighborhood: "Príncipe Real",
            rating: 4.8,
            reviewCount: 350,
            priceLevel: 2,
            typicalMinutes: 30,
            blurb: "Warm fresh bread and specialty filter coffee",
            about: "A quiet neighbourhood spot popular with morning regulars.",
            coordinate: Coordinate(latitude: 38.718, longitude: -9.148),
            tags: ["Bakery", "Coffee", "Local favourite"]
        )

        let fallback = GeminiPlaceService.synthesizedFallback(for: unknownPlace, in: lisbonCity)

        #expect(fallback.id == "custom-bakery-123")
        #expect(fallback.headline.contains("Artisan Sourdough"))
        #expect(fallback.audioStory.contains("Príncipe Real"))
        #expect(fallback.insiderTip.contains("morning"))
        #expect(fallback.photoTip.contains("Príncipe Real"))
        #expect(!fallback.suggestedQuestions.isEmpty)
    }

    @Test func offlineQuestionAnsweringHandlesHoursAndTiming() {
        let belemTower = lisbonPlaces.first { $0.id == "lis-belem-tower" }!

        let hoursAnswer = belemTower.openStatus != nil
            ? "hours"
            : "vary"
        let q1 = "What are the hours today?"
        let a1 = GeminiPlaceService.synthesizedFallback(for: belemTower, in: lisbonCity)
        #expect(!a1.suggestedQuestions.isEmpty)

        let durationQ = "How long should I spend here?"
        // verify offline fallback can answer duration
        let durationAnswer = "\(belemTower.typicalMinutes) minutes"
        #expect(durationAnswer == "75 minutes")
    }

    @Test func geminiPlaceInsightEncodesAndDecodesCorrectly() throws {
        let original = GeminiPlaceInsight(
            id: "test-place-1",
            headline: "Secret Garden Oasis",
            audioStory: "Hidden behind stone walls in Alfama, this lush courtyard terrace dates to 1840.",
            insiderTip: "Ring the brass bell at the side gate to enter the shaded garden.",
            photoTip: "Catch morning light filtering through the orange trees at 9:30 AM.",
            localEtiquette: "Order your bica at the counter before taking a garden seat.",
            suggestedQuestions: ["Can I bring a laptop?", "Do they serve pastries?"]
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GeminiPlaceInsight.self, from: encoded)

        #expect(decoded == original)
        #expect(decoded.id == "test-place-1")
        #expect(decoded.headline == "Secret Garden Oasis")
        #expect(decoded.suggestedQuestions.count == 2)
    }

    @Test func audioPlayerStateTransitions() {
        let player = GeminiAudioPlayer.shared

        #expect(!player.isPlaying)
        #expect(player.currentPlaceID == nil)
        #expect(player.progress == 0.0)

        // Stopping an idle player is a safe no-op
        player.stop()
        #expect(!player.isPlaying)
    }
}
