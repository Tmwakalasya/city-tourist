import SwiftUI
import CoreLocation

/// The Explore feed card: full-bleed photo, heart in the corner, then a tight
/// four-line stack of title, subtitle, meta and price — with the rating pulled
/// out to the right of the title, exactly as Airbnb sets it.
struct ListingCard: View {
    let place: Place
    let isSaved: Bool
    var badge: String? = nil
    var onAddToTrip: (() -> Void)? = nil
    let onToggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlacePhoto(place: place)
                .aspectRatio(Metric.photoAspect, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 2) {
                        if let onAddToTrip {
                            PhotoActionButton(systemImage: "calendar.badge.plus", label: String(localized: "Add \(place.name) to trip", bundle: L10n.bundle, locale: L10n.locale), action: onAddToTrip)
                        }
                        HeartButton(isSaved: isSaved, action: onToggleSaved)
                    }
                    .padding(8)
                }
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        if let badge {
                            Text(badge)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.onPhotoInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Palette.onPhoto, in: Capsule())
                                .floatingShadow(y: 2, radius: 6, opacity: 0.16)
                        } else {
                            Label(place.category.title, systemImage: place.category.symbol)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.onPhotoInk)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Palette.onPhoto.opacity(0.9), in: Capsule())
                        }
                    }
                    .padding(12)
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(place.name)
                        .cardTitleStyle()
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    RatingLabel(rating: place.rating, reviewCount: place.reviewCount)
                        .fixedSize(horizontal: true, vertical: false)
                }
                PlaceDistanceLabel(place: place)
                Text(place.blurb)
                    .metaStyle()
                    .lineLimit(1)
                // With live data the third line carries opening status; with
                // sample data there is none, so it falls back to the area.
                HStack(spacing: 5) {
                    Text(place.durationLabel).metaStyle()
                    Text("·").foregroundStyle(Palette.inkFaint)
                    if let open = place.openLabel {
                        Text(open)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(place.isOpenNow == false ? Brand.rausch : Brand.babu)
                        Text("·").foregroundStyle(Palette.inkFaint)
                    }
                    Text(place.neighborhood).metaStyle()
                    Text("·").foregroundStyle(Palette.inkFaint)
                    Text(place.priceLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
                .lineLimit(1)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Compact horizontal variant used inside itineraries and the saved grid.
struct PlaceRow: View {
    let place: Place
    var trailingText: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            PlacePhoto(place: place, showsGlyph: false)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).cardTitleStyle().lineLimit(1)
                Text(place.blurb).captionStyle().lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailingText {
                Text(trailingText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }
}

struct PlaceDistanceLabel: View {
    let place: Place
    @Environment(AppStore.self) private var store
    var body: some View {
        if let city = CityDirectory.knownCity(id: place.cityID), city.coordinate.isValid, place.coordinate.isValid {
            let meters = CLLocation(latitude: city.coordinate.latitude, longitude: city.coordinate.longitude)
                .distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
            Text(L10n.format("%@ from centre", store.distance(meters))).captionStyle()
        }
    }
}
