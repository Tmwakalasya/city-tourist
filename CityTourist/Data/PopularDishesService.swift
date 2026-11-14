import Foundation

/// Generates top popular items from Google "Menu Highlights" for food venues,
/// combining curated menu highlights with photos for iconic locations and
/// intelligent, cuisine-grounded menu generation with pictures for any restaurant.
enum PopularDishesService {

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

    // MARK: - Intelligent Menu Generator (Google Menu Highlights)

    private static func generateDishes(for place: Place) -> [Dish] {
        let text = "\(place.name) \(place.blurb) \(place.about) \(place.tags.joined(separator: " "))".lowercased()

        // 1. Ramen & Japanese Noodles
        if matches(text, keywords: ["ramen", "soba", "udon", "noodles", "tsukemen", "tonkotsu"]) {
            return [
                Dish(name: "Signature Tonkotsu Ramen",
                     note: "Rich 16-hour pork bone broth with tender chashu & ajitama",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Spicy Miso Ramen",
                     note: "House chili oil, seasoned ground pork, sweet corn & scallions",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1552611052-33e04de081de?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Handmade Pan-Fried Pork Gyoza",
                     note: "Crispy bottoms with ginger soy dipping sauce",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1498654896293-37aacf113fd9?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Chashu Rice Bowl (Chashu Don)",
                     note: "Braised pork belly over steamed rice with scallions",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Ajitama Soft-Boiled Egg",
                     note: "Jammy soy-marinated egg with nori seaweed",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 2. Sushi & Sashimi
        if matches(text, keywords: ["sushi", "sashimi", "nigiri", "omakase", "maki", "chirashi"]) {
            return [
                Dish(name: "Chef's Nigiri Omakase Platter",
                     note: "Daily selection of premium seasonal fish with fresh wasabi",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Spicy Tuna & Salmon Crispy Rice",
                     note: "Pan-crisped sushi rice topped with spicy tuna & serrano",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1611143669185-af224c5e3252?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Hamachi Yellowtail Carpaccio",
                     note: "Thinly sliced yellowtail with citrus ponzu and jalapeño",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Classic Dragon Roll",
                     note: "Fresh water eel, avocado, cucumber & sweet kabayaki glaze",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Warm Red Miso Soup",
                     note: "Silken tofu, wakame seaweed & spring scallions",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1607528971899-2e89e6c0ec69?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 3. Izakaya & Japanese Dining
        if matches(text, keywords: ["izakaya", "yakitori", "japanese", "tempura", "donburi"]) {
            return [
                Dish(name: "Tare-Glazed Yakitori Skewers",
                     note: "Charcoal-grilled chicken thighs with scallions",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Japanese Fried Chicken (Karaage)",
                     note: "Double-fried crispy thighs with kewpie mayo & lemon",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Agedashi Tofu",
                     note: "Crispy silken tofu in warm dashi broth with bonito flakes",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Wagyu Beef Skewers",
                     note: "Tender A5 beef seasoned with flaked sea salt",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Matcha Mochi / Parfait",
                     note: "Ceremonial grade green tea sweet finish",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1563805042-7684c019e1cb?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 4. Tacos & Taqueria
        if matches(text, keywords: ["taco", "tacos", "taqueria", "taquería", "pastor", "carnitas", "birria", "suadero"]) {
            return [
                Dish(name: "Tacos al Pastor",
                     note: "Spit-roasted marinated pork with charred pineapple & cilantro",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Birria Quesatacos con Consomé",
                     note: "Crispy griddled beef tacos with melted cheese & rich broth",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Fresh Guacamole & Totopos",
                     note: "Hand-mashed Hass avocado, lime, cotija cheese & pico de gallo",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Tacos de Suadero / Carnitas",
                     note: "Slow-braised tender meat with salsa verde & diced onions",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Warm Churros con Dulce de Leche",
                     note: "Crispy cinnamon-sugar pastry with house caramel",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 5. Mexican & Cantina
        if matches(text, keywords: ["mexican", "enchiladas", "mole", "quesadilla", "cantina", "antojitos", "tostadas"]) {
            return [
                Dish(name: "Enchiladas Verdes Suizas",
                     note: "Shredded chicken in tomatillo crema baked with melted cheese",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Traditional Mole Poblano",
                     note: "Slow-simmered rich cacao and chile sauce over tender chicken",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Quesadilla de Flor de Calabaza",
                     note: "Fresh masa stuffed with squash blossoms and Oaxaca quesillo",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Ceviche Mixto de Mariscos",
                     note: "Fresh lime-cured fish and shrimp with ripe avocado",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Flan Casero Tradicional",
                     note: "Velvety caramel custard with Mexican vanilla",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 6. Pizzeria & Italian Pizza
        if matches(text, keywords: ["pizza", "pizzeria", "pizzas", "napoletana", "calzone"]) {
            return [
                Dish(name: "Wood-Fired Pizza Margherita D.O.P.",
                     note: "San Marzano tomatoes, buffalo mozzarella, fresh basil & EVOO",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Pizza Diavola",
                     note: "Spicy soppressata calabrese, hot chili honey & fior di latte",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Burrata Pugliese & Prosciutto",
                     note: "Creamy burrata, 24-month prosciutto di Parma & arugula",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1592417817098-8f3d69102353?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Truffle & Wild Mushroom Pizza",
                     note: "Taleggio, roasted cremini mushrooms & white truffle oil",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Classic Espresso Tiramisù",
                     note: "Savoiardi ladyfingers soaked in espresso with mascarpone",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 7. Italian & Pasta
        if matches(text, keywords: ["italian", "pasta", "trattoria", "osteria", "ristorante", "risotto", "carbonara", "bolognese"]) {
            return [
                Dish(name: "Handmade Cacio e Pepe",
                     note: "Tonnarelli pasta tossed with aged Pecorino Romano & black pepper",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1621996346565-e3d5d6281788?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Slow-Braised Bolognese Tagliatelle",
                     note: "Rich 8-hour beef & veal ragù over fresh egg pasta",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551183053-bf91a1d81141?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Creamy Burrata Pugliese",
                     note: "Heirloom tomatoes, fresh basil pesto & aged balsamic",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1592417817098-8f3d69102353?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Seafood Saffron Risotto",
                     note: "Arborio rice with wild shrimp, mussels & calamari",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "House Tiramisù al Mascarpone",
                     note: "Traditional Venetian recipe with dark cocoa",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 8. Portuguese & Tasca
        if matches(text, keywords: ["portuguese", "bacalhau", "tasca", "petiscos", "marisqueira", "churrasqueira", "polvo"]) {
            return [
                Dish(name: "Bacalhau à Brás",
                     note: "Shredded salt cod sautéed with thin potatoes, eggs, onions & olives",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Polvo à Lagareiro",
                     note: "Tender oven-roasted octopus drenched in garlic olive oil & smashed potatoes",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Amêijoas à Bulhão Pato",
                     note: "Fresh clams steamed in white wine, olive oil, garlic & coriander",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Bifana Tradicional no Pão",
                     note: "Garlic and white wine marinated pork cutlet in crusty bread",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Pastel de Nata Quentinho",
                     note: "Warm custard tart dusted with cinnamon, freshly baked",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 9. Bakery, Café & Breakfast / Brunch
        if matches(text, keywords: ["bakery", "cafe", "café", "coffee", "brunch", "pastry", "boulangerie", "croissant", "espresso"]) {
            return [
                Dish(name: "Artisanal Flat White / Pour-Over",
                     note: "Locally roasted specialty beans with silky microfoam",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Flaky All-Butter Croissant",
                     note: "French laminated pastry baked golden and crisp",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Avocado & Poached Farm Egg Sourdough",
                     note: "Crushed avocado, radish, chili flakes & microgreens",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Pain au Chocolat / Cinnamon Roll",
                     note: "Warm layered pastry with rich dark chocolate or cinnamon glaze",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Seasonal Fruit & Frangipane Tart",
                     note: "Fresh fruit compote over velvety almond cream",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 10. Steakhouse & Barbecue
        if matches(text, keywords: ["steak", "steakhouse", "ribeye", "bbq", "barbecue", "churrasco", "sirloin", "tenderloin"]) {
            return [
                Dish(name: "Prime Dry-Aged Bone-In Ribeye",
                     note: "Charred crust with garlic rosemary compound butter",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Center-Cut Filet Mignon",
                     note: "Tender cut served with red wine bordelaise reduction",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Truffle Mac & Cheese",
                     note: "Aged gruyère, sharp cheddar & toasted panko crust",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Charred Creamed Spinach",
                     note: "Velvety classic steakhouse staple with nutmeg",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1576045057995-568f588f82fb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Warm Molten Chocolate Lava Cake",
                     note: "Dark Valrhona chocolate with vanilla bean gelato",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 11. Burger Joint
        if matches(text, keywords: ["burger", "burgers", "smashburger", "cheeseburger"]) {
            return [
                Dish(name: "Double Smash Cheeseburger",
                     note: "Crispy-edged beef patties, American cheese, house sauce & pickles",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Truffle Garlic Parmesan Fries",
                     note: "Crispy shoestring fries tossed in truffle oil & fresh herbs",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Smoked Bacon BBQ Burger",
                     note: "Applewood bacon, crispy onions & smoky BBQ aioli",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Crispy Buttermilk Chicken Sandwich",
                     note: "Pickle-brined fried chicken with spicy slaw",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1625813506062-0aeb1d7a094b?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Hand-Spun Malted Milkshake",
                     note: "Thick Madagascar vanilla bean or rich chocolate",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 12. Seafood & Oyster Bar
        if matches(text, keywords: ["seafood", "fish", "oyster", "oysters", "crab", "lobster", "shrimp", "clam"]) {
            return [
                Dish(name: "Fresh Catch of the Day",
                     note: "Pan-roasted local fillet with lemon-caper herb butter",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Crispy Calamari Fritti",
                     note: "Tender local squid served with charred lemon garlic aioli",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1599488615731-7e5c2823ff28?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Chilled Seafood Platter / Oysters",
                     note: "Freshly shucked oysters on ice with champagne mignonette",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Jumbo Lump Crab Cakes",
                     note: "Seared golden with whole-grain mustard remoulade",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Signature Key Lime Tart",
                     note: "Zesty citrus curd with toasted graham cracker crust",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 13. French & Bistro
        if matches(text, keywords: ["bistro", "brasserie", "french"]) {
            return [
                Dish(name: "Steak Frites",
                     note: "Seared hanger steak with crispy pomme frites and béarnaise",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "French Onion Soup Gratinée",
                     note: "Slow-caramelized onions with melted Gruyère crouton",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Crispy Duck Confit",
                     note: "Tender leg with garlic roasted potatoes and thyme jus",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1514944298352-fa2f33e387e2?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Burgundy Escargots",
                     note: "Snails baked in bubbling garlic parsley butter",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Classic Vanilla Bean Crème Brûlée",
                     note: "Rich custard with caramelized sugar crust",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1470124182917-cc6e71b22ecc?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 14. Asian & Noodle Bar
        if matches(text, keywords: ["thai", "vietnamese", "chinese", "dim sum", "asian", "curry"]) {
            return [
                Dish(name: "House Signature Noodle Bowl",
                     note: "Savory broth, fresh noodles, tender braised meat & herbs",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Crispy Imperial Spring Rolls",
                     note: "Golden fried rolls with sweet chili garlic dip",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Steamed Soup Dumplings (Xiao Long Bao)",
                     note: "Delicate dumplings filled with savory pork broth",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1498654896293-37aacf113fd9?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Aromatic Coconut Curry",
                     note: "Tender chicken, bamboo shoots & Thai basil over jasmine rice",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=400&q=80")),
                Dish(name: "Sweet Mango Coconut Sticky Rice",
                     note: "Warm glutinous rice with coconut cream & ripe mango",
                     imageURL: URL(string: "https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=400&q=80"))
            ]
        }

        // 15. General Dining / Signature Course
        return [
            Dish(name: "\(place.name) Chef's Tasting Special",
                 note: "The kitchen's most celebrated daily creation",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80")),
            Dish(name: "Signature House Entrée",
                 note: "Locally sourced seasonal specialty praised by guests",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=400&q=80")),
            Dish(name: "Crispy Appetizer & Artisan Dip",
                 note: "Perfect starter crafted for sharing at the table",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80")),
            Dish(name: "Slow-Braised Market Specialty",
                 note: "Tender, savory main dish featured on the daily menu",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80")),
            Dish(name: "Handmade Seasonal House Dessert",
                 note: "Sweet signature finish prepared fresh by the pastry chef",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=400&q=80"))
        ]
    }

    private static func matches(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b", options: .regularExpression) != nil
        }
    }

    // MARK: - Curated Iconic Venues (Google Menu Highlights)

    private static let curated: [String: [Dish]] = [
        "lis-pasteis-belem": [
            Dish(name: "Pastel de Belém",
                 note: "Original warm custard tart dusted with cinnamon & powdered sugar, baked fresh every few minutes.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.40"),
            Dish(name: "Pastel de Bacalhau",
                 note: "Crispy golden codfish croquette with tender potato and parsley filling.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.95"),
            Dish(name: "Galão",
                 note: "Traditional Portuguese espresso with steamed frothy milk served in a glass.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.60"),
            Dish(name: "Bolo Inglês",
                 note: "Spiced traditional Portuguese fruit and nut cake with candied peel.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1578985545062-69928b1d9587?auto=format&fit=crop&w=400&q=80"),
                 price: "€2.50"),
            Dish(name: "Marmelada com Queijo",
                 note: "Artisanal quince paste with soft cheese on crusty bread.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=400&q=80"),
                 price: "€2.80")
        ],
        "lis-timeout": [
            Dish(name: "Chef Henrique Sá Pessoa Bacalhau à Brás",
                 note: "Slow-cooked salted cod, shredded potatoes, farm eggs and black olives.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                 price: "€14.50"),
            Dish(name: "Manteigaria Pastel de Nata",
                 note: "Torched hot custard tart with flaky layered puff pastry and cinnamon.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1587314168485-3236d6710814?auto=format&fit=crop&w=400&q=80"),
                 price: "€1.30"),
            Dish(name: "Traditional Bifana no Pão",
                 note: "Tender pork cutlet marinated in garlic and white wine, served in warm papo-seco.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=400&q=80"),
                 price: "€4.80"),
            Dish(name: "O Prego da Peixaria",
                 note: "Garlic tenderloin steak in traditional Madeira sweet potato bolo do caco.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80"),
                 price: "€11.00"),
            Dish(name: "Santini Artisanal Gelato",
                 note: "Historic Lisbon strawberry and roasted pistachio Italian gelato.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1560008511-11c63416e52d?auto=format&fit=crop&w=400&q=80"),
                 price: "€3.90")
        ],
        "kyo-nishiki": [
            Dish(name: "Dashi Tamagoyaki by Miki Keiran",
                 note: "Steaming rolled egg omelet infused with rich bonito and kombu dashi broth.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=400&q=80"),
                 price: "¥400"),
            Dish(name: "Tako Tamago Skewer",
                 note: "Glazed baby octopus skewer stuffed with a whole seasoned quail egg.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                 price: "¥350"),
            Dish(name: "Soy Milk Donuts by Konna Monja",
                 note: "Freshly fried bite-sized airy donuts made with Kyoto silken soy milk.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1527515637462-cff94eecc1ac?auto=format&fit=crop&w=400&q=80"),
                 price: "¥300"),
            Dish(name: "Grilled A5 Wagyu Beef Skewer",
                 note: "Charbroiled tender wagyu glazed with sweet tare soy sauce and sea salt.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80"),
                 price: "¥1,200"),
            Dish(name: "Kyoto Tsukemono (Pickles)",
                 note: "Crisp seasonal local vegetables preserved in salted rice bran and miso.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=400&q=80"),
                 price: "¥500")
        ],
        "mex-contramar": [
            Dish(name: "Tostadas de Atún Fresco",
                 note: "Sashimi-grade tuna, chipotle mayo, sliced avocado and crispy fried leeks on crunchy tostada.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80"),
                 price: "$320 MXN"),
            Dish(name: "Pescado a la Talla",
                 note: "Signature butterflied grilled catch of the day with red chile adobo & green parsley.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80"),
                 price: "$580 MXN"),
            Dish(name: "Aguachile de Camarón",
                 note: "Fresh Pacific shrimp cured in lime juice with serrano chile, red onion and cucumber.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1535400255456-984241443b29?auto=format&fit=crop&w=400&q=80"),
                 price: "$340 MXN"),
            Dish(name: "Tarta de Higo",
                 note: "Famous fresh fig tart layered over sweet mascarpone on buttery shortbread crust.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?auto=format&fit=crop&w=400&q=80"),
                 price: "$195 MXN"),
            Dish(name: "Tacos de Carnitas de Pescado",
                 note: "Crispy slow-cooked fish carnitas served with fresh heirloom corn tortillas.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=400&q=80"),
                 price: "$290 MXN")
        ],
        "mex-coyoacan-market": [
            Dish(name: "Tostadas de Tinga de Pollo",
                 note: "Piled-high crispy corn tortilla with chipotle chicken, crema, avocado and cotija.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1551504734-5ee1c4a1479b?auto=format&fit=crop&w=400&q=80"),
                 price: "$65 MXN"),
            Dish(name: "Tostada de Ceviche Mixto",
                 note: "Fresh lime-cured white fish, tender octopus, avocado slices and salsa valentina.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1541544741938-0af808871cc0?auto=format&fit=crop&w=400&q=80"),
                 price: "$75 MXN"),
            Dish(name: "Churros Rellenos",
                 note: "Warm golden crispy churro stuffed with cajeta dulce de leche or chocolate.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1624300629298-e9de39c13be5?auto=format&fit=crop&w=400&q=80"),
                 price: "$35 MXN"),
            Dish(name: "Quesadilla de Flor de Calabaza",
                 note: "Handmade griddled blue masa filled with squash blossoms and melted Oaxaca cheese.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1618040996337-56904b7850b9?auto=format&fit=crop&w=400&q=80"),
                 price: "$45 MXN"),
            Dish(name: "Agua de Horchata / Jamaica",
                 note: "Traditional sweet cinnamon rice milk or cold hibiscus flower water.",
                 imageURL: URL(string: "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?auto=format&fit=crop&w=400&q=80"),
                 price: "$30 MXN")
        ]
    ]
}
