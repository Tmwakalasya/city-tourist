import Foundation

/// Rich, localized visitor intelligence generated for a place by the Gemini API.
/// Includes an immersive audio guide narrative, hidden insider tips, photo vantage
/// points, and cultural etiquette.
struct GeminiPlaceInsight: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var headline: String
    var audioStory: String
    var insiderTip: String
    var photoTip: String
    var localEtiquette: String
    var suggestedQuestions: [String]

    init(
        id: String,
        headline: String,
        audioStory: String,
        insiderTip: String,
        photoTip: String,
        localEtiquette: String,
        suggestedQuestions: [String] = []
    ) {
        self.id = id
        self.headline = headline
        self.audioStory = audioStory
        self.insiderTip = insiderTip
        self.photoTip = photoTip
        self.localEtiquette = localEtiquette
        self.suggestedQuestions = suggestedQuestions
    }
}
