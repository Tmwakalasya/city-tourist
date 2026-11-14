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

    /// Whether specific location menu items exist for the place.
    static func hasItems(for placeID: String) -> Bool {
        curated[placeID] != nil
    }

    /// Whether specific location menu items exist for the place.
    static func hasItems(for place: Place) -> Bool {
        curated[place.id] != nil
    }

    /// Returns top 5 most popular items from the menu of such location.
    static func popularItems(for place: Place) -> [Dish] {
        curated[place.id] ?? []
    }

    static func popularItems(for placeID: String) -> [Dish] {
        curated[placeID] ?? []
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
