import Foundation
import AVFoundation
import Observation

/// Audio playback engine for Gemini tour guide narratives using `AVSpeechSynthesizer`.
/// Features interactive speech synthesis with progress tracking, pause/resume, and
/// locale-aware voice selection.
@MainActor
@Observable
final class GeminiAudioPlayer: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = GeminiAudioPlayer()

    private(set) var isPlaying: Bool = false
    private(set) var currentPlaceID: String? = nil
    private(set) var progress: Double = 0.0

    private let synthesizer = AVSpeechSynthesizer()
    private var totalCharacters: Int = 0
    private var spokeCharacters: Int = 0

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func togglePlayPause(story: String, placeID: String, languageCode: String = "en-US") {
        if isPlaying && currentPlaceID == placeID {
            pause()
        } else if synthesizer.isPaused && currentPlaceID == placeID {
            resume()
        } else {
            play(story: story, placeID: placeID, languageCode: languageCode)
        }
    }

    func play(story: String, placeID: String, languageCode: String = "en-US") {
        stop()

        currentPlaceID = placeID
        totalCharacters = max(1, story.count)
        spokeCharacters = 0
        progress = 0.0

        let utterance = AVSpeechUtterance(string: story)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94 // Natural, relaxed tour guide pace
        utterance.pitchMultiplier = 1.0

        // Select best available voice for language or fallback to en-US
        if let voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
        isPlaying = true
    }

    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            isPlaying = false
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            isPlaying = true
        }
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
        currentPlaceID = nil
        progress = 0.0
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        willSpeakRangeOfSpeechString characterRange: NSRange,
        utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.spokeCharacters = characterRange.location + characterRange.length
            self.progress = min(1.0, Double(self.spokeCharacters) / Double(self.totalCharacters))
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1.0
            self.currentPlaceID = nil
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0.0
            self.currentPlaceID = nil
        }
    }
}
