import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var isAddSheetPresented = false
    @State private var isDirectionsPresented = false

    private var city: City { CityDirectory.city(id: place.cityID) }

    /// Where the traveller is staying in this city, on the next trip there
    /// that hasn't ended, so directions can start from the hotel.
    private var lodging: Lodging? {
        let today = Calendar.current.startOfDay(for: .now)
        return store.trips
            .filter { $0.cityID == place.cityID && $0.endDate >= today && $0.lodging != nil }
            .min { $0.startDate < $1.startDate }?.lodging
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 24) {
                    titleBlock
                    factsRow
                    Hairline()
                    aboutBlock
                    if !place.tags.isEmpty {
                        Hairline()
                        tagsBlock
                    }
                    Hairline()
                    mapBlock
                    if place.event == nil {
                        Hairline()
                        PlaceShortsSection(place: place)
                    }
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.top, 22)
                .padding(.bottom, 32)
                .background(
                    Palette.canvas,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 22,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 22,
                        style: .continuous
                    )
                )
                .padding(.top, -22)
            }
        }
        .background(Palette.canvas)
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .navigationBarBackButtonHidden()
        .overlay(alignment: .topLeading) { floatingControls }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $isAddSheetPresented) {
            AddToItinerarySheet(place: place)
        }
        .fullScreenCover(isPresented: $isDirectionsPresented) {
            DirectionsView(place: place, lodging: lodging)
        }
    }

    // MARK: Hero

    private var hero: some View {
        PlacePhoto(place: place)
            .frame(height: 360)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [.black.opacity(0.28), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 110)
            }
            .clipped()
    }

    private var floatingControls: some View {
        HStack {
            GlassCircleButton(systemImage: "chevron.left") { dismiss() }
                .accessibilityLabel("Back")
            Spacer()
            HStack(spacing: 10) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .floatingShadow(y: 1, radius: 4, opacity: 0.18)
                }
                .accessibilityLabel("Share place")
                Button {
                    store.toggleSaved(place)
                } label: {
                    Image(systemName: store.isSaved(place) ? "heart.fill" : "heart")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(store.isSaved(place) ? Brand.rausch : Palette.ink)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .floatingShadow(y: 1, radius: 4, opacity: 0.18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isSaved(place) ? "Remove from saved" : "Save place")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var shareText: String {
        "\(place.name) — \(place.blurb). Found it on City Tourist."
    }

    // MARK: Content

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(place.name)
                .font(.title.weight(.bold))
                .tracking(-0.5)
                .foregroundStyle(Palette.ink)
            Text("\(place.neighborhood), \(city.name)")
                .metaStyle()
            HStack(spacing: 8) {
                RatingLabel(rating: place.rating, reviewCount: place.reviewCount, size: 15)
                if let status = place.openStatus {
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Label(status, systemImage: "clock")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(place.isOpenNow == false ? Brand.rausch : Brand.babu)
                }
            }
            .padding(.top, 2)
        }
    }

    private var factsRow: some View {
        HStack(spacing: 10) {
            fact(symbol: "clock", title: place.durationLabel, subtitle: "Typical visit")
            fact(symbol: "creditcard", title: place.priceLabel, subtitle: "Entry")
            fact(symbol: place.category.symbol, title: place.category.title, subtitle: "Category")
        }
    }

    private func fact(symbol: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.rausch)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle).captionStyle()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About this place").sectionTitleStyle()
            Text(place.about)
                .bodyStyle()
                .lineSpacing(4)
        }
    }

    private var tagsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Good to know").sectionTitleStyle()
            FlowLayout(spacing: 8) {
                ForEach(place.tags, id: \.self) { tag in
                    Chip(title: tag)
                }
            }
        }
    }

    private var mapBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where you'll be").sectionTitleStyle()
            LookAroundBlock(coordinate: place.coordinate)
            Map(initialPosition: .region(MKCoordinateRegion(
                center: place.coordinate.clLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            ))) {
                Annotation(place.name, coordinate: place.coordinate.clLocation) {
                    MapPin(number: nil)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
            .allowsHitTesting(false)
            Text(place.neighborhood).metaStyle()
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        StickyBottomBar {
            HStack(spacing: 12) {
                SecondaryButton(title: "Directions", systemImage: "arrow.triangle.turn.up.right.diamond") {
                    isDirectionsPresented = true
                }
                .accessibilityIdentifier("placeDirections")
                PrimaryButton(title: "Add to trip") { isAddSheetPresented = true }
            }
        }
    }

}

/// Wraps chips onto as many lines as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        PlaceDetailView(place: SampleData.places[0])
            .environment(AppStore(loadFromDisk: false))
        .environment(PlaceCatalog())
        .environment(PlaceShorts(makeService: { nil }, cacheURL: nil))
    }
}
