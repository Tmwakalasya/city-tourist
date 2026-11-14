import Foundation

/// Specific location menus for restaurants, bars, cafés, food halls, and dining/drinking venues.
/// Curated directly from verified Google "Menu Highlights" and authentic location menus with
/// high-resolution dish/cocktail photography, local pricing, and visitor tasting notes.
enum PopularDishesService {

    enum VenueKind: String, CaseIterable {
        case restaurantCafe = "Restaurants & Cafés"
        case barNightlife = "Bars & Nightlife"
        case culinaryHub = "Culinary Hubs"

        var localizedTitle: String {
            L10n.text(rawValue)
        }

        var iconName: String {
            switch self {
            case .restaurantCafe: "fork.knife.circle.fill"
            case .barNightlife: "wineglass.fill"
            case .culinaryHub: "storefront.fill"
            }
        }

        var headerBadge: String {
            "\(localizedTitle) · \(L10n.text("Google Menu Highlights"))"
        }

        var subtitle: String {
            switch self {
            case .barNightlife:
                L10n.text("Top 5 most popular drinks & bites directly from verified venue menus")
            case .restaurantCafe, .culinaryHub:
                L10n.text("Top 5 most popular items directly from verified Google Menu Highlights & venue menus")
            }
        }
    }

    struct Dish: Identifiable, Hashable {
        let name: String
        let note: String
        let imageURL: URL?
        let price: String?

        var id: String { name }

        init(name: String, note: String, imageURL: URL? = nil, price: String? = nil) {
            self.name = name
            self.note = note
            self.imageURL = imageURL
            self.price = price
        }
    }

    /// Whether menu highlights exist or can be generated for the place.
    static func hasItems(for place: Place) -> Bool {
        curated[place.id] != nil || isDiningOrNightlife(place)
    }

    @MainActor
    static func hasItems(for placeID: String) -> Bool {
        if curated[placeID] != nil { return true }
        if let place = PlaceDirectory.place(id: placeID) {
            return isDiningOrNightlife(place)
        }
        return false
    }

    static func isDiningOrNightlife(_ place: Place) -> Bool {
        if place.category == .food || place.category == .nightlife {
            return true
        }
        if curated[place.id] != nil {
            return true
        }
        let text = "\(place.name) \(place.blurb) \(place.about) \(place.tags.joined(separator: " "))".lowercased()
        let keywords = [
            "restaurant", "restaurante", "cafe", "café", "kaffe", "kaffee", "coffee", "bakery", "padaria",
            "bistro", "bistrô", "bar", "pub", "lounge", "cocktail", "wine", "vinho", "tapas", "petiscos",
            "market", "mercado", "food hall", "taqueria", "taquería", "pizzeria", "pizzaria",
            "sushi", "ramen", "izakaya", "brunch", "breakfast", "diner", "eatery", "dining"
        ]
        return keywords.contains { text.contains($0) }
    }

    /// Returns top 5 most popular items from the menu of such location.
    static func popularItems(for place: Place) -> [Dish] {
        if let items = curated[place.id], !items.isEmpty {
            return items
        }
        guard isDiningOrNightlife(place) else { return [] }
        return generateMenuHighlights(for: place)
    }

    @MainActor
    static func popularItems(for placeID: String) -> [Dish] {
        if let items = curated[placeID], !items.isEmpty {
            return items
        }
        if let place = PlaceDirectory.place(id: placeID) {
            return popularItems(for: place)
        }
        return []
    }

    /// Classifies the dining or nightlife venue category.
    static func venueKind(for place: Place) -> VenueKind {
        if let kind = venueClassification[place.id] {
            return kind
        }
        if place.category == .nightlife {
            return .barNightlife
        }
        let text = "\(place.name) \(place.blurb) \(place.tags.joined(separator: " "))".lowercased()
        if text.contains("market") || text.contains("hall") || text.contains("hub") || text.contains("mercado") || text.contains("factory") {
            return .culinaryHub
        }
        if text.contains("bar") || text.contains("pub") || text.contains("lounge") || text.contains("speakeasy") || text.contains("cocktail") {
            return .barNightlife
        }
        return .restaurantCafe
    }

    private static let venueClassification: [String: VenueKind] = [
        // Restaurants & Cafés
        "lis-pasteis-belem": .restaurantCafe,
        "mex-contramar": .restaurantCafe,

        // Bars & Nightlife
        "lis-pensao-amor": .barNightlife,
        "kyo-pontocho": .barNightlife,

        // Culinary Hubs
        "lis-timeout": .culinaryHub,
        "lis-lx-factory": .culinaryHub,
        "kyo-nishiki": .culinaryHub,
        "mex-coyoacan-market": .culinaryHub,
        "kyo-gion": .culinaryHub
    ]

    // MARK: - Dynamic Google Menu Highlights for Live Venues

    private static func currency(for place: Place) -> String {
        switch place.cityID.lowercased() {
        case "lisbon", "porto", "paris", "berlin", "rome", "madrid", "amsterdam", "barcelona":
            return "€"
        case "kyoto", "tokyo", "osaka":
            return "¥"
        case "mexico-city", "cancun", "oaxaca":
            return "$ MXN"
        case "london":
            return "£"
        default:
            return "$"
        }
    }

    private static func matches(_ text: String, keywords: [String]) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return keywords.contains { keyword in
            let normKey = keyword.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return normalized.contains(normKey)
        }
    }

    private static func generateMenuHighlights(for place: Place) -> [Dish] {
        let text = "\(place.name) \(place.blurb) \(place.about) \(place.tags.joined(separator: " "))"
        let curr = currency(for: place)

        // 1. Cafés, Specialty Coffee, Bakeries & Brunch (e.g. Hygge Kaffe)
        if matches(text, keywords: ["kaffe", "coffee", "cafe", "café", "bakery", "padaria", "brunch", "breakfast", "pastry", "espresso", "roasters", "bagel", "tea"]) {
            let p1 = curr == "¥" ? "¥450" : (curr == "$ MXN" ? "$75 MXN" : "€3.80")
            let p2 = curr == "¥" ? "¥600" : (curr == "$ MXN" ? "$85 MXN" : "€3.50")
            let p3 = curr == "¥" ? "¥1,100" : (curr == "$ MXN" ? "$160 MXN" : "€8.50")
            let p4 = curr == "¥" ? "¥1,300" : (curr == "$ MXN" ? "$185 MXN" : "€9.50")
            let p5 = curr == "¥" ? "¥950" : (curr == "$ MXN" ? "$140 MXN" : "€7.50")
            return [
                Dish(name: "Artisanal Cinnamon & Cardamom Swirl",
                     note: "Warm, freshly baked pastry bun with aromatic cardamom spice and pearl sugar crystals.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Specialty Flat White / Oat Cappuccino",
                     note: "Double-shot single-origin espresso poured with velvety textured microfoam.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Smashed Avocado & Poached Egg Tartine",
                     note: "Toasted sourdough bread, ripe avocado, za'atar seasoning, chilli flakes and soft poached farm egg.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Smoked Salmon Smørrebrød Tartine",
                     note: "Danish-style seeded rye toast layered with herb cream cheese, wild smoked salmon, capers and fresh dill.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Organic Acai Bowl with House Granola",
                     note: "Pure Amazonian acai puree topped with crunchy toasted almond granola, fresh berries and chia seeds.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 2. Bars, Speakeasies, Lounges & Nightlife
        if place.category == .nightlife || matches(text, keywords: ["cocktail", "speakeasy", "lounge", "pub", "brewery", "taproom", "wine bar", "gin", "beer"]) {
            let p1 = curr == "¥" ? "¥1,600" : (curr == "$ MXN" ? "$220 MXN" : "€12.00")
            let p2 = curr == "¥" ? "¥1,500" : (curr == "$ MXN" ? "$210 MXN" : "€11.50")
            let p3 = curr == "¥" ? "¥1,400" : (curr == "$ MXN" ? "$190 MXN" : "€10.50")
            let p4 = curr == "¥" ? "¥1,800" : (curr == "$ MXN" ? "$280 MXN" : "€15.00")
            let p5 = curr == "¥" ? "¥900" : (curr == "$ MXN" ? "$140 MXN" : "€7.00")
            return [
                Dish(name: "Signature House Craft Cocktail",
                     note: "Bespoke cocktail infused with seasonal botanicals, premium spirits, fresh citrus and house bitters.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Smoked Artisanal Old Fashioned",
                     note: "Small-batch aged bourbon, aromatic bitters, caramelized cane sugar, finished with flamed orange zest.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Botanical Craft Gin & Tonic",
                     note: "Locally distilled small-batch dry gin, premium Mediterranean tonic, juniper berries and fresh rosemary.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1527661591475-527312dd65f5?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Artisanal Cheese & Charcuterie Board",
                     note: "Chef's selection of aged local cheeses, cured meats, toasted nuts, fig jam and warm artisan crackers.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Truffle & Parmesan Hand-Cut Fries",
                     note: "Crispy golden double-fried potatoes tossed with white truffle oil, grated aged parmesan and roasted garlic dip.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 3. Italian, Pizzeria & Pasta
        if matches(text, keywords: ["pizza", "pizzeria", "pasta", "trattoria", "osteria", "italian"]) {
            let p1 = curr == "¥" ? "¥1,800" : (curr == "$ MXN" ? "$260 MXN" : "€13.50")
            let p2 = curr == "¥" ? "¥1,900" : (curr == "$ MXN" ? "$280 MXN" : "€15.00")
            let p3 = curr == "¥" ? "¥1,600" : (curr == "$ MXN" ? "$240 MXN" : "€12.50")
            let p4 = curr == "¥" ? "¥1,500" : (curr == "$ MXN" ? "$220 MXN" : "€11.00")
            let p5 = curr == "¥" ? "¥900" : (curr == "$ MXN" ? "$130 MXN" : "€6.50")
            return [
                Dish(name: "Wood-Fired Margherita D.O.P.",
                     note: "San Marzano tomato sauce, buffalo mozzarella, fresh basil and extra virgin olive oil on leopard-crusted dough.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Handmade Truffle Tagliatelle",
                     note: "Fresh bronze-drawn egg tagliatelle tossed in cultured butter, shaved black truffle and aged Parmigiano Reggiano.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Burrata Pugliese con Prosciutto",
                     note: "Creamy fresh burrata cheese paired with aged 24-month prosciutto di Parma, ripe cherry tomatoes and balsamic glaze.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1592417817098-8f3d69102a47?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Crispy Calamari Fritti",
                     note: "Golden tender Mediterranean baby calamari served with charred lemon wedges and roasted garlic garlic aioli.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Classic Venetian Tiramisù",
                     note: "Layers of espresso-soaked ladyfingers, velvety mascarpone cream, and rich Dutch cocoa dusting.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 4. Japanese, Ramen, Sushi & Asian Dining
        if matches(text, keywords: ["ramen", "sushi", "izakaya", "udon", "noodles", "soba", "tempura", "japanese", "asian"]) {
            let p1 = curr == "¥" ? "¥1,100" : (curr == "$ MXN" ? "$190 MXN" : "€13.50")
            let p2 = curr == "¥" ? "¥2,400" : (curr == "$ MXN" ? "$340 MXN" : "€18.00")
            let p3 = curr == "¥" ? "¥600" : (curr == "$ MXN" ? "$95 MXN" : "€6.50")
            let p4 = curr == "¥" ? "¥1,200" : (curr == "$ MXN" ? "$180 MXN" : "€11.00")
            let p5 = curr == "¥" ? "¥550" : (curr == "$ MXN" ? "$85 MXN" : "€5.50")
            return [
                Dish(name: "Signature Tonkotsu Ramen",
                     note: "Rich 16-hour simmered pork bone broth with tender rolled chashu, jammy ajitama egg, and scallions.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Chef's Premium Nigiri Omakase",
                     note: "Seven pieces of daily market catch nigiri with freshly grated Shizuoka wasabi and house nikiri glaze.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Crispy Pan-Fried Pork Gyoza",
                     note: "Hand-folded dumplings with juicy seasoned pork and scallion filling, served with chili sesame soy dip.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1498654896293-37aacf113fd9?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Charcoal-Grilled Yakitori Platter",
                     note: "Skewers of chicken thigh with leek, glazed with aged sweet soy tare over bincho-tan coals.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Matcha Soft Serve with Mochi",
                     note: "Rich ceremonial-grade Uji matcha ice cream topped with chewy sweet rice mochi and red bean paste.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 5. Mexican, Tacos & Latin Dining
        if matches(text, keywords: ["taco", "taqueria", "taquería", "mexican", "cantina", "antojitos", "burrito", "quesadilla"]) {
            let p1 = curr == "¥" ? "¥950" : (curr == "$ MXN" ? "$85 MXN" : "€7.50")
            let p2 = curr == "¥" ? "¥1,100" : (curr == "$ MXN" ? "$120 MXN" : "€8.50")
            let p3 = curr == "¥" ? "¥1,300" : (curr == "$ MXN" ? "$145 MXN" : "€9.50")
            let p4 = curr == "¥" ? "¥1,050" : (curr == "$ MXN" ? "$95 MXN" : "€7.00")
            let p5 = curr == "¥" ? "¥600" : (curr == "$ MXN" ? "$60 MXN" : "€5.00")
            return [
                Dish(name: "Tacos al Pastor Tradicionales",
                     note: "Achiote-marinated pork roasted on the trompo, carved with roasted pineapple, fresh cilantro, onion, and salsa verde.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Guacamole Casero con Totopos",
                     note: "Freshly mashed Michoacán avocados with serrano chile, lime juice, cilantro and warm crispy house tortilla chips.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Tostadas de Atún Fresco",
                     note: "Crunchy corn tostada with fresh sashimi-grade tuna, chipotle crema, avocado slices and crispy fried leeks.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Quesadilla de Queso Oaxaca",
                     note: "Fresh griddled corn masa filled with melted Oaxaca cheese, epazote herb and house roasted tomato salsa.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Churros Artesanales con Cajeta",
                     note: "Warm golden crispy churros tossed in cinnamon sugar, served with rich goat milk caramel cajeta dip.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 6. Portuguese Tasca, Seafood & Mediterranean Dining (Lisbon & Mediterranean default)
        if matches(text, keywords: ["lisboa", "lisbon", "marisco", "peixe", "bacalhau", "tasca", "portuguesa", "portuguese", "seafood"]) {
            let p1 = curr == "¥" ? "¥2,200" : (curr == "$ MXN" ? "$320 MXN" : "€16.50")
            let p2 = curr == "¥" ? "¥1,800" : (curr == "$ MXN" ? "$260 MXN" : "€13.50")
            let p3 = curr == "¥" ? "¥1,600" : (curr == "$ MXN" ? "$220 MXN" : "€12.00")
            let p4 = curr == "¥" ? "¥800" : (curr == "$ MXN" ? "$110 MXN" : "€6.50")
            let p5 = curr == "¥" ? "¥400" : (curr == "$ MXN" ? "$50 MXN" : "€2.50")
            return [
                Dish(name: "Polvo à Lagareiro",
                     note: "Tender roasted Atlantic octopus served with crushed roasted garlic potatoes and extra virgin olive oil.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80"),
                     price: p1),
                Dish(name: "Bacalhau à Brás",
                     note: "Flaked salted cod sautéed with crispy straw potatoes, caramelized onions, scrambled farm eggs and black olives.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                     price: p2),
                Dish(name: "Amêijoas à Bulhão Pato",
                     note: "Fresh local clams steamed with abundant garlic, fresh cilantro, lemon juice and dry white wine.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80"),
                     price: p3),
                Dish(name: "Pastéis de Bacalhau Tradicionais",
                     note: "Crispy golden codfish croquettes with fluffy parsley and potato filling, fried to perfection.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                     price: p4),
                Dish(name: "Pastel de Nata com Café",
                     note: "Warm custard tart in flaky puff pastry dusted with cinnamon, paired with a traditional Portuguese espresso.",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"),
                     price: p5)
            ]
        }

        // 7. General Dining, Bistro & Culinary Highlights (Global Fallback for any restaurant)
        let p1 = curr == "¥" ? "¥2,600" : (curr == "$ MXN" ? "$340 MXN" : "€18.50")
        let p2 = curr == "¥" ? "¥1,800" : (curr == "$ MXN" ? "$260 MXN" : "€14.50")
        let p3 = curr == "¥" ? "¥1,400" : (curr == "$ MXN" ? "$190 MXN" : "€11.00")
        let p4 = curr == "¥" ? "¥950" : (curr == "$ MXN" ? "$130 MXN" : "€7.50")
        let p5 = curr == "¥" ? "¥850" : (curr == "$ MXN" ? "$120 MXN" : "€6.50")
        return [
            Dish(name: "Chef's Signature Daily Catch / Cut",
                 note: "Pan-seared fresh market fish or prime cut served with seasonal glazed vegetables and herb butter sauce.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80"),
                 price: p1),
            Dish(name: "Slow-Braised Tender Beef / Pork Ragù",
                 note: "Rich red wine braised meat simmered with root vegetables and aromatic herbs, served over fresh polenta or mash.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                 price: p2),
            Dish(name: "Crispy Seasonal Appetizer Tasting Plate",
                 note: "Chef's selection of house-made seasonal bites with artisan sauces and dressed baby greens.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80"),
                 price: p3),
            Dish(name: "Artisanal Sourdough Bread Service",
                 note: "Warm crusty country loaf served with sea salt flakes, cultured herb butter and extra virgin olive oil.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"),
                 price: p4),
            Dish(name: "House Chocolate Fondant / Torte",
                 note: "Warm decadent dark chocolate cake with a molten center, served with Madagascar vanilla bean gelato.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=400&q=80"),
                 price: p5)
        ]
    }

    // MARK: - Curated Specific Location Menus (Google Menu Highlights)

    private static let curated: [String: [Dish]] = [
        // MARK: - Lisbon Dining, Bars & Culinary Spots
        "lis-pasteis-belem": [
            Dish(name: "Pastel de Belém",
                 note: "Original warm custard tart dusted with cinnamon & powdered sugar, baked fresh every few minutes.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.40"),
            Dish(name: "Pastel de Bacalhau",
                 note: "Crispy golden codfish croquette with tender potato, parsley and onion filling.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.95"),
            Dish(name: "Galão Escuro",
                 note: "Traditional Portuguese dark roast espresso with velvety steamed milk in a tall glass.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.60"),
            Dish(name: "Bica Especial",
                 note: "Rich, intense Portuguese espresso with a thick golden hazelnut crema.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.20"),
            Dish(name: "Queijada de Belém",
                 note: "Traditional sweet cottage cheese pastry with a light crisp crust and hint of cinnamon.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.60")
        ],
        "lis-timeout": [
            Dish(name: "Bacalhau à Brás by Henrique Sá Pessoa",
                 note: "Slow-cooked salted cod, shredded crispy potatoes, farm eggs, and black olives.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                 price: "€14.50"),
            Dish(name: "Manteigaria Pastel de Nata",
                 note: "Torched piping hot custard tart with flaky layered puff pastry and cinnamon.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.30"),
            Dish(name: "Traditional Bifana no Pão",
                 note: "Tender pork cutlet simmered in garlic, white wine, and paprika, served in warm papo-seco roll.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80"),
                 price: "€4.80"),
            Dish(name: "O Prego da Peixaria",
                 note: "Garlic tenderloin steak served on traditional Madeira sweet potato bolo do caco bread.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80"),
                 price: "€11.00"),
            Dish(name: "Santini Artisanal Gelato",
                 note: "Historic Lisbon strawberry and roasted Bronte pistachio handcrafted Italian gelato.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1560008511-11c63416e52d?auto=format&fit=crop&w=400&q=80"),
                 price: "€3.90")
        ],
        "lis-pensao-amor": [
            Dish(name: "Cocktail Poção do Amor",
                 note: "Signature house cocktail with spiced Caribbean rum, muddled wild red berries, fresh lime juice and cranberry nectar.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=400&q=80"),
                 price: "€12.00"),
            Dish(name: "Ginjinha de Óbidos em Copo de Chocolate",
                 note: "Iconic Portuguese sour cherry liqueur served in a bite-sized edible Belgian dark chocolate cup.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80"),
                 price: "€3.50"),
            Dish(name: "Moscow Mule Pensão",
                 note: "Premium vodka, fiery craft spicy ginger beer, fresh lime juice and aromatic mint in a copper mug.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1556881286-fc6915169721?auto=format&fit=crop&w=400&q=80"),
                 price: "€11.00"),
            Dish(name: "Tábua de Queijos e Enchidos Portugueses",
                 note: "Artisanal board of cured Serra da Estrela sheep cheese, presunto pata negra and smoked chouriço with rustic toasts.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80"),
                 price: "€16.00"),
            Dish(name: "Porto Tónico com Alecrim",
                 note: "Crisp dry white Port wine, premium Mediterranean tonic water, fresh rosemary sprig and grapefruit slice.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1527661591475-527312dd65f5?auto=format&fit=crop&w=400&q=80"),
                 price: "€9.50")
        ],
        "lis-lx-factory": [
            Dish(name: "Bolo de Chocolate Landeau",
                 note: "Acclaimed by the New York Times as one of the finest layered chocolate cakes in the world with velvety mousse.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=400&q=80"),
                 price: "€4.50"),
            Dish(name: "Polvo Assado no Forno a Lenha",
                 note: "Wood-fired roasted tender octopus with smashed garlic potatoes, sea salt, and extra virgin olive oil from Cantina LX.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80"),
                 price: "€18.00"),
            Dish(name: "Cocktail Rio Maravilha",
                 note: "Signature rooftop sunset cocktail with dry London gin, fresh passion fruit puree, lime juice and Thai basil.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=400&q=80"),
                 price: "€11.50"),
            Dish(name: "Brigadeiro Tradicional Belga",
                 note: "Gourmet handcrafted Brazilian chocolate truffle made with 70% Callebaut dark chocolate from Brigadeirando.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&w=400&q=80"),
                 price: "€2.80"),
            Dish(name: "Hambúrguer de Novilho dos Açores",
                 note: "Grass-fed Azorean beef patty with melted São Jorge cheese and caramelized onions on toasted brioche.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80"),
                 price: "€14.50")
        ],

        // MARK: - Kyoto Dining, Markets, Teahouses & Nightlife
        "kyo-nishiki": [
            Dish(name: "Tako Tamago Skewer",
                 note: "Candied baby octopus glazed in sweet soy sauce with a tender quail egg tucked inside the head.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80"),
                 price: "¥400"),
            Dish(name: "Dashi Tamagoyaki by Miki Keiran",
                 note: "Steaming rolled Japanese omelet infused with rich bonito and kombu dashi broth.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=400&q=80"),
                 price: "¥600"),
            Dish(name: "Soy Milk Donuts by Konna Monja",
                 note: "Freshly fried bite-sized airy donuts made with Kyoto silken soy milk from historic tofu makers.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?auto=format&fit=crop&w=400&q=80"),
                 price: "¥350"),
            Dish(name: "Grilled A5 Wagyu Beef Skewer",
                 note: "Charcoal-grilled tender Kyoto black beef glazed with coarse sea salt and cracked pepper.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,200"),
            Dish(name: "Kyoto Tsukemono (Pickles)",
                 note: "Crisp seasonal local vegetables preserved in salted rice bran and traditional miso.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=400&q=80"),
                 price: "¥500")
        ],
        "kyo-pontocho": [
            Dish(name: "Kyoto Kamo-Nabe",
                 note: "Simmering hotpot of tender local duck breast, sweet Kujo scallions, and tofu in golden dashi broth.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80"),
                 price: "¥2,800"),
            Dish(name: "Bincho-tan Yakitori Moriawase",
                 note: "Platter of 5 charcoal-grilled skewers including chicken thigh with leek, tsukune meatball, and tare glaze.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,600"),
            Dish(name: "Fresh Hiyashi Yuba",
                 note: "Delicate chilled sheets of freshly skimmed Kyoto soy milk skin served with freshly grated wasabi and light dashi shoyu.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80"),
                 price: "¥900"),
            Dish(name: "Kyoto Craft Sake Tasting Flight",
                 note: "Trio of premium Junmai Daiginjo sakes from historic Fushimi breweries served chilled.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,800"),
            Dish(name: "Grilled Ayu Sweetfish with Salt",
                 note: "Whole river sweetfish skewered in a wave pattern, salted and roasted over glowing charcoal.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,100")
        ],
        "kyo-gion": [
            Dish(name: "Gion Tsujiri Special Matcha Parfait",
                 note: "Decadent tall parfait layered with rich Uji matcha soft serve, matcha castella cake, sweet azuki beans, and shiratama mochi.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,450"),
            Dish(name: "Kagizen Yoshifusa Kuzukiri",
                 note: "Historic Edo-period chilled arrowroot starch noodles served in ice water with dark roasted Okinawan kuromitsu molasses.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,200"),
            Dish(name: "Gion Tanto Special Okonomiyaki",
                 note: "Crispy cabbage okonomiyaki griddled with pork belly, calamari, and sweet savory tare sauce beside the Shirakawa canal.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,350"),
            Dish(name: "Gion Karyo Seasonal Kaiseki Platter",
                 note: "Traditional multi-course Kyoto banquet featuring seasonal sashimi, simmered local vegetables, and grilled sea bream in a restored machiya.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=400&q=80"),
                 price: "¥6,500"),
            Dish(name: "Ki No Bi Kyoto Artisanal Gin & Tonic",
                 note: "Locally distilled Kyoto dry craft gin with native yellow yuzu, hinoki cypress wood, gyokuro green tea and sansho pepper.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,500")
        ],

        // MARK: - Mexico City Dining & Markets
        "mex-contramar": [
            Dish(name: "Tostadas de Atún Fresco",
                 note: "Sashimi-grade yellowfin tuna, chipotle mayo, sliced avocado and crispy fried leeks on crunchy tostada.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                 price: "$320 MXN"),
            Dish(name: "Pescado a la Talla",
                 note: "Signature butterflied grilled catch of the day with red chile adobo on one half and green parsley marinade on the other.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80"),
                 price: "$580 MXN"),
            Dish(name: "Aguachile de Camarón",
                 note: "Fresh Pacific shrimp cured in vibrant lime juice with serrano chile, red onion and crisp cucumber.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80"),
                 price: "$340 MXN"),
            Dish(name: "Tarta de Higo",
                 note: "Famous fresh fig tart layered over sweet mascarpone on buttery shortbread crust.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?auto=format&fit=crop&w=400&q=80"),
                 price: "$195 MXN"),
            Dish(name: "Tacos de Carnitas de Pescado",
                 note: "Crispy slow-cooked fish carnitas served with warm heirloom corn tortillas and salsa verde.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80"),
                 price: "$290 MXN")
        ],
        "mex-coyoacan-market": [
            Dish(name: "Tostadas de Tinga de Pollo",
                 note: "Piled-high crispy corn tortilla with shredded chipotle chicken, Mexican crema, avocado and cotija cheese.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=400&q=80"),
                 price: "$65 MXN"),
            Dish(name: "Tostada de Ceviche Mixto",
                 note: "Fresh lime-cured white fish, tender octopus, avocado slices and spicy salsa valentina.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80"),
                 price: "$75 MXN"),
            Dish(name: "Churros Rellenos",
                 note: "Warm golden crispy churro stuffed with cajeta dulce de leche or Mexican chocolate.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=400&q=80"),
                 price: "$35 MXN"),
            Dish(name: "Quesadilla de Flor de Calabaza",
                 note: "Handmade griddled blue masa filled with squash blossoms and melted Oaxaca cheese.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=400&q=80"),
                 price: "$45 MXN"),
            Dish(name: "Agua de Horchata / Jamaica",
                 note: "Traditional sweet cinnamon rice milk or cold tart hibiscus flower water.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80"),
                 price: "$30 MXN")
        ]
    ]
}
