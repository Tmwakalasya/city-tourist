import Foundation

/// Curated practical tips and tricks summarized from traveller forums, guidebooks,
/// and local visitor insights for locations so travellers get actionable advice without video.
enum PlaceTipsService {

    struct TipItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let summary: String
        let iconName: String
    }

    /// Provides curated, summarized tips for the given place.
    static func tips(for place: Place) -> [TipItem] {
        let name = place.name.lowercased()

        // 1. Lisbon Iconic Venues
        if name.contains("belém tower") || name.contains("belem tower") {
            return [
                TipItem(
                    title: "Buy Timed-Entry Tickets Online",
                    summary: "The on-site ticket queue frequently exceeds 45 minutes. Pre-booking an official time-slot voucher lets you bypass the ticket booth line completely.",
                    iconName: "ticket.fill"
                ),
                TipItem(
                    title: "Arrive Right at Opening (10:00 AM)",
                    summary: "The spiral staircase leading to the upper battlements is narrow and one-way with automated stoplights. Early arrivals experience virtually zero bottlenecks.",
                    iconName: "clock.fill"
                ),
                TipItem(
                    title: "Sunset from the Riverbank",
                    summary: "Photographers agree the exterior view from the waterfront promenade during golden hour often eclipses the interior view, and it's completely free.",
                    iconName: "camera.fill"
                ),
                TipItem(
                    title: "Pair with Jerónimos Monastery",
                    summary: "It's only a 12-minute scenic walk through Praça do Império. Purchase a combined ticket if you plan to visit both on the same day.",
                    iconName: "map.fill"
                )
            ]
        }

        if name.contains("jerónimos") || name.contains("jeronimos") {
            return [
                TipItem(
                    title: "The Church Nave is Free",
                    summary: "The Church of Santa Maria (where Vasco da Gama's tomb rests) has free admission. Paid tickets are only needed for the decorative cloister.",
                    iconName: "building.columns.fill"
                ),
                TipItem(
                    title: "Avoid the Midday Tour Bus Rush",
                    summary: "Large tour groups arrive heavily between 11:30 AM and 2:30 PM. Booking the earliest morning or late afternoon slot ensures quiet cloister photos.",
                    iconName: "sun.max.fill"
                ),
                TipItem(
                    title: "Dress Appropriately",
                    summary: "As an active religious sanctuary, shoulders and knees should be covered when entering both the church and the cloister.",
                    iconName: "tshirt.fill"
                ),
                TipItem(
                    title: "Pastéis de Belém is 3 Minutes Away",
                    summary: "The original 1837 bakery is just down the block. Walk into the sprawling rear dining rooms for quick table service rather than the takeaway queue.",
                    iconName: "fork.knife"
                )
            ]
        }

        if name.contains("pastéis de belém") || name.contains("pasteis de belem") {
            return [
                TipItem(
                    title: "Bypass the Takeaway Queue",
                    summary: "The takeaway line out front looks daunting, but walking straight inside into the historic tiled salon rooms gives you prompt table service with zero wait.",
                    iconName: "arrow.right.circle.fill"
                ),
                TipItem(
                    title: "Eat Warm with Cinnamon & Sugar",
                    summary: "Shakers of powdered sugar and cinnamon are on every table. Dust both generously over your warm custard tart as Lisbon locals do.",
                    iconName: "sparkles"
                ),
                TipItem(
                    title: "Order a 'Bica' or 'Galão'",
                    summary: "Pair your pastry with a 'bica' (strong Portuguese espresso) or 'galão' (steamed milk with espresso in a tall glass).",
                    iconName: "cup.and.saucer.fill"
                )
            ]
        }

        if name.contains("tram 28") {
            return [
                TipItem(
                    title: "Board at Martim Moniz Terminal",
                    summary: "To get a guaranteed window seat, board at Martim Moniz square early in the morning (before 8:30 AM) where the tram line begins.",
                    iconName: "tram.fill"
                ),
                TipItem(
                    title: "Watch Belongings on Crowded Turns",
                    summary: "Tram 28 is famous among pickpockets due to tight packed aisles. Keep backpacks in front and phones zipped away.",
                    iconName: "shield.lefthalf.filled"
                ),
                TipItem(
                    title: "Quiet Alternative: Tram 12",
                    summary: "If line 28 has a long queue, hop on Tram 12. It covers the scenic Alfama and Castelo loop with far smaller tourist crowds.",
                    iconName: "arrow.triangle.branch"
                )
            ]
        }

        if name.contains("castelo de são jorge") || name.contains("castelo") || name.contains("sao jorge") {
            return [
                TipItem(
                    title: "Use the Free Baixa Public Elevators",
                    summary: "Avoid the strenuous uphill climb by taking the free Elevador do Castelo from Rua dos Fanqueiros up to the castle gates in minutes.",
                    iconName: "arrow.up.circle.fill"
                ),
                TipItem(
                    title: "Pre-Purchase Mobile Tickets",
                    summary: "The ticket booth at the castle archway gets congested. Buy digital passes on your phone to scan directly at the turnstiles.",
                    iconName: "iphone"
                ),
                TipItem(
                    title: "Best Panoramic Terrace View",
                    summary: "The ancient pine-shaded battlements offer the highest central vista over Baixa, the Tagus estuary, and the 25 de Abril suspension bridge.",
                    iconName: "mountain.2.fill"
                )
            ]
        }

        if name.contains("alfama") {
            return [
                TipItem(
                    title: "Get Intentionally Lost in the Alleys",
                    summary: "Alfama is Lisbon's oldest quarter that survived the 1755 earthquake. Put your maps away and wander the stairways and tile-lined alleys.",
                    iconName: "map.fill"
                ),
                TipItem(
                    title: "Doorstep Ginjinha Liquors",
                    summary: "Local residents sell traditional cherry liqueur for €1 right from their front windows, often served in miniature edible chocolate cups.",
                    iconName: "wineglass.fill"
                ),
                TipItem(
                    title: "Late Afternoon Fado Melodies",
                    summary: "Stroll between 5:00 and 7:00 PM to hear acoustic 12-string Portuguese guitars and singers warming up inside cozy family taverns ('tascas').",
                    iconName: "guitars.fill"
                )
            ]
        }

        if name.contains("senhora do monte") || name.contains("miradouro") {
            return [
                TipItem(
                    title: "Highest Natural Viewpoint in Lisbon",
                    summary: "Located above Graça, this pine-shaded belvedere gives an unobstructed 360-degree panorama of the entire city, castle, and river.",
                    iconName: "mountain.2.fill"
                ),
                TipItem(
                    title: "Bring a Windbreaker at Sunset",
                    summary: "Atlantic breezes pick up considerably after the sun drops. Pack a light sweater or wind layer for dusk viewing.",
                    iconName: "wind"
                ),
                TipItem(
                    title: "Tuk-Tuk Coffee & Cold Beer",
                    summary: "Parked tuk-tuks and small kiosk vans around the chapel square sell affordable espresso and chilled Super Bock while you watch the sunset.",
                    iconName: "cup.and.saucer.fill"
                )
            ]
        }

        if name.contains("time out market") || name.contains("mercado da ribeira") {
            return [
                TipItem(
                    title: "Secure Seats Before Ordering",
                    summary: "During peak lunch (1:00-3:00 PM) and dinner (8:00-10:00 PM), communal tables fill instantly. Have someone hold seats before queuing at food stalls.",
                    iconName: "person.2.fill"
                ),
                TipItem(
                    title: "Michelin-Star Dishes on a Budget",
                    summary: "Stalls by Chef Henrique Sá Pessoa and Alexandre Silva offer high-end culinary concepts at street-market price points.",
                    iconName: "star.fill"
                ),
                TipItem(
                    title: "Upstairs Mezzanine for Quieter Seating",
                    summary: "If the central ground floor is crowded and noisy, head up to the perimeter mezzanine deck for additional tables and cocktail service.",
                    iconName: "arrow.up.right"
                )
            ]
        }

        if name.contains("azulejo") || name.contains("tile museum") {
            return [
                TipItem(
                    title: "Don't Miss the 23-Meter Panorama",
                    summary: "Head to the top floor to admire the breathtaking 1738 blue-and-white tile panorama depicting Lisbon before the great earthquake.",
                    iconName: "photo.artframe"
                ),
                TipItem(
                    title: "Visit the Convent Garden Café",
                    summary: "The museum’s courtyard cafeteria is situated inside the original Madre de Deus convent cloister, lined with century-old porcelain panels.",
                    iconName: "cup.and.saucer.fill"
                ),
                TipItem(
                    title: "Take Bus 759 from Baixa",
                    summary: "The museum is slightly east of the tourist center. Bus 759 from Praça do Comércio drops you right outside the gates in 12 minutes.",
                    iconName: "bus.fill"
                )
            ]
        }

        if name.contains("lx factory") {
            return [
                TipItem(
                    title: "Visit Ler Devagar Bookstore",
                    summary: "One of the most photogenic bookshops in Europe, built inside an old 19th-century printing factory with soaring printing presses and suspended bicycle art.",
                    iconName: "book.fill"
                ),
                TipItem(
                    title: "Sunday Flea Market",
                    summary: "Visit on Sunday mornings when local artisans, vintage collectors, and vinyl record traders set up stalls along the main cobbled corridor.",
                    iconName: "bag.fill"
                ),
                TipItem(
                    title: "Rooftop Views at Rio Maravilha",
                    summary: "Take the industrial lift up to the top floor for sunset cocktails right beneath the massive red pillars of the 25 de Abril bridge.",
                    iconName: "sun.horizon.fill"
                )
            ]
        }

        if name.contains("comércio") || name.contains("comercio") {
            return [
                TipItem(
                    title: "Climb the Rua Augusta Arch",
                    summary: "A small elevator inside the monumental arch takes you to the top balcony for rare symmetrical views looking straight down Rua Augusta to the hills.",
                    iconName: "arrow.up.square.fill"
                ),
                TipItem(
                    title: "Cais das Colunas Marble Steps",
                    summary: "Walk to the southern river edge where marble columns rise directly out of the water; historically, dignitaries and kings stepped ashore here.",
                    iconName: "water.waves"
                )
            ]
        }

        if name.contains("pensão amor") || name.contains("pensao amor") {
            return [
                TipItem(
                    title: "Arrive Before 10:30 PM",
                    summary: "A landmark in Pink Street (Cais do Sodré). It gets tightly packed after 11 PM on weekends with a line forming on Rua do Alecrim.",
                    iconName: "clock.fill"
                ),
                TipItem(
                    title: "Explore the Hidden Themed Rooms",
                    summary: "Wander past the main chandelier bar into the velvet-lined cabaret room, the erotic library, and the fortune teller’s nook.",
                    iconName: "door.left.hand.open"
                )
            ]
        }

        // 2. Kyoto Iconic Venues
        if name.contains("fushimi inari") {
            return [
                TipItem(
                    title: "Hike Past the Yotsutsuji Intersection",
                    summary: "Over 80% of crowds turn around at the first viewpoint. Continue climbing the upper summit loop for quiet, atmospheric torii tunnels.",
                    iconName: "mountain.2.fill"
                ),
                TipItem(
                    title: "Open 24/7 — Visit at Sunrise or Night",
                    summary: "The shrine grounds never close. Arriving before 7:30 AM or visiting under atmospheric lantern light after dusk guarantees crowd-free exploration.",
                    iconName: "moon.stars.fill"
                ),
                TipItem(
                    title: "Carry 100-Yen Coins for Vending Machines",
                    summary: "Mountain rest stops only accept coin cash for cold green tea and water as you hike up Mount Inari.",
                    iconName: "yensign.circle.fill"
                )
            ]
        }

        if name.contains("kinkaku-ji") || name.contains("kinkakuji") || name.contains("golden pavilion") {
            return [
                TipItem(
                    title: "Best Mid-Morning or Afternoon Sun",
                    summary: "The pavilion shines brightest when sunlight directly illuminates the top two floors covered in genuine gold leaf reflecting into the pond.",
                    iconName: "sun.max.fill"
                ),
                TipItem(
                    title: "Follow the One-Way Garden Path",
                    summary: "Visitor flow is strictly unidirectional. Take your time at the initial pond vantage points, as you cannot double back once past the teahouse.",
                    iconName: "arrow.right"
                ),
                TipItem(
                    title: "Try Gold-Leaf Soft Cream",
                    summary: "Shops right outside the exit gate serve premium Kyoto matcha soft-serve wrapped in edible gold leaf.",
                    iconName: "sparkles"
                )
            ]
        }

        if name.contains("arashiyama") && (name.contains("bamboo") || name.contains("grove")) {
            return [
                TipItem(
                    title: "Arrive by 7:30 AM for Serenity",
                    summary: "By 9:00 AM, rickshaws and tour groups fill the narrow bamboo lane. Early mornings are peaceful and bird-filled.",
                    iconName: "sunrise.fill"
                ),
                TipItem(
                    title: "Visit Okochi Sanso Villa at the Top",
                    summary: "At the end of the bamboo corridor, pay admission to enter this silent heritage villa; your ticket includes fresh matcha and tea cake in the garden.",
                    iconName: "leaf.fill"
                )
            ]
        }

        if name.contains("nishiki") {
            return [
                TipItem(
                    title: "Eat in Front of the Stall",
                    summary: "Walking while eating is considered impolite in Japan. Enjoy snacks directly in front of the stall where purchased before continuing.",
                    iconName: "hand.raised.fill"
                ),
                TipItem(
                    title: "Must-Try Market Delicacies",
                    summary: "Sample freshly rolled dashi tamagoyaki (dashi egg omelet), soy milk donuts, candied baby octopus skewers, and sesame senbei crackers.",
                    iconName: "fork.knife"
                ),
                TipItem(
                    title: "Visit Around 11:00 AM – 3:00 PM",
                    summary: "Most family-run merchants begin packing up by 5:00 PM. Midday has the freshest preparations and fullest selection.",
                    iconName: "clock.fill"
                )
            ]
        }

        if name.contains("kiyomizu") {
            return [
                TipItem(
                    title: "Early Opening at 6:00 AM",
                    summary: "The main wooden terrace suspended over the maple hillside is open at dawn. Watch monks chant with the Kyoto city basin waking up below.",
                    iconName: "sunrise.fill"
                ),
                TipItem(
                    title: "Drink from Otowa Waterfall",
                    summary: "Use long poles to catch water from one of three sacred streams (health, academic success, or love). Japanese tradition says pick only one!",
                    iconName: "drop.fill"
                ),
                TipItem(
                    title: "Wear Easy Slip-On Shoes",
                    summary: "Entering the sacred inner halls and prayer rooms requires removing your shoes.",
                    iconName: "shoeprints.fill"
                )
            ]
        }

        if name.contains("gion") {
            return [
                TipItem(
                    title: "Respect Geiko and Maiko Etiquette",
                    summary: "Do not block pathways, touch silk kimonos, or enter private residential alleys with 'No Photography' signs. Fines are strictly enforced.",
                    iconName: "shield.fill"
                ),
                TipItem(
                    title: "Stroll Hanami-koji at Dusk",
                    summary: "Around 5:30 to 6:00 PM, lanterns light up traditional wooden 'machiya' merchant houses and teahouses.",
                    iconName: "lamp.table.fill"
                ),
                TipItem(
                    title: "Walk Along the Shirakawa Canal",
                    summary: "Just north of Shijo street, the stone canal lined with willows and wooden footbridges offers quiet, romantic photo angles.",
                    iconName: "water.waves"
                )
            ]
        }

        if name.contains("philosopher") {
            return [
                TipItem(
                    title: "Walk North to South",
                    summary: "Start near Ginkaku-ji (Silver Pavilion) and amble southward towards Nanzen-ji; this direction follows the gentle downstream canal current.",
                    iconName: "figure.walk"
                ),
                TipItem(
                    title: "Hidden Teahouses & Cat Shrines",
                    summary: "Small ceramic workshops, peaceful tea stands, and the charming Otoyoyo Shrine (famous for mouse and cat guardian statues) line the trail.",
                    iconName: "cup.and.saucer.fill"
                )
            ]
        }

        if name.contains("pontocho") || name.contains("pontochō") {
            return [
                TipItem(
                    title: "Kawayuka Terrace Dining (May–Sept)",
                    summary: "Book outdoor wooden decks built directly over the rushing Kamogawa river to enjoy cooling breezes and authentic Kyoto multi-course meals.",
                    iconName: "water.waves"
                ),
                TipItem(
                    title: "North End for Casual Walk-Ins",
                    summary: "The southern end near Shijo has exclusive members-only ochaya teahouses; the north end near Sanjo has accessible craft beer bars and ramen shops.",
                    iconName: "fork.knife"
                )
            ]
        }

        // 3. Mexico City Iconic Venues
        if name.contains("frida") || name.contains("kahlo") || name.contains("casa azul") {
            return [
                TipItem(
                    title: "Strict Online Booking Required",
                    summary: "Tickets are NEVER sold at the physical door. You must book online 2-4 weeks in advance, especially for weekends.",
                    iconName: "exclamationmark.triangle.fill"
                ),
                TipItem(
                    title: "Purchase the Photo Permit at Entry",
                    summary: "Taking photos inside the house with a phone requires a small fee for a wristband permit issued at the courtyard counter.",
                    iconName: "camera.fill"
                ),
                TipItem(
                    title: "Allow Time for Coyoacán Plaza",
                    summary: "Combine your visit with a peaceful stroll through Jardín Centenario and try hot churros at the traditional market.",
                    iconName: "map.fill"
                )
            ]
        }

        if name.contains("antropolog") || name.contains("anthropology") {
            return [
                TipItem(
                    title: "Don't Try to See All 23 Rooms",
                    summary: "The museum is enormous. Prioritize Hall 7 (Mexica / Aztec Sun Stone) and Hall 9 (Maya tombs and Palenque jade mask) first.",
                    iconName: "eye.fill"
                ),
                TipItem(
                    title: "Free Coat & Bag Check",
                    summary: "Large backpacks and bottles must be checked at the complimentary cloakroom before entering the courtyard umbrella fountain.",
                    iconName: "bag.fill"
                ),
                TipItem(
                    title: "Best Timing: Tuesday to Friday Morning",
                    summary: "Mexican residents receive free admission on Sundays so weekends get packed. Weekday mornings offer quiet viewing.",
                    iconName: "calendar.fill"
                )
            ]
        }

        if name.contains("zócalo") || name.contains("zocalo") {
            return [
                TipItem(
                    title: "Free Entry to the Metropolitan Cathedral",
                    summary: "Step inside to see the golden altar and observe the plumb-line pendulum revealing how the church slowly sinks into the ancient lakebed.",
                    iconName: "building.columns.fill"
                ),
                TipItem(
                    title: "Rooftop Views from Gran Hotel or Balcón",
                    summary: "Head up to the terrace café at the Gran Hotel Ciudad de México to see the Tiffany stained-glass ceiling and look over the whole plaza.",
                    iconName: "camera.fill"
                ),
                TipItem(
                    title: "6:00 PM Flag Lowering Ceremony",
                    summary: "Military guards march across the central square each evening at 6:00 PM to ceremoniously fold the monumental Mexican flag.",
                    iconName: "flag.fill"
                )
            ]
        }

        if name.contains("bellas artes") {
            return [
                TipItem(
                    title: "Top Floor Murals by Mexican Masters",
                    summary: "Take the elevators to the 2nd and 3rd floors to view Diego Rivera's famous mural 'Man, Controller of the Universe' alongside Siqueiros and Orozco masterpieces.",
                    iconName: "photo.artframe"
                ),
                TipItem(
                    title: "Postcard View from Sears Café",
                    summary: "Cross the street to the Sears department store and ride up to the 8th-floor Café Don Porfirio for the iconic aerial view of the yellow-orange marble dome.",
                    iconName: "camera.fill"
                )
            ]
        }

        if name.contains("contramar") {
            return [
                TipItem(
                    title: "Order the Signature Pescado a la Talla",
                    summary: "The half-red chile, half-green parsley grilled fish is legendary, along with the fresh tuna tostadas with crispy leeks and avocado.",
                    iconName: "fork.knife"
                ),
                TipItem(
                    title: "Lunch is the Main Event (1:30–5:00 PM)",
                    summary: "Contramar is traditionally a long leisurely lunch destination. Reservations open 30 days ahead; bar seats accommodate early walk-ins at 1:00 PM.",
                    iconName: "clock.fill"
                ),
                TipItem(
                    title: "Finish with Fig Tart or Strawberry Merengue",
                    summary: "Waiters bring around silver trays of fresh bakery desserts. The fig tart with mascarpone is universally praised.",
                    iconName: "star.fill"
                )
            ]
        }

        if name.contains("coyoacán") || name.contains("coyoacan") {
            return [
                TipItem(
                    title: "Crispy Tostadas at Stall 181",
                    summary: "The center of the market is famed for colorful pyramid displays of fresh ceviche, shredded tinga chicken, and pork tostadas piled high.",
                    iconName: "fork.knife"
                ),
                TipItem(
                    title: "Fresh Fruit Aguas Frescas",
                    summary: "Try massive cold cups of fresh agua de horchata (sweet cinnamon rice milk), maracuyá (passion fruit), or flor de jamaica (hibiscus).",
                    iconName: "cup.and.saucer.fill"
                )
            ]
        }

        if name.contains("xochimilco") {
            return [
                TipItem(
                    title: "Fixed Government Boat Pricing",
                    summary: "Official trajinera boat rental rates are regulated per boat per hour (not per person). Look for the official municipality board before boarding.",
                    iconName: "tag.fill"
                ),
                TipItem(
                    title: "Embarcadero Cuemanco vs. Nativitas",
                    summary: "Cuemanco offers quiet, eco-friendly canal routes through nature reserves and chinampa farms; Nativitas has party boats with floating mariachis.",
                    iconName: "map.fill"
                ),
                TipItem(
                    title: "BYOB & Cash for Floating Vendors",
                    summary: "You are allowed to bring your own coolers of drinks and snacks onto the boat, but bring cash to hire floating mariachi songs or buy hot elotes.",
                    iconName: "banknote.fill"
                )
            ]
        }

        if name.contains("teotihuac") {
            return [
                TipItem(
                    title: "Take Early Autobuses del Norte (Gate 8)",
                    summary: "Direct express buses depart every 15 minutes. Arrive at the pyramids right at 8:00 AM opening to explore before the desert sun gets intense.",
                    iconName: "bus.fill"
                ),
                TipItem(
                    title: "Strict Sun Protection & 2L Water",
                    summary: "The Avenue of the Dead has zero tree canopy across 4 kilometers. A wide-brim hat, high-SPF sunscreen, and water are essential.",
                    iconName: "sun.max.fill"
                ),
                TipItem(
                    title: "Dine at La Gruta Restaurant",
                    summary: "After touring the Moon and Sun pyramids, have lunch inside La Gruta, a massive underground candlelit volcanic cave 5 minutes from Gate 5.",
                    iconName: "fork.knife"
                )
            ]
        }

        // 4. Miami Iconic Venues
        if name.contains("joe") && name.contains("crab") {
            return [
                TipItem(
                    title: "Stone Crab Season: October to May",
                    summary: "Fresh stone crab claws are only harvested from mid-October through early May. Order the large claws with signature cold mustard sauce.",
                    iconName: "calendar.fill"
                ),
                TipItem(
                    title: "Joe's Take Away for Zero Wait",
                    summary: "The main dining room doesn't take reservations and waits can reach 2 hours. Joe's Take Away next door serves the identical menu with no wait.",
                    iconName: "arrow.right.circle.fill"
                ),
                TipItem(
                    title: "Save Room for Key Lime Pie",
                    summary: "Often called the best in Florida, served chilled with a thick graham cracker crust and whipped cream.",
                    iconName: "star.fill"
                )
            ]
        }

        if name.contains("wynwood") {
            return [
                TipItem(
                    title: "Visit Late Afternoon to Beat the Heat",
                    summary: "Wynwood is an open-air concrete district with minimal shade. Arrive after 4:00 PM when the tropical heat breaks and lighting is ideal for mural shots.",
                    iconName: "sun.horizon.fill"
                ),
                TipItem(
                    title: "Explore the Free Surrounding Streets",
                    summary: "While the gated Wynwood Walls has an entry fee, dozens of world-class murals by international artists line the adjacent 6-block radius for free.",
                    iconName: "figure.walk"
                ),
                TipItem(
                    title: "Comfortable Footwear & Sunscreen",
                    summary: "Expect 1.5 to 2 hours of walking across paved avenues between galleries, breweries, and outdoor installations.",
                    iconName: "shoeprints.fill"
                ),
                TipItem(
                    title: "Great Nearby Refreshments",
                    summary: "Grab cold-brew at Panther Coffee or local tacos at Coyo Taco right around the corner after finishing your mural tour.",
                    iconName: "cup.and.saucer.fill"
                )
            ]
        }

        // 5. Category-tailored practical wisdom for any other venues
        switch place.category {
        case .museum:
            return [
                TipItem(
                    title: "Reserve Timed-Entry Slots Online",
                    summary: "Most major museums cap visitor flow by timeslot. Booking ahead guarantees admission and bypasses the general ticket queue.",
                    iconName: "ticket.fill"
                ),
                TipItem(
                    title: "Cloakroom & Bag Restrictions",
                    summary: "Backpacks larger than standard daypacks, tripods, and long umbrellas usually must be checked at the cloakroom before entry.",
                    iconName: "bag.fill"
                ),
                TipItem(
                    title: "Download the Official Audio Guide",
                    summary: "Many museums provide free companion apps or audio guides on their website. Download over Wi-Fi before arriving to save roaming data.",
                    iconName: "headphones"
                ),
                TipItem(
                    title: "Best Visiting Windows",
                    summary: "Weekday mornings right at opening or late afternoon hours right before closing offer the most peaceful gallery viewing.",
                    iconName: "clock.fill"
                )
            ]

        case .attraction:
            return [
                TipItem(
                    title: "Optimal Photo Timing",
                    summary: "The hour right after sunrise or right before sunset provides warm directional light with fewer harsh shadows and fewer photo-bombers.",
                    iconName: "camera.fill"
                ),
                TipItem(
                    title: "Sturdy Footwear for Historic Pavement",
                    summary: "Ancient stones, uneven marble steps, and cobblestones can get slippery when polished by crowds. Wear sneakers or flat shoes.",
                    iconName: "shoeprints.fill"
                ),
                TipItem(
                    title: "Sun Protection & Refillable Water",
                    summary: "Historic courtyards often have limited canopy shade. Carry a compact water bottle and wear UV protection on sunny days.",
                    iconName: "sun.max.fill"
                ),
                TipItem(
                    title: "Check Local Event Schedules",
                    summary: "Historic landmarks occasionally close early for civic functions or maintenance. Check the venue's social or website on the morning of your visit.",
                    iconName: "calendar.badge.clock"
                )
            ]

        case .nature, .relaxation, .activity:
            return [
                TipItem(
                    title: "Monitor Weather & Wind Conditions",
                    summary: "Open viewpoints and coastal lookouts experience sudden wind gusts and temperature drops. Pack a light windbreaker or layer.",
                    iconName: "cloud.sun.fill"
                ),
                TipItem(
                    title: "Download Offline Maps",
                    summary: "Cellular reception can drop in dense tree cover or canyons. Cache your route or screenshot trail landmarks in advance.",
                    iconName: "map.fill"
                ),
                TipItem(
                    title: "Leave No Trace",
                    summary: "Keep the natural environment intact by packing out all wrappers and staying on designated paths to preserve native flora.",
                    iconName: "leaf.fill"
                ),
                TipItem(
                    title: "Early Arrival for Parking & Solitude",
                    summary: "Trailhead parking and scenic overlooks fill up quickly on pleasant weekends. Arrive before 9:00 AM for effortless access.",
                    iconName: "car.fill"
                )
            ]

        case .nightlife:
            return [
                TipItem(
                    title: "Check the Door & Dress Code Policy",
                    summary: "Many nightlife venues enforce smart-casual footwear and attire (no athletic shorts or flip-flops) after 9:00 PM.",
                    iconName: "tshirt.fill"
                ),
                TipItem(
                    title: "Prime Energy Timing",
                    summary: "Crowds and resident DJs typically ramp up around 11:30 PM. Arrive earlier if you prefer quiet craft cocktails and easier seating.",
                    iconName: "sparkles"
                ),
                TipItem(
                    title: "Plan Safe Transit Home",
                    summary: "Rideshares experience surge pricing and longer wait times right around closing. Pre-schedule or identify nearby transit stops in advance.",
                    iconName: "car.side.fill"
                )
            ]

        case .food:
            return [
                TipItem(
                    title: "Book Reservations in Advance",
                    summary: "Popular venues book out days or weeks ahead for prime dinner slots. Check if bar seating is available for walk-ins without reservations.",
                    iconName: "calendar.fill"
                ),
                TipItem(
                    title: "Ask for Server Specialties",
                    summary: "Chefs often prepare off-menu seasonal specials or catch of the day that isn't printed on the standard menu.",
                    iconName: "fork.knife"
                ),
                TipItem(
                    title: "Dietary & Allergen Notes",
                    summary: "Most kitchens gladly accommodate vegetarian or gluten sensitivities if notified at the time of ordering.",
                    iconName: "checkmark.seal.fill"
                )
            ]
        }
    }
}
