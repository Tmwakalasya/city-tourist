import Foundation

/// Generates top popular items from the menu of food venues, combining curated staples
/// for iconic locations with intelligent, cuisine-grounded menu generation for any restaurant.
enum PopularDishesService {

    struct Dish: Identifiable, Hashable {
        let name: String
        let note: String

        var id: String { name }
    }

    /// Whether menu recommendations can be generated or exist for the place.
    @MainActor
    static func hasItems(for placeID: String) -> Bool {
        if curated[placeID] != nil { return true }
        if let place = PlaceDirectory.place(id: placeID) {
            return place.category == .food
        }
        return false
    }

    /// Whether menu recommendations can be generated or exist for the place.
    static func hasItems(for place: Place) -> Bool {
        place.category == .food || curated[place.id] != nil
    }

    /// Returns top 5 most popular items from the menu of such location.
    static func popularItems(for place: Place) -> [Dish] {
        if let items = curated[place.id], !items.isEmpty {
            return items
        }
        guard place.category == .food else { return [] }
        return generateDishes(for: place)
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

    // MARK: - Intelligent Menu Generator

    private static func generateDishes(for place: Place) -> [Dish] {
        let text = "\(place.name) \(place.blurb) \(place.about) \(place.tags.joined(separator: " "))".lowercased()

        // 1. Ramen & Japanese Noodles
        if matches(text, keywords: ["ramen", "soba", "udon", "noodles", "tsukemen", "tonkotsu"]) {
            return [
                Dish(name: "Signature Tonkotsu Ramen", note: "Rich 16-hour pork bone broth with tender chashu & ajitama"),
                Dish(name: "Spicy Miso Ramen", note: "House chili oil, seasoned ground pork, sweet corn & scallions"),
                Dish(name: "Handmade Pan-Fried Pork Gyoza", note: "Crispy bottoms with ginger soy dipping sauce"),
                Dish(name: "Chashu Rice Bowl (Chashu Don)", note: "Braised pork belly over steamed rice with scallions"),
                Dish(name: "Ajitama Soft-Boiled Egg", note: "Jammy soy-marinated egg with nori seaweed")
            ]
        }

        // 2. Sushi & Sashimi
        if matches(text, keywords: ["sushi", "sashimi", "nigiri", "omakase", "maki", "chirashi"]) {
            return [
                Dish(name: "Chef's Nigiri Omakase Platter", note: "Daily selection of premium seasonal fish with fresh wasabi"),
                Dish(name: "Spicy Tuna & Salmon Crispy Rice", note: "Pan-crisped sushi rice topped with spicy tuna & serrano"),
                Dish(name: "Hamachi Yellowtail Carpaccio", note: "Thinly sliced yellowtail with citrus ponzu and jalapeño"),
                Dish(name: "Classic Dragon Roll", note: "Fresh water eel, avocado, cucumber & sweet kabayaki glaze"),
                Dish(name: "Warm Red Miso Soup", note: "Silken tofu, wakame seaweed & spring scallions")
            ]
        }

        // 3. Izakaya & Japanese Dining
        if matches(text, keywords: ["izakaya", "yakitori", "japanese", "tempura", "donburi"]) {
            return [
                Dish(name: "Tare-Glazed Yakitori Skewers", note: "Charcoal-grilled chicken thighs with scallions"),
                Dish(name: "Japanese Fried Chicken (Karaage)", note: "Double-fried crispy thighs with kewpie mayo & lemon"),
                Dish(name: "Agedashi Tofu", note: "Crispy silken tofu in warm dashi broth with bonito flakes"),
                Dish(name: "Wagyu Beef Skewers", note: "Tender A5 beef seasoned with flaked sea salt"),
                Dish(name: "Matcha Mochi / Parfait", note: "Ceremonial grade green tea sweet finish")
            ]
        }

        // 4. Tacos & Taqueria
        if matches(text, keywords: ["taco", "tacos", "taqueria", "taquería", "pastor", "carnitas", "birria", "suadero"]) {
            return [
                Dish(name: "Tacos al Pastor", note: "Spit-roasted marinated pork with charred pineapple & cilantro"),
                Dish(name: "Birria Quesatacos con Consomé", note: "Crispy griddled beef tacos with melted cheese & rich broth"),
                Dish(name: "Fresh Guacamole & Totopos", note: "Hand-mashed Hass avocado, lime, cotija cheese & pico de gallo"),
                Dish(name: "Tacos de Suadero / Carnitas", note: "Slow-braised tender meat with salsa verde & diced onions"),
                Dish(name: "Warm Churros con Dulce de Leche", note: "Crispy cinnamon-sugar pastry with house caramel")
            ]
        }

        // 5. Mexican & Cantina
        if matches(text, keywords: ["mexican", "enchiladas", "mole", "quesadilla", "cantina", "antojitos", "tostadas"]) {
            return [
                Dish(name: "Enchiladas Verdes Suizas", note: "Shredded chicken in tomatillo crema baked with melted cheese"),
                Dish(name: "Traditional Mole Poblano", note: "Slow-simmered rich cacao and chile sauce over tender chicken"),
                Dish(name: "Quesadilla de Flor de Calabaza", note: "Fresh masa stuffed with squash blossoms and Oaxaca quesillo"),
                Dish(name: "Ceviche Mixto de Mariscos", note: "Fresh lime-cured fish and shrimp with ripe avocado"),
                Dish(name: "Flan Casero Tradicional", note: "Velvety caramel custard with Mexican vanilla")
            ]
        }

        // 6. Pizzeria & Italian Pizza
        if matches(text, keywords: ["pizza", "pizzeria", "pizzas", "napoletana", "calzone"]) {
            return [
                Dish(name: "Wood-Fired Pizza Margherita D.O.P.", note: "San Marzano tomatoes, buffalo mozzarella, fresh basil & EVOO"),
                Dish(name: "Pizza Diavola", note: "Spicy soppressata calabrese, hot chili honey & fior di latte"),
                Dish(name: "Burrata Pugliese & Prosciutto", note: "Creamy burrata, 24-month prosciutto di Parma & arugula"),
                Dish(name: "Truffle & Wild Mushroom Pizza", note: "Taleggio, roasted cremini mushrooms & white truffle oil"),
                Dish(name: "Classic Espresso Tiramisù", note: "Savoiardi ladyfingers soaked in espresso with mascarpone")
            ]
        }

        // 7. Italian & Pasta
        if matches(text, keywords: ["italian", "pasta", "trattoria", "osteria", "ristorante", "risotto", "carbonara", "bolognese"]) {
            return [
                Dish(name: "Handmade Cacio e Pepe", note: "Tonnarelli pasta tossed with aged Pecorino Romano & black pepper"),
                Dish(name: "Slow-Braised Bolognese Tagliatelle", note: "Rich 8-hour beef & veal ragù over fresh egg pasta"),
                Dish(name: "Creamy Burrata Pugliese", note: "Heirloom tomatoes, fresh basil pesto & aged balsamic"),
                Dish(name: "Seafood Saffron Risotto", note: "Arborio rice with wild shrimp, mussels & calamari"),
                Dish(name: "House Tiramisù al Mascarpone", note: "Traditional Venetian recipe with dark cocoa")
            ]
        }

        // 8. Portuguese & Tasca
        if matches(text, keywords: ["portuguese", "bacalhau", "tasca", "petiscos", "marisqueira", "churrasqueira", "polvo"]) {
            return [
                Dish(name: "Bacalhau à Brás", note: "Shredded salt cod sautéed with thin potatoes, eggs, onions & olives"),
                Dish(name: "Polvo à Lagareiro", note: "Tender oven-roasted octopus drenched in garlic olive oil & smashed potatoes"),
                Dish(name: "Amêijoas à Bulhão Pato", note: "Fresh clams steamed in white wine, olive oil, garlic & coriander"),
                Dish(name: "Bifana Tradicional no Pão", note: "Garlic and white wine marinated pork cutlet in crusty bread"),
                Dish(name: "Pastel de Nata Quentinho", note: "Warm custard tart dusted with cinnamon, freshly baked")
            ]
        }

        // 9. Bakery, Café & Breakfast / Brunch
        if matches(text, keywords: ["bakery", "cafe", "café", "coffee", "brunch", "pastry", "boulangerie", "croissant", "espresso"]) {
            return [
                Dish(name: "Artisanal Flat White / Pour-Over", note: "Locally roasted specialty beans with silky microfoam"),
                Dish(name: "Flaky All-Butter Croissant", note: "French laminated pastry baked golden and crisp"),
                Dish(name: "Avocado & Poached Farm Egg Sourdough", note: "Crushed avocado, radish, chili flakes & microgreens"),
                Dish(name: "Pain au Chocolat / Cinnamon Roll", note: "Warm layered pastry with rich dark chocolate or cinnamon glaze"),
                Dish(name: "Seasonal Fruit & Frangipane Tart", note: "Fresh fruit compote over velvety almond cream")
            ]
        }

        // 10. Steakhouse & Barbecue
        if matches(text, keywords: ["steak", "steakhouse", "ribeye", "bbq", "barbecue", "churrasco", "sirloin", "tenderloin"]) {
            return [
                Dish(name: "Prime Dry-Aged Bone-In Ribeye", note: "Charred crust with garlic rosemary compound butter"),
                Dish(name: "Center-Cut Filet Mignon", note: "Tender cut served with red wine bordelaise reduction"),
                Dish(name: "Truffle Mac & Cheese", note: "Aged gruyère, sharp cheddar & toasted panko crust"),
                Dish(name: "Charred Creamed Spinach", note: "Velvety classic steakhouse staple with nutmeg"),
                Dish(name: "Warm Molten Chocolate Lava Cake", note: "Dark Valrhona chocolate with vanilla bean gelato")
            ]
        }

        // 11. Burger Joint
        if matches(text, keywords: ["burger", "burgers", "smashburger", "cheeseburger"]) {
            return [
                Dish(name: "Double Smash Cheeseburger", note: "Crispy-edged beef patties, American cheese, house sauce & pickles"),
                Dish(name: "Truffle Garlic Parmesan Fries", note: "Crispy shoestring fries tossed in truffle oil & fresh herbs"),
                Dish(name: "Smoked Bacon BBQ Burger", note: "Applewood bacon, crispy onions & smoky BBQ aioli"),
                Dish(name: "Crispy Buttermilk Chicken Sandwich", note: "Pickle-brined fried chicken with spicy slaw"),
                Dish(name: "Hand-Spun Malted Milkshake", note: "Thick Madagascar vanilla bean or rich chocolate")
            ]
        }

        // 12. Seafood & Oyster Bar
        if matches(text, keywords: ["seafood", "fish", "oyster", "oysters", "crab", "lobster", "shrimp", "clam"]) {
            return [
                Dish(name: "Fresh Catch of the Day", note: "Pan-roasted local fillet with lemon-caper herb butter"),
                Dish(name: "Crispy Calamari Fritti", note: "Tender local squid served with charred lemon garlic aioli"),
                Dish(name: "Chilled Seafood Platter / Oysters", note: "Freshly shucked oysters on ice with champagne mignonette"),
                Dish(name: "Jumbo Lump Crab Cakes", note: "Seared golden with whole-grain mustard remoulade"),
                Dish(name: "Signature Key Lime Tart", note: "Zesty citrus curd with toasted graham cracker crust")
            ]
        }

        // 13. French & Bistro
        if matches(text, keywords: ["bistro", "brasserie", "french"]) {
            return [
                Dish(name: "Steak Frites", note: "Seared hanger steak with crispy pomme frites and béarnaise"),
                Dish(name: "French Onion Soup Gratinée", note: "Slow-caramelized onions with melted Gruyère crouton"),
                Dish(name: "Crispy Duck Confit", note: "Tender leg with garlic roasted potatoes and thyme jus"),
                Dish(name: "Burgundy Escargots", note: "Snails baked in bubbling garlic parsley butter"),
                Dish(name: "Classic Vanilla Bean Crème Brûlée", note: "Rich custard with caramelized sugar crust")
            ]
        }

        // 14. Asian & Noodle Bar
        if matches(text, keywords: ["thai", "vietnamese", "chinese", "dim sum", "asian", "curry"]) {
            return [
                Dish(name: "House Signature Noodle Bowl", note: "Savory broth, fresh noodles, tender braised meat & herbs"),
                Dish(name: "Crispy Imperial Spring Rolls", note: "Golden fried rolls with sweet chili garlic dip"),
                Dish(name: "Steamed Soup Dumplings (Xiao Long Bao)", note: "Delicate dumplings filled with savory pork broth"),
                Dish(name: "Aromatic Coconut Curry", note: "Tender chicken, bamboo shoots & Thai basil over jasmine rice"),
                Dish(name: "Sweet Mango Coconut Sticky Rice", note: "Warm glutinous rice with coconut cream & ripe mango")
            ]
        }

        // 15. General Dining / Signature Course
        return [
            Dish(name: "\(place.name) Chef's Tasting Special", note: "The kitchen's most celebrated daily creation"),
            Dish(name: "Signature House Entrée", note: "Locally sourced seasonal specialty praised by guests"),
            Dish(name: "Crispy Appetizer & Artisan Dip", note: "Perfect starter crafted for sharing at the table"),
            Dish(name: "Slow-Braised Market Specialty", note: "Tender, savory main dish featured on the daily menu"),
            Dish(name: "Handmade Seasonal House Dessert", note: "Sweet signature finish prepared fresh by the pastry chef")
        ]
    }

    private static func matches(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b", options: .regularExpression) != nil
        }
    }

    // MARK: - Curated Iconic Venues

    private static let curated: [String: [Dish]] = [
        "lis-pasteis-belem": [
            Dish(name: "Pastel de Belém", note: "Original warm custard tart dusted with cinnamon"),
            Dish(name: "Galão", note: "Traditional Portuguese espresso with steamed milk"),
            Dish(name: "Pastel de Bacalhau", note: "Crispy codfish fritter with tender herb filling"),
            Dish(name: "Bolo Inglês", note: "Moist traditional spiced fruit and nut cake"),
            Dish(name: "Marmelada Caseira", note: "House-made quince paste on rustic bread")
        ],
        "lis-timeout": [
            Dish(name: "Chef Henrique Sá Pessoa Bacalhau", note: "Modern slow-cooked salted cod"),
            Dish(name: "Manteigaria Custard Tart", note: "Freshly torched warm pastel de nata"),
            Dish(name: "Traditional Bifana", note: "Garlic and white wine marinated pork cutlet"),
            Dish(name: "O Prego da Peixaria", note: "Garlic tenderloin steak in bolo do caco"),
            Dish(name: "Artisanal Santini Gelato", note: "Historic creamy strawberry & pistachio")
        ],
        "kyo-nishiki": [
            Dish(name: "Dashi Tamagoyaki", note: "Steaming rolled egg omelet infused with savory dashi broth"),
            Dish(name: "Tako Tamago", note: "Baby octopus skewer stuffed with a tiny quail egg"),
            Dish(name: "Soy Milk Donuts", note: "Light, fluffy bite-sized donuts freshly fried"),
            Dish(name: "Grilled Wagyu Beef Skewer", note: "A5 tender beef glazed with sweet tare soy sauce"),
            Dish(name: "Fresh Kyoto Pickles (Tsukemono)", note: "Traditional crisp seasonal vegetables preserved in miso")
        ],
        "mex-contramar": [
            Dish(name: "Pescado a la Talla", note: "Signature half-red chile, half-green parsley grilled fish"),
            Dish(name: "Tostadas de Atún Fresco", note: "Sashimi-grade tuna, chipotle mayo, avocado & fried leeks"),
            Dish(name: "Aguachile de Camarón", note: "Fresh Pacific shrimp in spicy lime, cucumber & serrano broth"),
            Dish(name: "Tacos de Escamoles", note: "Traditional buttery seasonal Mexican delicacy with epazote"),
            Dish(name: "Tarta de Higo", note: "Famous fresh fig tart layered over sweet mascarpone")
        ],
        "mex-coyoacan-market": [
            Dish(name: "Tostadas de Tinga de Pollo", note: "Crispy griddled tortilla with shredded chipotle chicken"),
            Dish(name: "Tostada de Ceviche Mixto", note: "Fresh lime-marinated fish, octopus, and ripe avocado"),
            Dish(name: "Agua de Horchata / Jamaica", note: "Traditional sweet cinnamon rice milk or cold hibiscus"),
            Dish(name: "Quesadilla de Flor de Calabaza", note: "Fresh masa stuffed with squash blossoms and quesillo"),
            Dish(name: "Churros Rellenos", note: "Warm crispy churro filled with cajeta or chocolate")
        ]
    ]
}
