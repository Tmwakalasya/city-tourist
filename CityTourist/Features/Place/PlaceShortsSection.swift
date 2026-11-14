import SwiftUI
import WebKit

/// Below "Where you'll be": what the place is like on video. YouTube Shorts
/// play here in YouTube's own player; TikTok and Instagram have an in-app
/// Vibe Check sheet with category-smart search angles.
struct PlaceShortsSection: View {
    let place: Place

    @Environment(PlaceShorts.self) private var shorts
    @State private var playing: Playing?
    @State private var activeVibeAngle: VibeSelection?

    private struct Playing: Identifiable {
        let shorts: [PlaceShort]
        let index: Int
        var id: Int { index }
    }

    struct VibeSelection: Identifiable {
        let angleIndex: Int
        var id: Int { angleIndex }
    }

    private var city: City { CityDirectory.city(id: place.cityID) }
    private var angles: [(label: String, suffix: String)] { PlaceShorts.vibeAngles(for: place) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What it’s like").sectionTitleStyle()
                Text("See the real crowd, ambiance, and reviews on TikTok & Shorts.")
                    .captionStyle()
            }
            tikTokVibeCard
            if shorts.isAvailable { videos }
            linksOut
        }
        .task(id: place.id) { await shorts.load(place) }
        .fullScreenCover(item: $playing) { playing in
            ShortPlayerView(place: place, shorts: playing.shorts, index: playing.index)
        }
        .sheet(item: $activeVibeAngle) { selection in
            VibeCheckSheet(place: place, initialAngleIndex: selection.angleIndex)
        }
        .accessibilityIdentifier("placeShorts")
    }

    private var tikTokVibeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        LinearGradient(colors: [Brand.rausch, Brand.rauschDeep],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vibe Check")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text("Tap an angle to preview \(place.name) in \(city.name)")
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 8) {
                ForEach(Array(angles.enumerated()), id: \.offset) { index, angle in
                    Button {
                        activeVibeAngle = VibeSelection(angleIndex: index)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Brand.rausch)
                            Text(angle.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.elevated, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(Palette.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var videos: some View {
        switch shorts.state(for: place) {
        case .loaded(let found) where found.isEmpty:
            Text("No short videos of \(place.name) on YouTube yet.").metaStyle()
        case .loaded(let found):
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(found.enumerated()), id: \.element.id) { index, short in
                        Button {
                            playing = Playing(shorts: found, index: index)
                        } label: {
                            ShortCard(short: short)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metric.gutter, for: .scrollContent)
            .padding(.horizontal, -Metric.gutter)
        case .failed(let message):
            HStack(spacing: 12) {
                Text(L10n.text(message)).metaStyle()
                Spacer(minLength: 0)
                Button("Try again") { Task { await shorts.load(place) } }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.rausch)
            }
        case .loading, nil:
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                            .fill(Palette.surface)
                            .frame(width: ShortCard.size.width, height: ShortCard.size.height)
                    }
                }
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, Metric.gutter, for: .scrollContent)
            .padding(.horizontal, -Metric.gutter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading videos")
        }
    }

    private var linksOut: some View {
        HStack(spacing: 8) {
            Text("More on").captionStyle()
            Link(destination: PlaceShorts.tikTokURL(for: place, in: city)) { linkLabel("TikTok") }
            if let instagram = PlaceShorts.instagramURL(for: place) {
                Link(destination: instagram) { linkLabel("Instagram") }
            }
        }
    }

    private func linkLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(L10n.text(title))
            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .overlay(Capsule().strokeBorder(Palette.hairline))
        .contentShape(Capsule())
    }
}

/// A Short's thumbnail, upright like the video, with who posted it and how
/// many have watched.
struct ShortCard: View {
    let short: PlaceShort

    static let size = CGSize(width: 150, height: 250)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.clear.overlay {
                AsyncImage(url: short.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Palette.surface
                }
            }
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 3) {
                Text(short.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text(short.channel)
                    .font(.system(size: 12))
                    .opacity(0.8)
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(10)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay(alignment: .top) {
            HStack {
                badge("YouTube", symbol: "play.rectangle.fill")
                Spacer(minLength: 4)
                if let views = short.views {
                    badge(views.formatted(.number.notation(.compactName)), symbol: "play.fill")
                }
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(short.title), by \(short.channel)")
        .accessibilityValue(short.views.map { "\($0.formatted()) views" } ?? "")
        .accessibilityHint("Plays the video")
    }

    private func badge(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55), in: Capsule())
    }
}

/// One Short at a time in YouTube's player, upright, with the next one a tap
/// away. Starts muted and waits for a tap to play.
struct ShortPlayerView: View {
    let place: Place
    let shorts: [PlaceShort]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var index: Int
    @State private var playback = PlaceVideoPlayback()
    @State private var attempt = UUID()

    init(place: Place, shorts: [PlaceShort], index: Int) {
        self.place = place
        self.shorts = shorts
        _index = State(initialValue: index)
    }

    private var short: PlaceShort { shorts[index] }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let height = max(200, geometry.size.height - 230)
                VStack(alignment: .leading, spacing: 16) {
                    player
                        .frame(width: min(geometry.size.width - Metric.gutter * 2, height * 9 / 16), height: height)
                        .frame(maxWidth: .infinity)
                    details
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 8)
            }
            .background(Palette.canvas)
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Brand.rausch)
                }
            }
            .task(id: attempt) {
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                playback.timedOut()
            }
        }
    }

    @ViewBuilder
    private var player: some View {
        if case .failed(let message) = playback.state {
            VStack(spacing: 14) {
                Image(systemName: "wifi.exclamationmark").font(.title)
                Text("Video unavailable").font(.headline)
                Text(L10n.text(message)).font(.subheadline).multilineTextAlignment(.center)
                Button("Try again") { show(index) }.buttonStyle(.bordered)
            }
            .foregroundStyle(Palette.inkMuted)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius))
        } else {
            YouTubePlayer(videoID: short.id, playback: playback, isActive: scenePhase == .active)
                .id(attempt)
                .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay {
                    if playback.state == .loading { ProgressView().tint(.white) }
                }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(short.title).cardTitleStyle().lineLimit(2)
            Text([short.channel, short.views.map { "\($0.formatted(.number.notation(.compactName))) views" }]
                .compactMap { $0 }.joined(separator: " · ")).metaStyle()
            HStack {
                Link("Watch on YouTube ↗", destination: short.watchURL)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.rausch)
                Spacer()
                if shorts.count > 1 {
                    Button { show(index - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(index == 0)
                        .accessibilityLabel("Previous video")
                    Text("\(index + 1) of \(shorts.count)").captionStyle()
                    Button { show(index + 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(index == shorts.count - 1)
                        .accessibilityLabel("Next video")
                }
            }
            .tint(Palette.ink)
        }
    }

    /// A fresh player for each video, so one's error or state never carries over.
    private func show(_ newIndex: Int) {
        guard shorts.indices.contains(newIndex) else { return }
        index = newIndex
        playback = PlaceVideoPlayback()
        attempt = UUID()
    }
}

/// In-app Vibe Check sheet that fetches real vertical short-form videos for
/// the exact venue + category angle (e.g. "CASA NEOS Miami crowd DJ") and plays
/// them natively without TikTok's unauthenticated webview login redirect.
struct VibeCheckSheet: View {
    let place: Place
    var initialAngleIndex: Int = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var angleIndex: Int
    @State private var clips: [PlaceShort] = []
    @State private var selectedClipIndex = 0
    @State private var isLoading = true
    @State private var playback = PlaceVideoPlayback()
    @State private var attempt = UUID()

    init(place: Place, initialAngleIndex: Int = 0) {
        self.place = place
        self.initialAngleIndex = initialAngleIndex
        _angleIndex = State(initialValue: initialAngleIndex)
    }

    private var city: City { CityDirectory.city(id: place.cityID) }
    private var angles: [(label: String, suffix: String)] { PlaceShorts.vibeAngles(for: place) }

    private var currentSuffix: String {
        guard angles.indices.contains(angleIndex) else { return "" }
        return angles[angleIndex].suffix
    }

    private var currentAngleLabel: String {
        guard angles.indices.contains(angleIndex) else { return "" }
        return angles[angleIndex].label
    }

    private var currentClip: PlaceShort? {
        guard clips.indices.contains(selectedClipIndex) else { return nil }
        return clips[selectedClipIndex]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                angleBar
                Hairline()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if currentAngleLabel == "Must-order" && place.category == .food {
                            mustOrderView
                        } else if currentAngleLabel == "Honest review" {
                            honestReviewsSection
                        } else if currentAngleLabel == "Tips" {
                            tipsView
                        } else {
                            playerSection
                            if clips.count > 1 {
                                clipStrip
                            }
                        }
                        externalAppLinks
                    }
                    .padding(.horizontal, Metric.gutter)
                    .padding(.vertical, 16)
                }
            }
            .background(Palette.canvas)
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .tint(Brand.rausch)
                }
                if let clip = currentClip,
                   !(currentAngleLabel == "Must-order" && place.category == .food),
                   currentAngleLabel != "Honest review",
                   currentAngleLabel != "Tips" {
                    ToolbarItem(placement: .topBarTrailing) {
                        Link(destination: clip.watchURL) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.body.weight(.semibold))
                        }
                        .tint(Palette.ink)
                    }
                }
            }
            .task(id: angleIndex) {
                await loadClips()
            }
        }
    }

    private var angleBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(angles.enumerated()), id: \.offset) { idx, angle in
                    let isSelected = idx == angleIndex
                    Button {
                        guard angleIndex != idx else { return }
                        angleIndex = idx
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isSelected ? Brand.rausch : Palette.inkMuted)
                            Text(angle.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? Palette.canvas : Palette.ink)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isSelected ? Palette.ink : Palette.surface, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(isSelected ? .clear : Palette.hairline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.vertical, 10)
        }
        .background(Palette.elevated)
    }

    @ViewBuilder
    private var playerSection: some View {
        if isLoading {
            RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                .fill(Palette.surface)
                .frame(height: 400)
                .overlay {
                    VStack(spacing: 10) {
                        ProgressView().tint(Brand.rausch)
                        Text("Finding \(place.name) clips…")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
        } else if let clip = currentClip {
            VStack(alignment: .leading, spacing: 12) {
                YouTubePlayer(videoID: clip.id, playback: playback, isActive: scenePhase == .active)
                    .id(attempt)
                    .frame(height: 410)
                    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                    .overlay {
                        if playback.state == .loading { ProgressView().tint(.white) }
                    }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clip.title)
                            .cardTitleStyle()
                            .lineLimit(2)
                        Text("\(clip.channel) · \(place.neighborhood)")
                            .metaStyle()
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if clips.count > 1 {
                        HStack(spacing: 6) {
                            Button { selectClip(selectedClipIndex - 1) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .background(Palette.surface, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedClipIndex == 0)

                            Text("\(selectedClipIndex + 1)/\(clips.count)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Palette.inkMuted)

                            Button { selectClip(selectedClipIndex + 1) } label: {
                                Image(systemName: "chevron.right")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 36, height: 36)
                                    .background(Palette.surface, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(selectedClipIndex == clips.count - 1)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 10) {
                Image(systemName: "video.slash")
                    .font(.title2)
                    .foregroundStyle(Palette.inkMuted)
                Text("No embedded clips found for this angle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("Open TikTok or Instagram below to see recent posts for \(place.name).")
                    .font(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        }
    }

    private var mustOrderView: some View {
        let dishes = PopularDishesService.popularItems(for: place)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Brand.rausch)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Must Order")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("Top 5 most popular items from the menu")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            .padding(.bottom, 2)

            VStack(spacing: 10) {
                ForEach(Array(dishes.prefix(5).enumerated()), id: \.element.id) { index, dish in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Brand.rausch)
                            .frame(width: 26, height: 26)
                            .background(Brand.rausch.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(dish.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(dish.note)
                                .font(.caption)
                                .foregroundStyle(Palette.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var honestReviewsSection: some View {
        let reviews = PlaceReviewsService.reviews(for: place)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "quote.bubble.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Brand.rausch)
                Text("REVIEWS FOR THIS LOCATION")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkMuted)
            }

            VStack(spacing: 10) {
                ForEach(reviews) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.author)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= item.rating ? "star.fill" : "star")
                                        .font(.caption2)
                                        .foregroundStyle(star <= item.rating ? Brand.rausch : Palette.inkFaint)
                                }
                            }
                            Text("· \(item.timeAgo)")
                                .font(.caption2)
                                .foregroundStyle(Palette.inkMuted)
                        }

                        Text(item.comment)
                            .font(.caption)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var tipsView: some View {
        let tips = PlaceTipsService.tips(for: place)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Brand.rausch)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tips & Tricks")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.ink)
                    Text("Practical advice and secrets from traveller forums")
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
            .padding(.bottom, 2)

            VStack(spacing: 10) {
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: tip.iconName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Brand.rausch)
                            .frame(width: 32, height: 32)
                            .background(Brand.rausch.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(tip.summary)
                                .font(.caption)
                                .foregroundStyle(Palette.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                }
            }
        }
    }

    private var clipStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MORE CLIPS FOR THIS VIBE")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Palette.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(clips.enumerated()), id: \.element.id) { idx, clip in
                        let isSelected = idx == selectedClipIndex
                        Button {
                            selectClip(idx)
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                AsyncImage(url: clip.thumbnailURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Palette.surface
                                }
                                .frame(width: 112, height: 164)
                                .clipped()

                                LinearGradient(colors: [.clear, .black.opacity(0.8)],
                                               startPoint: .center, endPoint: .bottom)

                                Text(clip.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                                    .padding(8)
                            }
                            .frame(width: 112, height: 164)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(isSelected ? Brand.rausch : .clear, lineWidth: 2.5)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var externalAppLinks: some View {
        HStack(spacing: 10) {
            Link(destination: PlaceShorts.tikTokURL(for: place, in: city)) {
                HStack(spacing: 6) {
                    Text("Open in TikTok")
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
            }

            if let ig = PlaceShorts.instagramURL(for: place) {
                Link(destination: ig) {
                    HStack(spacing: 6) {
                        Text("Instagram Tag")
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Palette.hairline, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func selectClip(_ newIndex: Int) {
        guard clips.indices.contains(newIndex), newIndex != selectedClipIndex else { return }
        selectedClipIndex = newIndex
        playback = PlaceVideoPlayback()
        attempt = UUID()
    }

    private func loadClips() async {
        if (currentAngleLabel == "Must-order" && place.category == .food)
            || currentAngleLabel == "Honest review"
            || currentAngleLabel == "Tips" {
            isLoading = false
            clips = []
            return
        }
        isLoading = true
        let found = await PlaceShorts.fetchLiveVibeShorts(
            for: place,
            in: city,
            angleSuffix: currentSuffix
        )
        guard !Task.isCancelled else { return }
        clips = found
        selectedClipIndex = 0
        playback = PlaceVideoPlayback()
        attempt = UUID()
        isLoading = false
    }
}
