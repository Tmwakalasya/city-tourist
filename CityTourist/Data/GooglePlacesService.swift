import Foundation
import CoreLocation

/// Client for the Google Places API (New).
///
/// Uses Nearby Search to pull what's actually around a city centre right now,
/// including today's opening hours, and maps the response onto our `Place`.
struct GooglePlacesService {

    enum ServiceError: LocalizedError {
        case missingKey
        case http(status: Int, message: String)
        case transport(Error)
        /// This phone has used its allowance for now; see `RequestBudget`.
        case rateLimited

        var errorDescription: String? {
            switch self {
            case .missingKey:
                "No Google Places API key configured."
            case let .http(status, message):
                "Google Places returned \(status): \(message)"
            case let .transport(error):
                error.localizedDescription
            case .rateLimited:
                "Live places are paused on this device for a while. Try again later."
            }
        }
    }

    private let session: URLSession
    private let apiKey: String
    private let budget: RequestBudget

    init?(session: URLSession = .shared) {
        guard let key = Secrets.googlePlacesAPIKey else { return nil }
        self.init(apiKey: key, session: session, budget: .googlePlaces)
    }

    /// Explicit-key initialiser. Used by tests against a stubbed session.
    init(apiKey: String, session: URLSession = .shared, budget: RequestBudget = .unlimited) {
        self.apiKey = apiKey
        self.session = session
        self.budget = budget
    }

    /// Everything we ask Google for about a place. Field masks are billed, so
    /// this is kept to exactly what the UI renders.
    private static let placeFields = [
        "id",
        "displayName",
        "shortFormattedAddress",
        "location",
        "rating",
        "userRatingCount",
        "priceLevel",
        "types",
        // What the place mainly is. Same billing tier as `types`.
        "primaryType",
        "primaryTypeDisplayName",
        "editorialSummary",
        "photos",
        "currentOpeningHours",
        // Same billing tier as currentOpeningHours. Today's hours can't say
        // whether a museum is open on the Monday of a trip next month.
        "regularOpeningHours"
    ]

    /// Nearby Search nests results under `places`, so its mask is prefixed.
    private static let fieldMask = placeFields.map { "places.\($0)" }.joined(separator: ",")
    private static let detailsFieldMask = placeFields.joined(separator: ",")

    // MARK: Nearby search

    /// One category's worth of places around a city centre.
    func nearby(city: City, category: PlaceCategory, radiusMeters: Double = 12_000,
                prepaid: Bool = false) async throws -> [Place] {
        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:searchNearby")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.setValue(Self.fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")

        var body: [String: Any] = [
            "includedTypes": Self.includedTypes(for: category),
            "maxResultCount": 20,
            "rankPreference": "POPULARITY",
            "locationRestriction": [
                "circle": [
                    "center": [
                        "latitude": city.coordinate.latitude,
                        "longitude": city.coordinate.longitude
                    ],
                    "radius": radiusMeters
                ]
            ]
        ]
        let excluded = Self.excludedTypes(for: category)
        if !excluded.isEmpty { body["excludedTypes"] = excluded }
        // Half the places with a bar are restaurants, which are filed under
        // food. Asking for what a place mainly is keeps all twenty for nightlife.
        if category == .nightlife {
            body["includedTypes"] = nil
            body["includedPrimaryTypes"] = Self.nightlifePrimaryTypes
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await send(request, prepaid: prepaid)
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.http(status: -1, message: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError.http(
                status: http.statusCode,
                message: String(data: data, encoding: .utf8)?.prefix(300).description ?? ""
            )
        }

        let decoded = try JSONDecoder().decode(NearbyResponse.self, from: data)
        return (decoded.places ?? []).compactMap { place in
            // Nearby can return broad or incomplete matches. Wellness requires positive type evidence.
            if category == .relaxation && !Self.isWellness(types: place.types ?? []) { return nil }
            if Self.isEveryday(types: place.types ?? []) { return nil }
            return place.toPlace(cityID: city.id, fallbackCategory: category)
        }
    }

    /// All six categories at once, deduped — one city's full catalogue.
    /// The six are taken from the budget together: a catalogue that would
    /// run out halfway isn't started, rather than paying for half and
    /// throwing it away.
    func catalogue(for city: City) async throws -> [Place] {
        let categories = PlaceCategory.allCases
        guard budget.spend(categories.count) else { throw ServiceError.rateLimited }
        return try await withThrowingTaskGroup(of: [Place].self) { group in
            for category in categories {
                group.addTask { try await nearby(city: city, category: category, prepaid: true) }
            }
            var byID: [String: Place] = [:]
            for try await batch in group {
                for place in batch where byID[place.id] == nil {
                    byID[place.id] = place
                }
            }
            return Array(byID.values).sorted { $0.rating > $1.rating }
        }
    }

    // MARK: Place search

    /// A submitted name or category, independent of the discovery catalogue.
    /// Bias alone can return a namesake in another country, so keep results
    /// within the advertised 50 km area before assigning them to this city.
    static let placeSearchRadiusMeters: Double = 50_000

    func searchPlaces(query: String, city: City, pageToken: String? = nil) async throws
        -> (places: [Place], nextPageToken: String?) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return ([], nil) }
        try Task.checkCancellation()

        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:searchText")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.setValue(Self.fieldMask + ",nextPageToken", forHTTPHeaderField: "X-Goog-FieldMask")
        var body: [String: Any] = [
            "textQuery": "\(trimmed) near \(city.displayName)",
            "pageSize": 20,
            "locationBias": [
                "circle": [
                    "center": ["latitude": city.coordinate.latitude, "longitude": city.coordinate.longitude],
                    "radius": Self.placeSearchRadiusMeters
                ]
            ]
        ]
        if let pageToken { body["pageToken"] = pageToken }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await send(request, prepaid: false)
        try Task.checkCancellation()
        try Self.check(response, data)
        let decoded = try JSONDecoder().decode(NearbyResponse.self, from: data)
        let centre = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
        var seen = Set<String>()
        let places = (decoded.places ?? []).compactMap {
            $0.toPlace(cityID: city.id, fallbackCategory: .attraction)
        }.filter { place in
            let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
            return centre.distance(from: location) <= Self.placeSearchRadiusMeters
                && seen.insert(place.id).inserted
        }
        return (places, decoded.nextPageToken.flatMap { $0.isEmpty ? nil : $0 })
    }

    /// Every request carries the key and names the app: a key restricted to
    /// iOS apps is only honoured when the bundle id comes with it.
    private func authorize(_ request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        Self.identifyApp(&request)
    }

    /// Photos are fetched outside this client, by `PhotoLoader`, but need the
    /// same header.
    static func identifyApp(_ request: inout URLRequest) {
        request.setValue(Bundle.main.bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
    }

    /// `prepaid` when the caller already took this request from the budget.
    private func send(_ request: URLRequest, prepaid: Bool = false) async throws -> (Data, URLResponse) {
        guard prepaid || budget.spend() else { throw ServiceError.rateLimited }
        do {
            return try await session.data(for: request)
        } catch {
            // Offline or cancelled: nothing reached Google, so nothing's owed.
            budget.refund()
            throw ServiceError.transport(error)
        }
    }

    /// Whether an error is this phone's allowance rather than Google failing.
    static func isRateLimited(_ error: Error) -> Bool {
        if case ServiceError.rateLimited = error { return true }
        return false
    }

    // MARK: Place details

    /// One place by id — how a stop or bookmark from an earlier session gets
    /// its details back, since only the id is kept on disk.
    func place(id: String, cityID: String) async throws -> Place {
        guard let url = URL(string: "https://places.googleapis.com/v1/places/\(id)") else {
            throw ServiceError.transport(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        authorize(&request)
        request.setValue(Self.detailsFieldMask, forHTTPHeaderField: "X-Goog-FieldMask")

        let (data, response) = try await send(request)
        try Self.check(response, data)
        let decoded = try JSONDecoder().decode(GooglePlace.self, from: data)

        // The category it was first found under isn't stored, so an
        // unrecognised type set lands on the broadest one.
        guard let place = decoded.toPlace(cityID: cityID, fallbackCategory: .attraction) else {
            throw ServiceError.http(status: 200, message: "Place details were incomplete.")
        }
        return place
    }

    // MARK: City search

    /// Autocomplete over cities only. Cheap and partial-match friendly, so it
    /// runs on every keystroke (debounced); the expensive details call happens
    /// once, when a suggestion is picked.
    ///
    /// `sessionToken` ties the keystrokes and the eventual details call into
    /// one billable session — pass the same token to `cityDetails`.
    func autocompleteCities(input: String, sessionToken: String) async throws -> [CitySuggestion] {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        var request = URLRequest(url: URL(string: "https://places.googleapis.com/v1/places:autocomplete")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "input": trimmed,
            "includedPrimaryTypes": ["(cities)"],
            "sessionToken": sessionToken
        ])

        let (data, response) = try await send(request)
        try Self.check(response, data)
        let decoded = try JSONDecoder().decode(AutocompleteResponse.self, from: data)
        return (decoded.suggestions ?? []).compactMap { suggestion in
            guard let prediction = suggestion.placePrediction,
                  let id = prediction.placeId,
                  let name = prediction.structuredFormat?.mainText?.text
            else { return nil }
            return CitySuggestion(
                id: id,
                name: name,
                region: prediction.structuredFormat?.secondaryText?.text ?? ""
            )
        }
    }

    /// Turns a picked suggestion into a full `City` with coordinates and a cover photo.
    func cityDetails(placeID: String, sessionToken: String) async throws -> City {
        var components = URLComponents(string: "https://places.googleapis.com/v1/places/\(placeID)")!
        components.queryItems = [URLQueryItem(name: "sessionToken", value: sessionToken)]

        var request = URLRequest(url: components.url!)
        authorize(&request)
        request.setValue(
            "id,displayName,formattedAddress,location,photos,editorialSummary",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        let (data, response) = try await send(request)
        try Self.check(response, data)
        let place = try JSONDecoder().decode(CityDetails.self, from: data)

        guard let name = place.displayName?.text,
              let latitude = place.location?.latitude,
              let longitude = place.location?.longitude
        else { throw ServiceError.http(status: 200, message: "City details were incomplete.") }

        // "Barcelona, Spain" — everything after the city name is the region.
        let country = place.formattedAddress?
            .split(separator: ",")
            .dropFirst()
            .joined(separator: ",")
            .trimmingCharacters(in: .whitespaces) ?? ""

        return City(
            id: place.id ?? placeID,
            name: name,
            country: country,
            tagline: place.editorialSummary?.text ?? "",
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            photoName: place.photos?.first?.name
        )
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.http(status: -1, message: "No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ServiceError.http(
                status: http.statusCode,
                message: String(data: data, encoding: .utf8)?.prefix(300).description ?? ""
            )
        }
    }

    // MARK: Photos

    /// Places photos are served by resource name; the API redirects to the image.
    static func photoURL(name: String, maxHeight: Int = 900) -> URL? {
        guard let key = Secrets.googlePlacesAPIKey else { return nil }
        var components = URLComponents(string: "https://places.googleapis.com/v1/\(name)/media")
        components?.queryItems = [
            URLQueryItem(name: "maxHeightPx", value: String(maxHeight)),
            URLQueryItem(name: "key", value: key)
        ]
        return components?.url
    }

    // MARK: Type mapping

    private static func includedTypes(for category: PlaceCategory) -> [String] {
        switch category {
        case .attraction: ["tourist_attraction", "historical_landmark", "monument"]
        case .food:       ["restaurant", "cafe", "bakery"]
        case .museum:     ["museum", "art_gallery"]
        case .nature:     ["park", "garden", "national_park"]
        case .activity:   activityTypes
        case .nightlife:  ["bar", "night_club"]
        case .relaxation: ["spa", "sauna", "wellness_center", "massage_spa", "yoga_studio"]
        }
    }

    /// A spa, sauna, bathhouse or yoga studio, but not a salon, gym or hotel
    /// that also lists a spa: those aren't what a visitor is looking for.
    static func isWellness(types: [String]) -> Bool {
        let set = Set(types)
        return !set.isDisjoint(with: ["spa", "sauna", "wellness_center", "massage_spa", "yoga_studio"])
            && set.isDisjoint(with: wellnessLookalikes)
    }

    static let wellnessLookalikes: Set<String> = lodgingTypes.union([
        "hair_salon", "hair_care", "beauty_salon", "nail_salon", "barber_shop",
        "beautician", "makeup_artist", "tanning_studio",
        "gym", "fitness_center"
    ])

    private static let lodgingTypes: Set<String> = [
        "lodging", "hotel", "resort_hotel", "motel", "inn", "guest_house", "hostel", "bed_and_breakfast"
    ]

    private static let nightlifeTypes = ["night_club", "bar", "pub", "wine_bar"]
    static let nightlifePrimaryTypes = nightlifeTypes + ["cocktail_bar", "lounge_bar", "sports_bar", "brewpub", "brewery", "bar_and_grill"]
    private static let museumTypes = ["museum", "art_gallery", "performing_arts_theater"]
    private static let foodTypes = ["restaurant", "cafe", "bakery", "meal_takeaway"]
    private static let activityTypes = [
        "market", "shopping_mall", "amusement_park", "zoo",
        "aquarium", "amusement_center", "bowling_alley", "water_park"
    ]
    private static let natureTypes = ["park", "garden", "national_park", "hiking_area", "beach"]
    private static let attractionTypes = ["tourist_attraction", "historical_landmark", "monument", "church", "place_of_worship"]

    /// Places people live beside rather than travel for. In a small city the
    /// most popular "market" is a dollar store and the most popular "bakery"
    /// is inside a supermarket, so discovery leaves these out. A search by
    /// name still finds them.
    static let everydayTypes: Set<String> = [
        "supermarket", "grocery_store", "warehouse_store", "discount_store", "convenience_store",
        "drugstore", "pharmacy", "gas_station", "hardware_store", "home_improvement_store",
        "auto_parts_store", "car_repair", "car_dealer", "car_wash",
        "hospital", "doctor", "dentist", "real_estate_agency",
        "hair_salon", "hair_care", "beauty_salon", "nail_salon", "barber_shop",
        "beautician", "makeup_artist", "tanning_studio"
    ]

    static func isEveryday(types: [String]) -> Bool {
        !everydayTypes.isDisjoint(with: types)
    }

    /// Somewhere to eat, going by what Google says the place mainly is.
    private static func isEatery(_ primaryType: String) -> Bool {
        primaryType == "restaurant" || primaryType.hasSuffix("_restaurant") || [
            "cafe", "bakery", "coffee_shop", "diner", "steak_house", "food_court", "cafeteria", "deli",
            "sandwich_shop", "ice_cream_shop", "dessert_shop", "donut_shop", "bagel_shop", "juice_shop",
            "tea_house", "meal_takeaway", "confectionery"
        ].contains(primaryType)
    }

    /// The category of a place from what it mainly is, or nil when that says
    /// nothing we recognise.
    private static func category(primaryType: String) -> PlaceCategory? {
        if isEatery(primaryType) { return .food }
        if nightlifePrimaryTypes.contains(primaryType) { return .nightlife }
        if (museumTypes + ["art_museum", "history_museum"]).contains(primaryType) { return .museum }
        if (activityTypes + ["video_arcade", "miniature_golf_course", "indoor_playground", "flea_market"]).contains(primaryType) { return .activity }
        if (natureTypes + ["nature_preserve", "botanical_garden", "state_park"]).contains(primaryType) { return .nature }
        if attractionTypes.contains(primaryType) { return .attraction }
        return nil
    }

    /// A place has one category. What Google says it mainly is decides: a
    /// restaurant with a bar is somewhere to eat, and one that hangs art is
    /// not a museum. Without that, its other types decide in this order; a
    /// zoo or a market is something to do even when it's also a tourist
    /// attraction.
    static func category(primaryType: String? = nil, fromTypes types: [String], fallback: PlaceCategory) -> PlaceCategory {
        if isWellness(types: types) { return .relaxation }
        if let primaryType, let category = category(primaryType: primaryType) { return category }
        let set = Set(types)
        if !set.isDisjoint(with: nightlifeTypes) { return .nightlife }
        if !set.isDisjoint(with: museumTypes) { return .museum }
        if !set.isDisjoint(with: foodTypes) { return .food }
        if !set.isDisjoint(with: activityTypes) { return .activity }
        if !set.isDisjoint(with: natureTypes) { return .nature }
        if !set.isDisjoint(with: attractionTypes) { return .attraction }
        return fallback == .relaxation ? .activity : fallback
    }

    /// What a category's request asks Google to leave out. A request returns
    /// twenty places at most, so each one that would be filed under another
    /// category, or dropped as everyday or as not wellness, is a place this
    /// category goes without. Miami's landmarks came back as eight.
    static func excludedTypes(for category: PlaceCategory) -> [String] {
        let elsewhere: [String] = switch category {
        case .attraction: nightlifeTypes + museumTypes + foodTypes + activityTypes + natureTypes
        case .nature:     nightlifeTypes + museumTypes + foodTypes + activityTypes
        case .activity:   nightlifeTypes + museumTypes + foodTypes
        case .relaxation: Array(wellnessLookalikes)
        case .nightlife:  Array(lodgingTypes)
        case .food, .museum: []
        }
        return Set(elsewhere).union(everydayTypes).sorted()
    }

    /// Google doesn't publish visit lengths, so we estimate from the category —
    /// the user can change it on the stop anyway.
    /// `weekdayDescriptions` is Monday-first; `Calendar` weekdays are
    /// Sunday-first (1 = Sunday). Getting this conversion wrong shifts every
    /// opening time by a day silently, so it takes the date as a parameter and
    /// is covered for all seven days in the tests.
    static func todayHours(from descriptions: [String]?, on date: Date = .now,
                           calendar: Calendar = .current) -> String? {
        guard let descriptions, descriptions.count == 7 else { return nil }
        let weekday = calendar.component(.weekday, from: date)  // 1 = Sunday
        let index = (weekday + 5) % 7
        guard descriptions.indices.contains(index) else { return nil }
        // Each entry reads "Tuesday: 9:00 AM – 6:00 PM"; keep just the hours.
        let entry = descriptions[index]
        guard let colon = entry.firstIndex(of: ":") else { return entry }
        return entry[entry.index(after: colon)...].trimmingCharacters(in: .whitespaces)
    }

    static func typicalMinutes(for category: PlaceCategory) -> Int {
        switch category {
        case .attraction: 90
        case .food:       75
        case .museum:     120
        case .nature:     60
        case .activity:   90
        case .nightlife:  110
        case .relaxation: 90
        }
    }
}

// MARK: - Wire format

private struct NearbyResponse: Decodable {
    let places: [GooglePlace]?
    let nextPageToken: String?
}

private struct GooglePlace: Decodable {
    struct LocalizedText: Decodable { let text: String? }
    struct LatLng: Decodable { let latitude: Double?; let longitude: Double? }
    struct Photo: Decodable { let name: String? }
    struct OpeningHours: Decodable {
        struct Period: Decodable {
            struct Point: Decodable {
                let day: Int?
                let hour: Int?
                let minute: Int?

                var minuteOfWeek: Int? {
                    day.map { WeeklyHours.minuteOfWeek(day: $0, hour: hour ?? 0, minute: minute ?? 0) }
                }
            }
            let open: Point?
            let close: Point?
        }
        let openNow: Bool?
        let weekdayDescriptions: [String]?
        let periods: [Period]?

        /// Each period is an open point and a close point, Sunday being day 0.
        /// Google marks a place that never closes with a period that has no
        /// close at all.
        var weeklyHours: WeeklyHours? {
            guard let periods, !periods.isEmpty else { return nil }
            var spans: [WeeklyHours.Span] = []
            for period in periods {
                guard let open = period.open?.minuteOfWeek else { continue }
                guard let close = period.close?.minuteOfWeek else { return .alwaysOpen }
                // A close earlier in the week than its open runs past Saturday night.
                let end = close > open ? close : close + WeeklyHours.minutesPerWeek
                spans.append(WeeklyHours.Span(start: open, end: end))
            }
            return spans.isEmpty ? nil : WeeklyHours(spans: spans)
        }
    }

    let id: String?
    let displayName: LocalizedText?
    let shortFormattedAddress: String?
    let location: LatLng?
    let rating: Double?
    let userRatingCount: Int?
    let priceLevel: String?
    let types: [String]?
    let primaryType: String?
    let primaryTypeDisplayName: LocalizedText?
    let editorialSummary: LocalizedText?
    let photos: [Photo]?
    let currentOpeningHours: OpeningHours?
    let regularOpeningHours: OpeningHours?

    func toPlace(cityID: String, fallbackCategory: PlaceCategory) -> Place? {
        guard let id,
              let name = displayName?.text,
              let latitude = location?.latitude,
              let longitude = location?.longitude
        else { return nil }

        let category = GooglePlacesService.category(primaryType: primaryType, fromTypes: types ?? [], fallback: fallbackCategory)
        let summary = editorialSummary?.text
        let typeLabel = primaryTypeDisplayName?.text ?? category.title

        return Place(
            id: id,
            name: name,
            cityID: cityID,
            category: category,
            neighborhood: shortFormattedAddress ?? typeLabel,
            rating: rating ?? 0,
            reviewCount: userRatingCount ?? 0,
            priceLevel: Self.priceLevel(from: priceLevel),
            typicalMinutes: GooglePlacesService.typicalMinutes(for: category),
            blurb: summary ?? typeLabel,
            about: summary ?? "\(typeLabel) in \(shortFormattedAddress ?? "the city").",
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            tags: Self.tags(from: types ?? []),
            photoName: photos?.first?.name,
            isOpenNow: currentOpeningHours?.openNow,
            todayHours: GooglePlacesService.todayHours(from: currentOpeningHours?.weekdayDescriptions),
            weeklyHours: regularOpeningHours?.weeklyHours
        )
    }

    private static func priceLevel(from value: String?) -> Int {
        switch value {
        case "PRICE_LEVEL_FREE", "PRICE_LEVEL_INEXPENSIVE": 1
        case "PRICE_LEVEL_MODERATE": 2
        case "PRICE_LEVEL_EXPENSIVE": 3
        case "PRICE_LEVEL_VERY_EXPENSIVE": 4
        default: 2
        }
    }

    private static func tags(from types: [String]) -> [String] {
        types
            .filter { !["point_of_interest", "establishment"].contains($0) }
            .prefix(3)
            .map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
    }
}


private struct AutocompleteResponse: Decodable {
    struct Suggestion: Decodable {
        struct Prediction: Decodable {
            struct StructuredFormat: Decodable {
                struct Text: Decodable { let text: String? }
                let mainText: Text?
                let secondaryText: Text?
            }
            let placeId: String?
            let structuredFormat: StructuredFormat?
        }
        let placePrediction: Prediction?
    }
    let suggestions: [Suggestion]?
}

private struct CityDetails: Decodable {
    struct LocalizedText: Decodable { let text: String? }
    struct LatLng: Decodable { let latitude: Double?; let longitude: Double? }
    struct Photo: Decodable { let name: String? }

    let id: String?
    let displayName: LocalizedText?
    let formattedAddress: String?
    let location: LatLng?
    let photos: [Photo]?
    let editorialSummary: LocalizedText?
}
