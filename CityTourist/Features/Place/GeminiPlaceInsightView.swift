import SwiftUI

/// Displays Gemini-powered intelligence on the Place Details screen, including
/// a spoken audio tour guide, secret local tips, photo angles, and instant Q&A.
struct GeminiPlaceInsightView: View {
    let place: Place

    @State private var insight: GeminiPlaceInsight? = nil
    @State private var isLoading = true
    @State private var selectedTab: DetailTab = .tip
    @State private var isTranscriptExpanded = false
    @State private var askedQuestion: String? = nil
    @State private var answerText: String? = nil
    @State private var isAnswering = false

    private var audioPlayer: GeminiAudioPlayer { GeminiAudioPlayer.shared }
    private var city: City { CityDirectory.city(id: place.cityID) }

    enum DetailTab: String, CaseIterable, Identifiable {
        case tip = "Insider Tip"
        case photo = "Photo Spot"
        case etiquette = "Etiquette"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .tip: return "sparkles"
            case .photo: return "camera.fill"
            case .etiquette: return "cup.and.saucer.fill"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerRow

            if isLoading {
                loadingPlaceholder
            } else if let insight {
                insightContent(insight)
            }
        }
        .task(id: place.id) {
            await loadInsight()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(Brand.rausch)

            Text("Gemini Tour Guide")
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.ink)

            Spacer()

            Text("AI Audio")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Brand.rausch)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Brand.rausch.opacity(0.12), in: Capsule())
        }
    }

    // MARK: - Content

    private func insightContent(_ insight: GeminiPlaceInsight) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Audio Player Card
            audioPlayerCard(insight)

            // Transcript drawer
            if isTranscriptExpanded {
                transcriptView(insight)
            }

            // Tab Selector
            tabSelector

            // Active Tab Card
            tabContentCard(insight)

            // Instant Q&A
            qaSection(insight)
        }
    }

    // MARK: - Audio Card

    private func audioPlayerCard(_ insight: GeminiPlaceInsight) -> some View {
        let isCurrentAudio = audioPlayer.currentPlaceID == place.id && audioPlayer.isPlaying

        return VStack(alignment: .leading, spacing: 10) {
            Text(insight.headline)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 12) {
                Button {
                    let lang = languageForCity(place.cityID)
                    audioPlayer.togglePlayPause(story: insight.audioStory, placeID: place.id, languageCode: lang)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isCurrentAudio ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.bold))
                        Text(isCurrentAudio ? "Pause Audio Guide" : "Listen with Gemini")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Brand.rausch, in: Capsule())
                }
                .buttonStyle(.plain)

                if isCurrentAudio {
                    WaveformView()
                        .frame(width: 44, height: 22)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isTranscriptExpanded.toggle()
                    }
                } label: {
                    Text(isTranscriptExpanded ? "Hide story" : "Read story")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.inkMuted)
                }
                .buttonStyle(.plain)
            }

            if isCurrentAudio {
                ProgressView(value: audioPlayer.progress)
                    .tint(Brand.rausch)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                .strokeBorder(Palette.hairline)
        )
    }

    // MARK: - Transcript

    private func transcriptView(_ insight: GeminiPlaceInsight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(insight.audioStory)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(Palette.ink)
        }
        .padding(14)
        .background(Palette.canvas, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                .strokeBorder(Brand.rausch.opacity(0.3))
        )
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(DetailTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.caption2)
                        Text(tab.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(isSelected ? Palette.ink : Palette.surface, in: Capsule())
                    .foregroundStyle(isSelected ? Palette.canvas : Palette.ink)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tab Content

    private func tabContentCard(_ insight: GeminiPlaceInsight) -> some View {
        let (icon, title, bodyText) = tabData(insight)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Brand.rausch)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)

                Text(bodyText)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                .strokeBorder(Palette.hairline)
        )
    }

    private func tabData(_ insight: GeminiPlaceInsight) -> (String, String, String) {
        switch selectedTab {
        case .tip:
            return ("sparkles", "Hidden Local Detail", insight.insiderTip)
        case .photo:
            return ("camera.fill", "Prime Photography Vantage", insight.photoTip)
        case .etiquette:
            return ("cup.and.saucer.fill", "Local Etiquette & Culture", insight.localEtiquette)
        }
    }

    // MARK: - Q&A

    private func qaSection(_ insight: GeminiPlaceInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask Gemini about this place")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(insight.suggestedQuestions, id: \.self) { question in
                        Button {
                            Task { await ask(question) }
                        } label: {
                            Text(question)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Palette.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Palette.hairline))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isAnswering {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Asking Gemini...")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .padding(.vertical, 4)
            } else if let answerText, let askedQuestion {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.caption2)
                            .foregroundStyle(Brand.rausch)
                        Text(askedQuestion)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.ink)
                    }

                    Text(answerText)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .lineSpacing(3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Brand.rausch.opacity(0.08), in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .strokeBorder(Brand.rausch.opacity(0.25))
                )
            }
        }
    }

    // MARK: - Loading

    private var loadingPlaceholder: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text("Preparing Gemini Tour Guide...")
                .font(.subheadline)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func loadInsight() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let res = try await GeminiPlaceService.shared.fetchInsight(for: place, city: city)
            self.insight = res
        } catch {
            self.insight = GeminiPlaceService.synthesizedFallback(for: place, in: city)
        }
    }

    private func ask(_ question: String) async {
        isAnswering = true
        askedQuestion = question
        defer { isAnswering = false }
        do {
            let answer = try await GeminiPlaceService.shared.askQuestion(question, place: place, city: city)
            withAnimation(.spring()) {
                self.answerText = answer
            }
        } catch {
            self.answerText = "Sorry, could not get an answer right now. Please try again."
        }
    }

    private func languageForCity(_ cityID: String) -> String {
        switch cityID.lowercased() {
        case "lisbon": return "pt-PT"
        case "kyoto": return "ja-JP"
        case "mexico-city": return "es-MX"
        default: return "en-US"
        }
    }
}

// MARK: - Animated Audio Waveform

private struct WaveformView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Brand.rausch)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let heights: [[CGFloat]] = [
            [6, 14, 20, 10],
            [16, 8, 12, 18],
            [10, 18, 6, 14],
            [18, 12, 16, 8]
        ]
        let current = heights[index % heights.count]
        return current[0] + (current[1] - current[0]) * phase
    }
}
