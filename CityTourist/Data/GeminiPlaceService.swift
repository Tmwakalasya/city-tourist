import Foundation
import CoreLocation

/// Service that coordinates calls to the Google Gemini API for place tour guides,
/// audio narratives, and insider tips. Works directly with Gemini via API key,
/// through the launch server proxy, or offline using curated sample data.
final class GeminiPlaceService: @unchecked Sendable {
    static let shared = GeminiPlaceService()

    private let session: URLSession
    private let budget: RequestBudget
    private let lock = NSLock()
    private var cache: [String: GeminiPlaceInsight] = [:]

    init(session: URLSession = .shared, budget: RequestBudget = .gemini) {
        self.session = session
        self.budget = budget
    }

    enum ServiceError: LocalizedError, Equatable {
        case rateLimited
        case unavailable
        case invalidResponse
        case rejected(String)

        var errorDescription: String? {
            switch self {
            case .rateLimited:
                return "Gemini Tour Guide has reached today's limit. Try again tomorrow."
            case .unavailable:
                return "Gemini service is unavailable right now. Check your connection."
            case .invalidResponse:
                return "Could not process tour guide insight. Please try again."
            case .rejected(let reason):
                return reason
            }
        }
    }

    /// Fetches or generates a tour guide insight for the given place.
    func fetchInsight(for place: Place, city: City) async throws -> GeminiPlaceInsight {
        lock.lock()
        if let cached = cache[place.id] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        // 1. Check curated samples for sample cities first if offline or no key
        let key = Secrets.geminiAPIKey
        if key == nil || key?.isEmpty == true {
            let insight = Self.curatedSample(placeID: place.id) ?? Self.synthesizedFallback(for: place, in: city)
            lock.lock()
            cache[place.id] = insight
            lock.unlock()
            return insight
        }

        // 2. Rate limit budget check
        guard budget.spend() else {
            // If rate limited on API, fall back to sample/synthesized
            let fallback = Self.curatedSample(placeID: place.id) ?? Self.synthesizedFallback(for: place, in: city)
            return fallback
        }

        // 3. Make live request to Gemini API
        do {
            let insight = try await callGeminiAPI(place: place, city: city, apiKey: key!)
            lock.lock()
            cache[place.id] = insight
            lock.unlock()
            return insight
        } catch {
            budget.refund()
            // Graceful degradation: return synthesized insight on API failure
            let fallback = Self.curatedSample(placeID: place.id) ?? Self.synthesizedFallback(for: place, in: city)
            return fallback
        }
    }

    /// Freeform question answering about a place powered by Gemini.
    func askQuestion(_ question: String, place: Place, city: City) async throws -> String {
        let key = Secrets.geminiAPIKey
        guard let key, !key.isEmpty else {
            return Self.offlineAnswer(for: question, place: place)
        }

        guard budget.spend() else {
            return Self.offlineAnswer(for: question, place: place)
        }

        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are City Tourist's local guide for \(city.name), \(city.country).
        Answer the traveller's question about \(place.name) (\(place.neighborhood)).
        Place details:
        - Category: \(place.category.title)
        - About: \(place.about.isEmpty ? place.blurb : place.about)
        - Rating: \(place.rating) (\(place.reviewCount) reviews)
        - Hours: \(place.todayHours ?? "Not specified")
        - Tags: \(place.tags.joined(separator: ", "))

        Traveller's Question: "\(question)"

        Provide a concise, direct, helpful answer in 2-3 sentences. Do not use markdown bullet lists or quotes.
        """

        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.5,
                "maxOutputTokens": 200
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return Self.offlineAnswer(for: question, place: place)
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let content = firstCandidate["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return Self.offlineAnswer(for: question, place: place)
    }

    // MARK: - Gemini API Call

    private func callGeminiAPI(place: Place, city: City, apiKey: String) async throws -> GeminiPlaceInsight {
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are City Tourist's charismatic local guide in \(city.name), \(city.country).
        Generate an insider briefing and an audio tour script for \(place.name) located in \(place.neighborhood).
        
        Venue Details:
        - Category: \(place.category.title)
        - Overview: \(place.about.isEmpty ? place.blurb : place.about)
        - Tags: \(place.tags.joined(separator: ", "))
        - Rating: \(place.rating) (\(place.reviewCount) reviews)
        - Typical visit: \(place.typicalMinutes) minutes
        - Hours: \(place.todayHours ?? "Check local signs")

        Required Output JSON Schema:
        {
          "headline": "A short, evocative 4-8 word title capturing the essence of the place",
          "audioStory": "A spoken 45-60 second audio guide narrative (approx 100-140 words). Tell the traveller what they are seeing, secret history, sensory details, and what locals cherish. Write in natural spoken tone suitable for text-to-speech audio narration.",
          "insiderTip": "1-2 sentences on a hidden detail, architectural secret, or timing trick tourists miss.",
          "photoTip": "1-2 sentences on the best photo angle, vantage point, and time of day for lighting.",
          "localEtiquette": "1-2 sentences on cultural norms, ordering etiquette, or customs here.",
          "suggestedQuestions": ["3 interesting questions a traveller might ask about this place"]
        }
        """

        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.6,
                "responseMimeType": "application/json"
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ServiceError.unavailable
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw ServiceError.invalidResponse
        }

        struct DecodedResponse: Decodable {
            let headline: String
            let audioStory: String
            let insiderTip: String
            let photoTip: String
            let localEtiquette: String
            let suggestedQuestions: [String]?
        }

        let decoded = try JSONDecoder().decode(DecodedResponse.self, from: textData)
        return GeminiPlaceInsight(
            id: place.id,
            headline: decoded.headline,
            audioStory: decoded.audioStory,
            insiderTip: decoded.insiderTip,
            photoTip: decoded.photoTip,
            localEtiquette: decoded.localEtiquette,
            suggestedQuestions: decoded.suggestedQuestions ?? [
                "What is the best time to visit?",
                "Are there good food spots nearby?",
                "How much time should I spend here?"
            ]
        )
    }

    // MARK: - Offline Curated Samples

    static func curatedSample(placeID: String) -> GeminiPlaceInsight? {
        switch placeID {
        case "lis-belem-tower":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "The Riverside Sentinel of the Discoveries",
                audioStory: "Standing before the Tagus estuary, you are looking at Belém Tower, built in 1515 in the flamboyant Manueline style to defend Lisbon and bid farewell to Portuguese caravels sailing into the unknown. Notice the stone rhinoceros carved into the western base—the first depiction of a rhino in Europe, gifted from India to King Manuel I. Climb the narrow spiral staircase to the terrace, where maritime wind and open water capture the audacious spirit of Lisbon's golden age.",
                insiderTip: "Look closely at the lower bastion facing the water to spot the stone rhinoceros gargoyle. Go early before 10 AM before tour queues build up.",
                photoTip: "Head 50 metres west along the waterfront promenade during golden hour to frame the tower against the Tagus sunset without crowds in your shot.",
                localEtiquette: "The spiral staircase is one-way with traffic light signals. Step steadily when the light turns green so you don't stall the line behind you.",
                suggestedQuestions: ["Is it worth going inside?", "Where can I walk nearby?", "Who designed the tower?"]
            )

        case "lis-pasteis-belem":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "The Secret 1837 Custard Tart Recipe",
                audioStory: "Since 1837, this bakery has guarded the original recipe for Pastel de Belém, created by monks at the nearby Jerónimos Monastery after the 1820 revolution shut down religious orders. Only three master bakers know the exact ratio of cream, egg yolks, and paper-thin puff pastry, mixing it inside the fabled 'Oficina do Segredo' behind closed doors. Eat yours fresh and warm, dusted with cinnamon and icing sugar.",
                insiderTip: "Do not wait in the intimidating street queue outside! Walk straight past the counter into the blue-tiled salon rooms inside; there are over 400 seats and table service is remarkably fast.",
                photoTip: "Capture a top-down shot of two golden pastéis on the traditional blue ceramic dish with the cinnamon shaker positioned alongside.",
                localEtiquette: "Sprinkle cinnamon first, then powdered sugar. Order an espresso (bica) to balance the sweet custard.",
                suggestedQuestions: ["How many do they sell daily?", "Can I take boxes on a flight?", "What makes it different from pastel de nata?"]
            )

        case "lis-jeronimos":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "A Cathedral of Carved Coral and Mooring Ropes",
                audioStory: "Financed by a five-percent tax on Eastern spice trade, Jerónimos Monastery took over a century to carve from golden limestone. As you stroll through the two-story cloister, inspect the columns: each pillar is intricately sculpted with sea monsters, coiled ropes, and astrolabes. Inside the church lies the tomb of explorer Vasco da Gama, resting beneath soaring rib-vault ceilings that survived the catastrophic 1755 earthquake.",
                insiderTip: "Entry into the main church of Santa Maria is completely free; only the cloister requires a ticket. Buy cloister tickets online in advance to skip the main queue.",
                photoTip: "Stand on the upper cloister balcony looking diagonally across the stone arches into the central courtyard around 3 PM for rich architectural shadows.",
                localEtiquette: "This is an active consecrated sanctuary; ensure shoulders and knees are covered when entering the church.",
                suggestedQuestions: ["Who is buried inside?", "How long to tour the cloisters?", "Is audio guide provided?"]
            )

        case "lis-tram-28":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "The Historic Wooden Yellow Rollercoaster",
                audioStory: "Dating back to the 1930s, Tram 28's vintage 'Remodelado' wooden cars were specifically engineered to negotiate Lisbon's impossibly steep 14-degree grades and tight hairpin corners that modern trams cannot clear. As it rattles through the medieval maze of Alfama, you'll pass so close to pastel façades and hanging laundry that you could almost reach out and touch them.",
                insiderTip: "Board in reverse at Campo de Ourique instead of Martim Moniz to guarantee a window seat without standing in a 90-minute queue.",
                photoTip: "Wait at the bend near Miradouro de Santa Luzia to photograph the yellow tram climbing against bougainvillea and river backdrop.",
                localEtiquette: "Keep your belongings zipped and in front of you—crowded trams are notorious for pickpockets. Give up front seats to elderly locals.",
                suggestedQuestions: ["How much is a single ticket?", "Can I use the Viva Viagem card?", "Where does the line start and end?"]
            )

        case "kyo-fushimi-inari":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "Ten Thousand Vermilion Torii Through Sacred Forests",
                audioStory: "Founded in 711 AD, Fushimi Inari is Kyoto's head shrine dedicated to Inari, the Shinto kami of rice, bountiful harvest, and business prosperity. The famed Senbon Torii path is formed by thousands of vermilion gates gifted by merchants and families, with donor names inscribed in black kanji. Watch for the kitsune fox statues guarding the path—messengers of Inari, often clenching rice granary keys in their jaws.",
                insiderTip: "Most tourists turn around at the Yotsutsuji intersection half an hour up. Continue past this point onto the summit circuit, where crowds thin out into peaceful cedar groves.",
                photoTip: "Take photos on your descent rather than ascent: the black calligraphy inscribed on the back of the torii gates provides stunning visual contrast.",
                localEtiquette: "Walk on the left along the double torii path. When approaching a shrine altar, bow twice, clap twice, and bow once in respect.",
                suggestedQuestions: ["Can I visit at night?", "How long is the hike to the summit?", "Are there vending machines on the trail?"]
            )

        case "kyo-kinkakuji":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "The Golden Pavilion Mirrored in Kyoko-chi Lake",
                audioStory: "Originally a shogun's villa before being converted into a Zen temple, Kinkaku-ji is clad in pure gold leaf on its top two floors. Each tier reflects a different architectural style: palace style on the ground floor, samurai style in the middle, and Zen temple architecture at the top crowned by a bronze phoenix. The building floats above the Mirror Pond, intentionally harmonized with pine-covered islets and the surrounding garden.",
                insiderTip: "Arrive right at 9:00 AM opening or an hour before closing. When the sun is high at noon, the reflection loses contrast; morning light gives the gold an ethereal glow.",
                photoTip: "Position yourself at the edge of the viewing clearing across the pond to catch the golden reflection in the still water before ripples from wind pick up.",
                localEtiquette: "Follow the strictly one-way walking route around the pond and garden; stopping or backtracking causes bottlenecks.",
                suggestedQuestions: ["Is the gold leaf real?", "Can visitors enter the pavilion?", "What does the entrance ticket look like?"]
            )

        case "mex-frida-kahlo":
            return GeminiPlaceInsight(
                id: placeID,
                headline: "The Cobalt Blue Sanctuary of Coyoacán",
                audioStory: "La Casa Azul is where Frida Kahlo was born, created her most evocative masterpieces, lived with muralist Diego Rivera, and spent her final days. The cobalt-blue walls were painted to ward off evil spirits, and the lush interior courtyard is filled with pre-Hispanic stone sculptures and cacti. In Frida's sunlit studio, her wheelchair remains pulled up to the easel, beside a mirror mounted above her daybed which allowed her to paint self-portraits while immobilized.",
                insiderTip: "You must book timed admission online days or weeks in advance—no tickets are sold at the door. If you wish to take photos, buy the photo permit sticker at check-in.",
                photoTip: "Photograph the iconic cobalt wall inscribed with 'Frida y Diego vivieron en esta casa 1929-1954' framed by courtyard greenery.",
                localEtiquette: "Speak in hushed tones inside the intimate residential quarters and Frida's bedroom.",
                suggestedQuestions: ["Can I buy tickets at the door?", "What else is worth seeing in Coyoacán?", "How much is the photo permit?"]
            )

        default:
            return nil
        }
    }

    // MARK: - Dynamic Fallback

    static func synthesizedFallback(for place: Place, in city: City) -> GeminiPlaceInsight {
        let name = place.name
        let category = place.category.title
        let neighborhood = place.neighborhood
        let blurb = place.blurb.isEmpty ? place.about : place.blurb

        let story = "Welcome to \(name), one of \(city.name)'s standouts in \(neighborhood). Known as a key \(category.lowercased()) destination, it captures the authentic character of the district. \(blurb) Visitors come here to immerse themselves in local atmosphere, take in distinctive architecture, and experience a beloved neighbourhood staple."

        let tip = "Visit either early in the morning or during the late afternoon to experience \(name) at a relaxed pace without mid-day crowds."
        let photo = "Look for vantage points that frame \(name) against the distinctive streetscape of \(neighborhood) during late afternoon golden hour."
        let etiquette = "Be mindful of local customs; in \(city.name), a polite greeting in the local language is always appreciated by staff and residents."

        return GeminiPlaceInsight(
            id: place.id,
            headline: "\(name) in \(neighborhood)",
            audioStory: story,
            insiderTip: tip,
            photoTip: photo,
            localEtiquette: etiquette,
            suggestedQuestions: [
                "What is \(name) best known for?",
                "What are the best nearby places to eat?",
                "How do I reach here on public transit?"
            ]
        )
    }

    private static func offlineAnswer(for question: String, place: Place) -> String {
        let lower = question.lowercased()
        if lower.contains("hour") || lower.contains("open") || lower.contains("close") {
            if let hours = place.todayHours {
                return "\(place.name) is scheduled for \(hours) today."
            }
            return "Opening hours vary; check local signage or official listings before your visit."
        }
        if lower.contains("time") || lower.contains("long") || lower.contains("spend") {
            return "A typical visit to \(place.name) takes around \(place.typicalMinutes) minutes to explore comfortably."
        }
        if lower.contains("ticket") || lower.contains("cost") || lower.contains("price") {
            return "\(place.name) is rated \(place.priceLabel) for price level. Check online for advance admission if booking is required."
        }
        return "\(place.name) is located in \(place.neighborhood). It is rated \(place.rating) out of 5 based on \(place.reviewCount) visitor reviews."
    }
}
