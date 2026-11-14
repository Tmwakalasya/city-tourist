import Foundation

/// Practical tips for hand-written venues, matched strictly by place ID.
enum PlaceTipsService {

    struct TipItem: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let summary: String
        let iconName: String
    }

    /// Whether hand-written visitor tips exist for the place.
    static func hasTips(for placeID: String) -> Bool {
        curated[placeID] != nil
    }

    /// Returns hand-written tips for the given place, or an empty list if not hand-written.
    static func tips(for place: Place) -> [TipItem] {
        tips(for: place.id)
    }

    static func tips(for placeID: String) -> [TipItem] {
        curated[placeID] ?? []
    }

    private static let curated: [String: [TipItem]] = [
        // MARK: - Lisbon
        "lis-belem-tower": [
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
                summary: "The exterior view from the waterfront promenade during golden hour often eclipses the interior view, and it's completely free.",
                iconName: "camera.fill"
            ),
            TipItem(
                title: "Pair with Jerónimos Monastery",
                summary: "It's only a 12-minute scenic walk through Praça do Império. Purchase a combined ticket if you plan to visit both on the same day.",
                iconName: "map.fill"
            )
        ],
        "lis-jeronimos": [
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
        ],
        "lis-pasteis-belem": [
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
        ],
        "lis-tram-28": [
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
        ],
        "lis-castelo": [
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
        ],
        "lis-alfama": [
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
        ],
        "lis-senhora-monte": [
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
        ],
        "lis-timeout": [
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
        ],
        "lis-azulejo": [
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
        ],
        "lis-lx-factory": [
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
        ],
        "lis-comercio": [
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
        ],
        "lis-pensao-amor": [
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
        ],

        // MARK: - Kyoto
        "kyo-fushimi": [
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
        ],
        "kyo-kinkakuji": [
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
        ],
        "kyo-arashiyama": [
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
        ],
        "kyo-nishiki": [
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
        ],
        "kyo-kiyomizu": [
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
        ],
        "kyo-gion": [
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
        ],
        "kyo-philosopher": [
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
        ],
        "kyo-pontocho": [
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
        ],

        // MARK: - Mexico City
        "mex-frida": [
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
        ],
        "mex-antropologia": [
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
        ],
        "mex-zocalo": [
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
        ],
        "mex-bellas-artes": [
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
        ],
        "mex-contramar": [
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
        ],
        "mex-coyoacan-market": [
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
        ],
        "mex-xochimilco": [
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
        ],
        "mex-teotihuacan": [
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
    ]
}
