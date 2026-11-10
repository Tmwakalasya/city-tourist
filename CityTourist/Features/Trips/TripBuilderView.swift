import SwiftUI

/// "Plan my whole trip": the traveller says what they want in their own
/// words, the model drafts the days, and the app checks every stop against
/// opening hours and travel time before showing it. Nothing is saved until
/// they accept.
struct TripBuilderView: View {
    let city: City
    let startDate: Date
    let endDate: Date
    /// One list of stops for each day of the trip, in order.
    let onAccept: ([[ItineraryStop]]) -> Void

    @Environment(PlaceCatalog.self) private var catalog
    @State private var model: TripBuilding
    @State private var request = ""
    @State private var wishes: Set<String> = []
    @State private var buildID: UUID?
    @FocusState private var isEditing: Bool

    /// Previews and tests pass a build that has already run.
    init(city: City, startDate: Date, endDate: Date, model: TripBuilding? = nil,
         onAccept: @escaping ([[ItineraryStop]]) -> Void) {
        self.city = city
        self.startDate = startDate
        self.endDate = endDate
        self.onAccept = onAccept
        _model = State(initialValue: model ?? TripBuilding())
    }

    private struct Wish: Identifiable {
        let title: String
        let phrase: String
        let symbol: String
        /// A wish this one can't sit beside.
        var opposite: String? = nil
        var id: String { title }
    }

    private static let wishList = [
        Wish(title: "Slow mornings", phrase: "slow mornings", symbol: "sunrise"),
        Wish(title: "Food first", phrase: "plenty of good food", symbol: "fork.knife"),
        Wish(title: "Museums & culture", phrase: "museums and culture", symbol: "building.columns"),
        Wish(title: "Outdoors & views", phrase: "time outdoors and good views", symbol: "leaf"),
        Wish(title: "Nights out", phrase: "a proper night out", symbol: "wineglass"),
        Wish(title: "Easy pace", phrase: "an easy pace with room to wander", symbol: "tortoise", opposite: "Packed days"),
        Wish(title: "Packed days", phrase: "full, busy days", symbol: "hare", opposite: "Easy pace")
    ]

    static let defaultRequest = "The highlights of a first visit, with good food and an easy pace."

    private var dates: [Date] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: startDate)
        let count = max(0, calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: endDate)).day ?? 0) + 1
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    private var builder: TripBuilder { TripBuilder(city: city, dates: dates) }

    /// What's typed, then what's ticked, as one request.
    private var fullRequest: String {
        Self.request(typed: request, phrases: Self.wishList.filter { wishes.contains($0.title) }.map(\.phrase))
    }

    static func request(typed: String, phrases: [String]) -> String {
        let typed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts = typed.isEmpty ? [] : [typed]
        if !phrases.isEmpty { parts.append("I’d like " + phrases.joined(separator: ", ") + ".") }
        return parts.isEmpty ? defaultRequest : String(parts.joined(separator: " ").prefix(500))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction
                switch model.phase {
                case .idle:
                    composer
                case .failed(let message):
                    composer
                    Label(L10n.text(message), systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(Brand.rausch)
                        .accessibilityIdentifier("tripBuilderMessage")
                case .finding, .drafting, .checking:
                    progress
                case .ready:
                    if let result = model.result { plan(result) }
                }
            }
            .padding(Metric.gutter)
            .padding(.bottom, 24)
        }
        .background(Palette.canvas)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Plan my whole trip")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { StickyBottomBar { actions } }
        .task(id: buildID) {
            guard buildID != nil else { return }
            await build()
        }
    }

    // MARK: Asking

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("TRIP BUILDER").tracking(1.3)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Brand.rausch)

            Text(verbatim: L10n.format(dates.count == 1 ? "%d day in %@" : "%d days in %@", dates.count, city.name))
                .displayStyle()
                .fixedSize(horizontal: false, vertical: true)
            Text(dateRange).metaStyle()
        }
    }

    private var dateRange: String {
        let style = Date.FormatStyle.dateTime.locale(L10n.locale).weekday(.abbreviated).month(.abbreviated).day()
        return dates.count == 1 ? startDate.formatted(style) : "\(startDate.formatted(style)) – \(endDate.formatted(style))"
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Say what you want from the trip. We’ll draft each day, then check it against opening hours and travel times.")
                .metaStyle()
                .fixedSize(horizontal: false, vertical: true)

            TextField("Good food, a couple of museums, one big night out…", text: $request, axis: .vertical)
                .lineLimit(3...6)
                .font(.body)
                .focused($isEditing)
                .padding(16)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                }
                .accessibilityIdentifier("tripRequestInput")

            FlowLayout(spacing: 8) {
                ForEach(Self.wishList) { wish in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { toggle(wish) }
                    } label: {
                        Chip(title: wish.title, systemImage: wish.symbol, isSelected: wishes.contains(wish.title))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(wishes.contains(wish.title) ? .isSelected : [])
                }
            }
            if dates.count > TripDraftService.maxDays {
                Text("The first \(TripDraftService.maxDays) days get planned. The rest stay open for you to fill.")
                    .captionStyle()
            }
        }
    }

    private func toggle(_ wish: Wish) {
        if wishes.contains(wish.title) {
            wishes.remove(wish.title)
        } else {
            wishes.insert(wish.title)
            if let opposite = wish.opposite { wishes.remove(opposite) }
        }
    }

    // MARK: Building

    private var progress: some View {
        VStack(alignment: .leading, spacing: 16) {
            step(L10n.format("Finding places in %@", city.name), for: .finding)
            step(L10n.text("Drafting your days"), for: .drafting)
            step(L10n.text("Checking opening hours and travel times"), for: .checking)
            Text("Keep this screen open while it builds.").captionStyle()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func step(_ title: String, for phase: TripBuilding.Phase) -> some View {
        let order: [TripBuilding.Phase] = [.finding, .drafting, .checking]
        let current = order.firstIndex(of: model.phase) ?? order.count
        let index = order.firstIndex(of: phase) ?? 0
        return HStack(spacing: 12) {
            Group {
                if index < current {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.babu)
                } else if index == current {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "circle").foregroundStyle(Palette.inkFaint)
                }
            }
            .frame(width: 22)
            Text(verbatim: title)
                .font(.subheadline.weight(index == current ? .semibold : .regular))
                .foregroundStyle(index > current ? Palette.inkMuted : Palette.ink)
        }
    }

    private func build() async {
        let text = fullRequest
        let dates = dates
        let service = TripDraftService()
        let draft: (([Place]) async throws -> TripDraftService.Draft)? = service.map { service in
            { places in
                try await service.draft(request: text, city: city, dates: dates, candidates: places,
                                        language: L10n.languageName)
            }
        }
        await model.run(builder: builder, find: {
            await catalog.load(city: city)
            var batches: [[Place]] = []
            // Extra searches only help a draft that reads the request.
            if service != nil, catalog.isLiveDataAvailable {
                for term in TripDraftService.searchTerms(for: text) {
                    if let page = try? await catalog.searchPlaces(query: term, city: city) {
                        batches.append(page.places)
                    }
                }
            }
            return TripDraftService.candidates(
                searched: AIRecommendationService.interleave(batches).filter { $0.cityID == city.id },
                catalog: catalog.places(in: city.id).filter { $0.cityID == city.id })
        }, draft: draft)
    }

    // MARK: The plan

    @ViewBuilder
    private func plan(_ result: TripBuilder.Result) -> some View {
        if model.followsRequest {
            if !model.summary.isEmpty {
                Text(model.summary).bodyStyle().fixedSize(horizontal: false, vertical: true)
            }
            checked(result)
        } else {
            Text("A starter plan from the best-rated places that fit each day’s opening hours. It doesn’t follow your request.")
                .metaStyle()
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(Array(result.days.enumerated()), id: \.element.id) { index, day in
            dayBlock(day, number: index + 1)
        }
    }

    /// What the check found, so the plan isn't taken on faith.
    private func checked(_ result: TripBuilder.Result) -> some View {
        let notes = Self.notes(for: result, dates: dates)
        return VStack(alignment: .leading, spacing: 10) {
            Label("Checked against opening hours and travel times", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.babu)
            if notes.isEmpty {
                Text("Every stop is open when you arrive, with time to get between them.").captionStyle()
            } else {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.caption2.weight(.semibold))
                        Text(note).font(.footnote).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Palette.ink)
                }
            }
            Text("Regular hours only. Holidays and bookings aren’t checked.").captionStyle()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
        .accessibilityIdentifier("tripBuilderChecked")
    }

    /// One line for each thing checking changed.
    static func notes(for result: TripBuilder.Result, dates: [Date]) -> [String] {
        func weekday(_ index: Int) -> String {
            dates.indices.contains(index)
                ? dates[index].formatted(.dateTime.locale(L10n.locale).weekday(.wide)) : ""
        }
        var notes = result.fixes.map { fix -> String in
            switch fix {
            case let .moved(place, from, to, closedThatDay):
                closedThatDay
                    ? L10n.format("Moved %@ to %@. It’s closed on %@s.", place.name, weekday(to), weekday(from))
                    : L10n.format("Moved %@ to %@, where its hours fit.", place.name, weekday(to))
            case let .reordered(day):
                L10n.format("Reordered %@ so every place is open when you get there.", weekday(day))
            case let .dropped(place, from, closedThatDay):
                closedThatDay
                    ? L10n.format("Left out %@. It’s closed on %@s and didn’t fit any other day.", place.name, weekday(from))
                    : L10n.format("Left out %@. Its hours didn’t fit any day.", place.name)
            }
        }
        if result.retimed == 1 {
            notes.append(L10n.text("Moved 1 start time to allow for travel or an opening time."))
        } else if result.retimed > 1 {
            notes.append(L10n.format("Moved %d start times to allow for travel or opening times.", result.retimed))
        }
        return notes
    }

    private func dayBlock(_ day: TripBuilder.Day, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DAY \(number) · \(day.date.formatted(.dateTime.locale(L10n.locale).weekday(.wide).month(.abbreviated).day()).uppercased())")
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.inkMuted)
                if !day.theme.isEmpty { Text(day.theme).sectionTitleStyle() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            if day.stops.isEmpty {
                Text("Nothing planned. A day to fill as you go.").metaStyle()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(day.stops.enumerated()), id: \.element.id) { index, stop in
                        stopRow(stop)
                        if index < day.stops.count - 1 {
                            hop(from: stop, to: day.stops[index + 1])
                        }
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func stopRow(_ stop: TripBuilder.Stop) -> some View {
        HStack(alignment: .top, spacing: 12) {
            PlacePhoto(place: stop.place, showsGlyph: false)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stop.place.name).cardTitleStyle().lineLimit(2)
                    Spacer(minLength: 6)
                    Text(DayForecast.clockLabel(stop.start))
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Brand.rausch)
                }
                Text("\(stop.place.durationLabel) · \(stop.place.category.title)").captionStyle()
                if !stop.reason.isEmpty {
                    Text(stop.reason)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Button {
                withAnimation(.snappy(duration: 0.2)) { model.remove(stop) }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(stop.place.name)")
        }
        .padding(.vertical, 10)
    }

    /// The gap to the next stop, with the estimate it was checked against.
    private func hop(from stop: TripBuilder.Stop, to next: TripBuilder.Stop) -> some View {
        let minutes = TravelEstimate.minutes(from: stop.place.coordinate, to: next.place.coordinate)
        return HStack(spacing: 8) {
            Rectangle().fill(Palette.hairline).frame(width: 1.5, height: 16).padding(.leading, 27)
            Image(systemName: minutes <= RouteService.walkingCeilingMinutes ? "figure.walk" : "tram.fill")
                .font(.caption2.weight(.semibold))
                .padding(.leading, 20)
            Text("About \(minutes) min").font(.caption)
        }
        .foregroundStyle(Palette.inkMuted)
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        switch model.phase {
        case .idle:
            PrimaryButton(title: "Build my trip") { start() }
                .accessibilityIdentifier("buildTripButton")
        case .failed:
            VStack(spacing: 12) {
                PrimaryButton(title: "Try again") { start() }
                if !model.candidates.isEmpty {
                    Button(L10n.text("Build a starter plan without AI")) { model.useStarter(builder: builder) }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
        case .finding, .drafting, .checking:
            PrimaryButton(title: "Building your trip…", isEnabled: false) {}
        case .ready:
            VStack(spacing: 12) {
                PrimaryButton(title: "Use this trip", isEnabled: (model.result?.stopCount ?? 0) > 0) {
                    if let result = model.result {
                        onAccept(result.days.map { $0.stops.map(\.itineraryStop) })
                    }
                }
                .accessibilityIdentifier("useTripButton")
                Button(L10n.text("Change what I asked for")) { model.reset() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            }
        }
    }

    private func start() {
        isEditing = false
        buildID = UUID()
    }
}

#Preview {
    NavigationStack {
        TripBuilderView(city: SampleData.cities[0], startDate: .now,
                        endDate: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now) { _ in }
    }
    .environment(PlaceCatalog())
}
