import SwiftUI

/// Authentication view for Log In / Sign Up, styled and centered cleanly to match City Tourist's design system.
struct AuthenticationSheetView: View {
    @Environment(AuthenticationStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top close bar
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 36, height: 36)
                            .background(Palette.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.text("Close"))
                }
                .padding(.top, 4)

                // Centered header & icon
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(Brand.rausch)
                        .frame(width: 84, height: 84)
                        .background(Brand.rausch.opacity(0.1), in: Circle())

                    Text(L10n.text("Log in or sign up"))
                        .font(.title2.weight(.bold))
                        .tracking(-0.4)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)

                    Text(L10n.text("Sync your trips, saved places, and tailored recommendations across your devices."))
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                // Input & login options (centered form card)
                AccountAccessView()
                    .frame(maxWidth: 420)

                // Footer link
                Link(destination: ProfileView.privacyURL) {
                    Text(L10n.text("By continuing you agree to our Privacy Policy."))
                        .font(.footnote).underline()
                        .foregroundStyle(Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.bottom, 36)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.canvas)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Metric.sheetRadius)
        .onChange(of: auth.session?.user.id) { _, id in
            if id != nil { dismiss() }
        }
        .onDisappear { auth.changeNumber() }
    }
}

#Preview {
    AuthenticationSheetView()
        .environment(AuthenticationStore())
        .environment(AppStore(loadFromDisk: false))
}
