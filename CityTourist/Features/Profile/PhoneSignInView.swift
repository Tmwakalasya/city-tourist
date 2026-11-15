import SwiftUI

struct PhoneSignInView: View {
    @Environment(AuthenticationStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.lastDialCode) private var lastDialCode = PhoneCountry.supported[0].dialCode
    @State private var country: PhoneCountry
    @State private var number = ""
    @State private var code = ""
    @FocusState private var focusedField: Field?

    private enum Field { case phone, code }

    init() {
        let saved = UserDefaults.standard.string(forKey: AppSettings.lastDialCode)
        let initialCountry = PhoneCountry.supported.first(where: { $0.dialCode == saved }) ?? PhoneCountry.supported[0]
        _country = State(initialValue: initialCountry)
    }

    var body: some View {
        NavigationStack {
            Form {
                if auth.pendingPhone == nil {
                    Section {
                        Picker("Country code", selection: $country) {
                            ForEach(PhoneCountry.supported) { country in
                                Text("\(country.name) (+\(country.dialCode))").tag(country)
                            }
                        }
                        .onChange(of: country) { _, newCountry in
                            lastDialCode = newCountry.dialCode
                            number = newCountry.masked(number)
                        }

                        TextField("Phone number", text: $number)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .focused($focusedField, equals: .phone)
                            .onChange(of: number) { _, value in
                                let masked = country.masked(value)
                                if number != masked { number = masked }
                            }

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = auth.remaining(at: context.date)
                            Button(seconds > 0 ? L10n.format("Resend in %d s", seconds) : L10n.text("Send code")) {
                                guard let phone = country.e164(number) else { return }
                                Task { await auth.request(phone: phone) }
                            }
                            .disabled(country.e164(number) == nil || auth.busy || seconds > 0)
                        }
                    } footer: {
                        Text("Use your national number without a leading zero. Standard SMS rates may apply.")
                    }
                } else {
                    Section {
                        Text(auth.pendingPhone ?? "").font(.headline)
                        TextField("Verification code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .code)
                            .onChange(of: code) { _, value in
                                let sanitized = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                                if code != sanitized { code = sanitized }
                                if sanitized.count == 6 && !auth.busy {
                                    Task { await auth.verify(code: sanitized) }
                                }
                            }

                        Button("Verify and sign in") { Task { await auth.verify(code: code) } }
                            .disabled(code.count != 6 || auth.busy)

                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let seconds = auth.remaining(at: context.date)
                            Button(seconds > 0 ? L10n.format("Resend in %d s", seconds) : L10n.text("Resend code")) {
                                guard let phone = auth.pendingPhone else { return }
                                code = ""
                                Task { await auth.request(phone: phone) }
                            }
                            .disabled(seconds > 0 || auth.busy)
                        }

                        Button("Change phone number") { auth.changeNumber(); code = "" }
                            .disabled(auth.busy)
                    }
                }
                if auth.busy { ProgressView() }
                if let message = auth.errorMessage {
                    Text(L10n.text(message))
                        .foregroundStyle(Brand.rausch)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .navigationTitle("Phone sign-in")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .onAppear {
                focusedField = auth.pendingPhone == nil ? .phone : .code
            }
            .onChange(of: auth.pendingPhone) { _, pending in
                focusedField = pending == nil ? .phone : .code
            }
            .onChange(of: auth.session?.user.id) { _, id in
                if id != nil { dismiss() }
            }
        }
    }
}

