import Foundation

/// Curated menu staples for hand-written venues, matched strictly by place ID.
enum PopularDishesService {

    struct Dish: Identifiable, Hashable {
        let name: String
        let note: String

        var id: String { name }
    }

    /// Whether hand-written menu recommendations exist for the place.
    static func hasItems(for placeID: String) -> Bool {
        curated[placeID] != nil
    }

    /// Returns top 5 most popular items for the given place, or an empty list if not hand-written.
    static func popularItems(for place: Place) -> [Dish] {
        popularItems(for: place.id)
    }

    static func popularItems(for placeID: String) -> [Dish] {
        curated[placeID] ?? []
    }

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
