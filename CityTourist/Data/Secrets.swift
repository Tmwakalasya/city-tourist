import Foundation

/// Where the API keys come from.
///
/// Order: `Secrets.plist` in the app bundle, then an environment variable on
/// the scheme. Keys never go in source control — `Secrets.plist` is gitignored
/// and `Secrets.example.plist` shows the shape.
enum Secrets {
    static let supabaseURL = key("SupabaseURL", orEnvironment: "SUPABASE_URL")
    static let supabasePublishableKey = key("SupabasePublishableKey", orEnvironment: "SUPABASE_PUBLISHABLE_KEY")
    static let eventbriteProxyURL = key("EventbriteProxyURL", orEnvironment: "EVENTBRITE_PROXY_URL")

    static let googlePlacesAPIKey: String? = key("GooglePlacesAPIKey", orEnvironment: "GOOGLE_PLACES_API_KEY")

    static var hasGooglePlacesKey: Bool { googlePlacesAPIKey != nil }

    /// Optional: short videos on place pages. Without its own entry this is
    /// the Google Places key, which works once YouTube Data API v3 is enabled
    /// for it in the same Google Cloud project.
    static let youtubeAPIKey: String? = key("YouTubeAPIKey", orEnvironment: "YOUTUBE_API_KEY") ?? googlePlacesAPIKey

    /// Optional: without it the trip screen just doesn't show what's on.
    static let ticketmasterAPIKey: String? = key("TicketmasterAPIKey", orEnvironment: "TICKETMASTER_API_KEY")

    /// Optional: where Settings' "Send feedback" writes to. Without it the
    /// row isn't shown. Kept out of source like the keys.
    static let feedbackEmail: String? = key("FeedbackEmail", orEnvironment: "FEEDBACK_EMAIL")

    /// Optional: Claude API key for the AI Concierge feature in beta.
    static let anthropicAPIKey: String? = {
        if let direct = key("AnthropicAPIKey", orEnvironment: "ANTHROPIC_API_KEY")
            ?? key("ANTHROPIC_API_KEY", orEnvironment: "ANTHROPIC_API_KEY")
            ?? key("ClaudeAPIKey", orEnvironment: "CLAUDE_API_KEY") {
            return direct
        }
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        // 1. Match any value or key in Secrets.plist starting with "sk-ant-"
        // (covers accidental paste into Xcode's "New item" Key column as well).
        for (dictKey, dictValue) in plist {
            if let strVal = dictValue as? String {
                let trimmedVal = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedVal.hasPrefix("sk-ant-") { return trimmedVal }
            }
            let trimmedKey = dictKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedKey.hasPrefix("sk-ant-") { return trimmedKey }
        }
        // 2. Match any non-standard row added to Secrets.plist (e.g., "New item", "AnthropicKey", "Claude").
        let standardKeys: Set<String> = [
            "supabaseurl", "supabasepublishablekey", "eventbriteproxyurl", "googleplacesapikey", "ticketmasterapikey", "youtubeapikey", "feedbackemail", "sharebaseurl"
        ]
        for (dictKey, dictValue) in plist where !standardKeys.contains(dictKey.localizedLowercase) {
            if let strVal = dictValue as? String, isUsable(strVal) {
                return strVal.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if isUsable(dictKey), dictKey.localizedLowercase != "new item" {
                return dictKey.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }()

    static var hasAnthropicKey: Bool { anthropicAPIKey != nil }

    /// Key names present in Secrets.plist (never values), used only for diagnostics.
    static var plistKeyNames: [String] {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }
        return plist.keys.sorted()
    }

    private static func key(_ name: String, orEnvironment variable: String) -> String? {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            if let key = plist[name] as? String, isUsable(key) {
                return key.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let match = plist.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value as? String,
               isUsable(match) {
                return match.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let key = ProcessInfo.processInfo.environment[variable], isUsable(key) {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Where the web viewer is hosted. Set `ShareBaseURL` in Secrets.plist to
    /// your own deployment; share links are built against it.
    static let shareBaseURL: String = {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let base = plist["ShareBaseURL"] as? String,
           isUsable(base) {
            return base.hasSuffix("/") ? String(base.dropLast()) : base
        }
        return "https://example.invalid/citytourist"
    }()

    static var hasShareBaseURL: Bool { !shareBaseURL.contains("example.invalid") }

    private static func isUsable(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ignore the placeholders that ship in Secrets.example.plist.
        return !trimmed.isEmpty && !trimmed.hasPrefix("PASTE_") && !trimmed.contains("YOUR-USERNAME")
    }
}
