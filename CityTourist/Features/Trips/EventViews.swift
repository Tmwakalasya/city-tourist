import SwiftUI

/// One event in the Explore or trip day's "What's on" row.
struct EventCard: View {
    let place: Place
    var showsDate: Bool = false

    private static let width: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                PlacePhoto(place: place, showsGlyph: false)
                    .frame(width: Self.width, height: 136)
                    .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))

                if let event = place.event {
                    HStack {
                        Text(event.kind.components(separatedBy: " · ").first ?? event.kind)
                            .font(.caption2.weight(.bold))
                            .tracking(0.4)
                            .textCase(.uppercase)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())

                        Spacer(minLength: 6)

                        if let price = event.price {
                            Text(price)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.62), in: Capsule())
                        }
                    }
                    .padding(10)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                if let event = place.event {
                    Text(timeText(for: event))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.rausch)
                        .lineLimit(1)
                }
                Text(place.name)
                    .cardTitleStyle()
                    .lineLimit(2)
                if let event = place.event {
                    Text(event.venue)
                        .captionStyle()
                        .lineLimit(1)
                }
            }
        }
        .frame(width: Self.width, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func timeText(for event: EventInfo) -> String {
        let time = DayForecast.clockLabel(event.startMinute)
        guard showsDate else { return time }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: event.localDate) else { return time }
        return "\(date.formatted(.dateTime.locale(L10n.locale).weekday(.abbreviated).month(.abbreviated).day())) · \(time)"
    }
}

/// An event's details, with tickets on Ticketmaster and adding it to a trip.
struct EventDetailView: View {
    let place: Place
    /// Where "Add" puts it. Nil when opened from Explore or a stop already planned.
    var tripID: Trip.ID? = nil
    var dayIndex: Int? = nil

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isAddingToTrip = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PlacePhoto(place: place)
                    .frame(height: 220)
                    .clipped()
                if let event = place.event {
                    details(event)
                        .padding(.horizontal, Metric.gutter)
                        .padding(.vertical, 20)
                }
            }
        }
        .background(Palette.canvas)
        .scrollIndicators(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }.foregroundStyle(Palette.ink)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.toggleSaved(place)
                } label: {
                    Image(systemName: store.isSaved(place) ? "heart.fill" : "heart")
                        .foregroundStyle(store.isSaved(place) ? Brand.rausch : Palette.ink)
                }
                .accessibilityLabel(store.isSaved(place) ? "Remove from saved" : "Save event")
            }
        }
        .sheet(isPresented: $isAddingToTrip) {
            AddToItinerarySheet(place: place)
        }
        .safeAreaInset(edge: .bottom) {
            if let tripID, let dayIndex, let event = place.event {
                StickyBottomBar {
                    if isPlanned(in: tripID, dayIndex: dayIndex) {
                        PrimaryButton(title: "On this day's plan", isEnabled: false) {}
                    } else {
                        PrimaryButton(title: String(localized: "Add to Day \(dayIndex + 1) at \(DayForecast.clockLabel(event.startMinute))", bundle: L10n.bundle, locale: L10n.locale)) {
                            // Booked: the planner works around it rather than moving it.
                            store.addStop(place: place, to: tripID, dayIndex: dayIndex,
                                          startMinute: event.startMinute, isBooked: true)
                            dismiss()
                        }
                    }
                }
            } else if place.event != nil {
                StickyBottomBar {
                    PrimaryButton(title: "Add to trip") {
                        isAddingToTrip = true
                    }
                }
            }
        }
    }

    private func details(_ event: EventInfo) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.kind)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Brand.rausch)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Text(place.name)
                    .font(.title2.weight(.bold))
                    .tracking(-0.4)
                    .foregroundStyle(Palette.ink)
                Text(when(event)).metaStyle()
            }

            Hairline()

            VStack(alignment: .leading, spacing: 12) {
                Label(event.venue, systemImage: "mappin.and.ellipse")
                Label("About \(duration(place.typicalMinutes))", systemImage: "clock")
                if let price = event.price {
                    Label(price, systemImage: "ticket")
                }
            }
            .font(.system(size: 15))
            .foregroundStyle(Palette.ink)

            if let url = event.ticketURL {
                Link(destination: url) {
                    Label(L10n.format("Tickets on %@", place.eventProvider), systemImage: "arrow.up.right.square")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .underline()
                }
            }

            Text(L10n.format("Event details from %@. Times are the venue’s local time.", place.eventProvider))
                .captionStyle()
        }
    }

    private func isPlanned(in tripID: Trip.ID, dayIndex: Int) -> Bool {
        guard let trip = store.trip(id: tripID), trip.days.indices.contains(dayIndex) else { return false }
        return trip.days[dayIndex].stops.contains { $0.placeID == place.id }
    }

    /// "Thursday, October 8 · 8:00 PM"
    private func when(_ event: EventInfo) -> String {
        let time = DayForecast.clockLabel(event.startMinute)
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: event.localDate) else { return time }
        return "\(date.formatted(.dateTime.locale(L10n.locale).weekday(.wide).month(.wide).day())) · \(time)"
    }

    private func duration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }
}
