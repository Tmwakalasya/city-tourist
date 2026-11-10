import SwiftUI

/// First launch, before there's a trip: what the app does in a few lines and
/// the way straight into planning one. Shown once; anyone who'd sooner look
/// around is one tap from Explore.
struct WelcomeView: View {
    /// Called with the trip once one has been made.
    let onPlanned: (Trip) -> Void
    let onSkip: () -> Void

    @State private var isPlanning = false

    private static let promises: [(symbol: String, text: String)] = [
        ("sparkles", "A plan for every day, in your own words"),
        ("checkmark.seal", "Checked, so nothing is closed when you arrive"),
        ("figure.walk", "Leave-by times and directions on the day")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            Text("CITY TOURIST")
                .font(.caption.weight(.bold))
                .tracking(1.3)
                .foregroundStyle(Brand.rausch)
            Text("Where are you going?")
                .displayStyle()
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
            Text("Name the city and your dates. We’ll plan each day around what you like, then check it against opening hours and travel times.")
                .metaStyle()
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Self.promises, id: \.text) { promise in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: promise.symbol)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Brand.rausch)
                            .frame(width: 26)
                        Text(L10n.text(promise.text))
                            .font(.body)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 32)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                PrimaryButton(title: "Plan my trip") { isPlanning = true }
                    .accessibilityIdentifier("welcomePlanButton")
                Button(L10n.text("Look around first"), action: onSkip)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("welcomeSkipButton")
                Text("No account needed. Your trips stay on your iPhone.")
                    .captionStyle()
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.canvas.ignoresSafeArea())
        .sheet(isPresented: $isPlanning) {
            NewTripView(onCreate: onPlanned)
        }
    }
}

#Preview {
    WelcomeView(onPlanned: { _ in }, onSkip: {})
        .environment(AppStore(loadFromDisk: false))
        .environment(PlaceCatalog())
}
