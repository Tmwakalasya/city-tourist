import Foundation

/// Where the API keys come from.
///
/// Order: `Secrets.plist` in the app bundle, then an environment variable on
/// the scheme. Keys never go in source control — `Secrets.plist` is gitignored
/// and `Secrets.example.plist` shows the shape.
///
/// Whatever is in the bundle ships to every phone and can be read out of the
/// app, so only keys that are safe there go here: ones Google restricts to
/// this app's bundle ID, and public ones. A key that spends money for whoever
/// holds it (Claude's) stays on the server.
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

    /// Where the AI concierge and the trip builder send their requests: the
    /// launch site's `/api/ai`, which holds the Claude key. No AI key belongs
    /// in the app or in Secrets.plist; everything in the bundle can be read
    /// by anyone who has the app. `AIProxyURL` points a build at another
    /// deployment.
    static let aiBaseURL: URL = {
        if let raw = key("AIProxyURL", orEnvironment: "AI_PROXY_URL"),
           let url = URL(string: raw), url.scheme == "https", url.host != nil {
            return url
        }
        return URL(string: defaultAIBaseURL)!
    }()

    static let defaultAIBaseURL = "https://citytourist.pages.dev/api/ai"

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

    /// Where the web viewer is hosted: the launch site's own `/trip` page,
    /// unless `ShareBaseURL` in Secrets.plist points at another deployment.
    /// Share links are built against it.
    static let shareBaseURL: String = {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let base = plist["ShareBaseURL"] as? String,
           isUsable(base) {
            return base.hasSuffix("/") ? String(base.dropLast()) : base
        }
        return defaultShareBaseURL
    }()

    static let defaultShareBaseURL = "https://citytourist.pages.dev/trip"

    static var hasShareBaseURL: Bool { !shareBaseURL.contains("example.invalid") }

    private static func isUsable(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ignore the placeholders that ship in Secrets.example.plist.
        return !trimmed.isEmpty && !trimmed.hasPrefix("PASTE_") && !trimmed.contains("YOUR-USERNAME")
    }
}
