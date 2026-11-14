import Foundation

/// Curated menu staples for well-known spots and smart cuisine-driven fallbacks
/// for restaurants so travellers immediately see what to order without video.
enum PopularDishesService {

    struct Dish: Identifiable, Hashable {
        let name: String
        let note: String

        var id: String { name }
    }

    /// Returns top 5 most popular items for the given place.
    static func popularItems(for place: Place) -> [Dish] {
        guard place.category == .food else { return [] }

        let name = place.name.lowercased()
        let tags = place.tags.map { $0.lowercased() }

        // 1. Venue-specific curated classics
        if name.contains("joe") && name.contains("crab") {
            return [
                Dish(name: "Florida Stone Crab Claws", note: "Chilled with signature mustard sauce"),
                Dish(name: "Key Lime Pie", note: "World-famous graham cracker crust"),
                Dish(name: "Fried Chicken", note: "Crispy skin, tender & seasoned to perfection"),
                Dish(name: "Hash Browns", note: "Crispy shredded potato pie, served golden"),
                Dish(name: "Creamed Spinach", note: "Rich, velvety classic steakhouse staple")
            ]
        }

        if name.contains("pastéis de belém") || name.contains("pasteis de belem") {
            return [
                Dish(name: "Pastel de Belém", note: "Original warm custard tart dusted with cinnamon"),
                Dish(name: "Galão", note: "Traditional Portuguese espresso with steamed milk"),
                Dish(name: "Pastel de Bacalhau", note: "Crispy codfish fritter with tender herb filling"),
                Dish(name: "Bolo Inglês", note: "Moist traditional spiced fruit and nut cake"),
                Dish(name: "Marmelada Caseira", note: "House-made quince paste on rustic bread")
            ]
        }

        if name.contains("time out") {
            return [
                Dish(name: "Chef Henrique Sá Pessoa Bacalhau", note: "Modern slow-cooked salted cod"),
                Dish(name: "Manteigaria Custard Tart", note: "Freshly torched warm pastel de nata"),
                Dish(name: "Traditional Bifana", note: "Garlic and white wine marinated pork cutlet"),
                Dish(name: "O Prego da Peixaria", note: "Garlic tenderloin steak in bolo do caco"),
                Dish(name: "Artisanal Santini Gelato", note: "Historic creamy strawberry & pistachio")
            ]
        }

        if name.contains("contramar") {
            return [
                Dish(name: "Pescado a la Talla", note: "Signature half-red chile, half-green parsley grilled fish"),
                Dish(name: "Tostadas de Atún Fresco", note: "Sashimi-grade tuna, chipotle mayo, avocado & fried leeks"),
                Dish(name: "Aguachile de Camarón", note: "Fresh Pacific shrimp in spicy lime, cucumber & serrano broth"),
                Dish(name: "Tacos de Escamoles", note: "Traditional buttery seasonal Mexican delicacy with epazote"),
                Dish(name: "Tarta de Higo", note: "Famous fresh fig tart layered over sweet mascarpone")
            ]
        }

        if name.contains("coyoacán") || name.contains("coyoacan") {
            return [
                Dish(name: "Tostadas de Tinga de Pollo", note: "Crispy griddled tortilla with shredded chipotle chicken"),
                Dish(name: "Tostada de Ceviche Mixto", note: "Fresh lime-marinated fish, octopus, and ripe avocado"),
                Dish(name: "Agua de Horchata / Jamaica", note: "Traditional sweet cinnamon rice milk or cold hibiscus"),
                Dish(name: "Quesadilla de Flor de Calabaza", note: "Fresh masa stuffed with squash blossoms and quesillo"),
                Dish(name: "Churros Rellenos", note: "Warm crispy churro filled with cajeta or chocolate")
            ]
        }

        if name.contains("nishiki") {
            return [
                Dish(name: "Dashi Tamagoyaki", note: "Steaming rolled egg omelet infused with savory dashi broth"),
                Dish(name: "Tako Tamago", note: "Baby octopus skewer stuffed with a tiny quail egg"),
                Dish(name: "Soy Milk Donuts", note: "Light, fluffy bite-sized donuts freshly fried"),
                Dish(name: "Grilled Wagyu Beef Skewer", note: "A5 tender beef glazed with sweet tare soy sauce"),
                Dish(name: "Fresh Kyoto Pickles (Tsukemono)", note: "Traditional crisp seasonal vegetables preserved in miso")
            ]
        }

        // 2. Cuisine heuristics based on name and tags
        if tags.contains(where: { $0.contains("sushi") || $0.contains("japanese") }) || name.contains("sushi") || name.contains("ramen") || name.contains("izakaya") {
            return [
                Dish(name: "Chef’s Omakase Nigiri", note: "Seasonal fresh market catch"),
                Dish(name: "Crispy Rice Spicy Tuna", note: "Truffle soy glaze & serrano pepper"),
                Dish(name: "Signature Tonkotsu Ramen", note: "Rich 18-hour slow simmered broth & chashu"),
                Dish(name: "Yellowtail Jalapeño", note: "Thinly sliced hamachi with yuzu ponzu"),
                Dish(name: "Matcha Lava Cake", note: "Warm molten green tea center with gelato")
            ]
        }

        if tags.contains(where: { $0.contains("cuban") || $0.contains("caribbean") }) || name.contains("cuban") || name.contains("habana") || name.contains("versailles") {
            return [
                Dish(name: "Classic Cuban Sandwich", note: "Roast pork, ham, swiss, mustard & pickles on pressed bread"),
                Dish(name: "Ropa Vieja", note: "Slow-shredded beef in sweet pepper & tomato sofrito"),
                Dish(name: "Empanadas Mixtas", note: "Flaky turnovers with seasoned beef & melted cheese"),
                Dish(name: "Maduros & Tostones", note: "Caramelized plantains with garlic mojo dip"),
                Dish(name: "Cafecito / Cortadito", note: "Whipped sweetened espresso with steamed milk")
            ]
        }

        if tags.contains(where: { $0.contains("mexican") || $0.contains("taco") }) || name.contains("taqueria") || name.contains("taco") || name.contains("cantina") {
            return [
                Dish(name: "Tacos al Pastor", note: "Spit-roasted marinated pork with charred pineapple"),
                Dish(name: "House Guacamole & Chips", note: "Freshly mashed avocado, lime, cilantro & cotija"),
                Dish(name: "Birria Quesatacos", note: "Crispy griddled beef tacos served with rich consommé"),
                Dish(name: "Street Corn (Elote)", note: "Grilled sweet corn with chipotle crema and cotija"),
                Dish(name: "Churros con Dulce de Leche", note: "Cinnamon-dusted pastry with warm caramel")
            ]
        }

        if tags.contains(where: { $0.contains("seafood") || $0.contains("fish") }) || name.contains("seafood") || name.contains("fish") || name.contains("crab") || name.contains("lobster") {
            return [
                Dish(name: "Catch of the Day", note: "Pan-roasted local fillet with lemon herb butter"),
                Dish(name: "Crispy Calamari", note: "Tender fried squid with spicy remoulade"),
                Dish(name: "Seafood Risotto / Paella", note: "Shrimp, mussels & calamari in saffron broth"),
                Dish(name: "Crab Cakes", note: "Jumbo lump crab meat with whole-grain mustard sauce"),
                Dish(name: "Key Lime Pie", note: "Fresh lime custard with toasted graham crust")
            ]
        }

        if tags.contains(where: { $0.contains("italian") || $0.contains("pasta") || $0.contains("pizza") }) || name.contains("trattoria") || name.contains("pasta") || name.contains("pizza") || name.contains("osteria") {
            return [
                Dish(name: "Handmade Cacio e Pepe / Carbonara", note: "Fresh extruded pasta with aged pecorino"),
                Dish(name: "Wood-Fired Margherita Pizza", note: "San Marzano tomatoes, buffalo mozzarella & basil"),
                Dish(name: "Burrata Pugliese", note: "Creamy heirloom tomato salad with basil pesto"),
                Dish(name: "Slow-Braised Bolognese Tagliatelle", note: "Rich veal and beef ragù over egg pasta"),
                Dish(name: "Classic Tiramisu", note: "Espresso-soaked ladyfingers with mascarpone cream")
            ]
        }

        if tags.contains(where: { $0.contains("steak") || $0.contains("steakhouse") }) || name.contains("steak") || name.contains("grill") || name.contains("prime") {
            return [
                Dish(name: "Dry-Aged Bone-In Ribeye", note: "Charred crust, rosemary compound butter"),
                Dish(name: "Center-Cut Filet Mignon", note: "Ultra-tender cut with red wine demi-glace"),
                Dish(name: "Truffle Mac & Cheese", note: "Aged gruyère, sharp cheddar & black truffle breadcrumbs"),
                Dish(name: "Jumbo Shrimp Cocktail", note: "Chilled colossal shrimp with tangy cocktail sauce"),
                Dish(name: "Warm Chocolate Fondant", note: "Molten dark chocolate with vanilla bean gelato")
            ]
        }

        if tags.contains(where: { $0.contains("bakery") || $0.contains("cafe") || $0.contains("coffee") }) || name.contains("bakery") || name.contains("café") || name.contains("cafe") {
            return [
                Dish(name: "Flaky Butter Croissant", note: "Freshly baked laminated dough with golden layers"),
                Dish(name: "Signature Cold Brew / Flat White", note: "Single-origin roast with velvety microfoam"),
                Dish(name: "Avocado Sourdough Toast", note: "Poached farm egg, pickled shallots & chili flakes"),
                Dish(name: "Pain au Chocolat", note: "Valrhona chocolate baton inside crisp puff pastry"),
                Dish(name: "Artisanal Seasonal Tart", note: "Fruit compote over almond frangipane cream")
            ]
        }

        // 3. High-quality default bistro recommendations
        return [
            Dish(name: "House Signature Special", note: "The kitchen’s most ordered daily favourite"),
            Dish(name: "Chef’s Seasonal Tasting Entrée", note: "Crafted with fresh regional produce and local ingredients"),
            Dish(name: "Crispy Starter & House Dip", note: "Perfect for sharing before the main courses"),
            Dish(name: "Slow-Cooked Meat or Market Fish", note: "Tender, savory main dish praised in customer reviews"),
            Dish(name: "Signature House Dessert", note: "Handmade sweet finish to complete the dining experience")
        ]
    }
}
