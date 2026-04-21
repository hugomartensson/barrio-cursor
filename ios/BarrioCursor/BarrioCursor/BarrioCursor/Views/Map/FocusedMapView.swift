import SwiftUI
import MapKit

// MARK: - FocusedMapView
// Modal map that shows a fixed set of spots/events (no live API loading).
// Used by: collection "See on Map", spot detail, event detail, plan detail.

struct FocusedMapView: View {
    let title: String
    let spots: [PortalSpotItem]
    let events: [Event]
    /// When set, the camera will start focused on this coordinate with a tight zoom.
    var focusCoordinate: CLLocationCoordinate2D? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var contentFilter: ContentFilter = .all
    @State private var previewSpot: PortalSpotItem? = nil
    @State private var previewEvent: Event? = nil
    @State private var detailSpot: PortalSpotItem? = nil
    @State private var detailEvent: Event? = nil
    @EnvironmentObject var authManager: AuthManager

    enum ContentFilter: String, CaseIterable {
        case all, spots, events
        var label: String {
            switch self {
            case .all: return "All"
            case .spots: return "Spots"
            case .events: return "Events"
            }
        }
    }

    private var visibleSpots: [PortalSpotItem] {
        contentFilter == .events ? [] : spots.filter { $0.coordinate != nil }
    }
    private var visibleEvents: [Event] {
        contentFilter == .spots ? [] : events
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Map
            Map(position: $cameraPosition) {
                ForEach(visibleSpots) { spot in
                    if let coord = spot.coordinate {
                        Annotation("", coordinate: coord) {
                            FocusedSpotPin(name: spot.name, categoryLabel: spot.categoryLabel)
                                .onTapGesture { previewSpot = spot; previewEvent = nil }
                        }
                    }
                }
                ForEach(visibleEvents) { event in
                    Annotation("", coordinate: event.coordinate) {
                        FocusedEventPin(event: event)
                            .onTapGesture { previewEvent = event; previewSpot = nil }
                    }
                }
            }
            .ignoresSafeArea()

            // Top bar
            VStack(spacing: 0) {
                topBar
                Spacer()
            }

            // Preview cards
            if let spot = previewSpot {
                VStack {
                    Spacer()
                    focusedSpotPreview(spot)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: previewSpot?.id)
            }
            if let event = previewEvent {
                VStack {
                    Spacer()
                    focusedEventPreview(event)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: previewEvent?.id)
            }
        }
        .onAppear { setCameraPosition() }
        .sheet(item: $detailSpot) { spot in
            SpotDetailView(spot: spot, isSaved: false)
                .environmentObject(authManager)
        }
        .sheet(item: $detailEvent) { event in
            EventDetailView(event: event)
                .environmentObject(authManager)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.portalForeground)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.portalBorder.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.portalLabelSemibold)
                .foregroundColor(.portalForeground)
                .lineLimit(1)

            Spacer()

            // Content type pills
            HStack(spacing: 4) {
                ForEach(ContentFilter.allCases, id: \.self) { filter in
                    let active = contentFilter == filter
                    Button { contentFilter = filter } label: {
                        Text(filter.label)
                            .font(.system(size: 12, weight: active ? .semibold : .regular))
                            .foregroundColor(active ? .portalPrimaryForeground : .portalForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(active ? Color.portalPrimary : Color.portalCard)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: contentFilter)
                }
            }
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.portalBorder).frame(height: 0.5)
        }
    }

    // MARK: - Preview Cards

    private func focusedSpotPreview(_ spot: PortalSpotItem) -> some View {
        Button {
            detailSpot = spot
            previewSpot = nil
        } label: {
            HStack(spacing: 12) {
                if let url = spot.imageURL.flatMap({ URL(string: $0) }) {
                    CachedRemoteImage(url: url, placeholder: { placeholderRect }, failure: { placeholderRect })
                        .frame(width: 64, height: 64)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    placeholderRect
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let cat = spot.categoryLabel {
                        Text(cat)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.portalPrimary)
                    }
                    Text(spot.name)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                        .lineLimit(1)
                    Text(spot.neighborhood)
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.portalMutedForeground)

                Button { previewSpot = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.portalMutedForeground)
                        .frame(width: 28, height: 28)
                        .background(Color.portalMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.portalCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func focusedEventPreview(_ event: Event) -> some View {
        Button {
            detailEvent = event
            previewEvent = nil
        } label: {
            HStack(spacing: 12) {
                if let url = (event.media.first?.thumbnailUrl ?? event.media.first?.url).flatMap({ URL(string: $0) }) {
                    CachedRemoteImage(url: url, placeholder: { placeholderRect }, failure: { placeholderRect })
                        .frame(width: 64, height: 64)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    placeholderRect
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(event.category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.portalPrimary)
                    Text(event.title)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                        .lineLimit(1)
                    Text(event.displayNeighborhood)
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.portalMutedForeground)

                Button { previewEvent = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.portalMutedForeground)
                        .frame(width: 28, height: 28)
                        .background(Color.portalMuted)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color.portalCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var placeholderRect: some View {
        Rectangle().fill(Color.portalMuted)
    }

    // MARK: - Camera Setup

    private func setCameraPosition() {
        if let focus = focusCoordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: focus,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            ))
            return
        }
        // Fit all pins
        let coords: [CLLocationCoordinate2D] = spots.compactMap(\.coordinate) + events.map(\.coordinate)
        guard !coords.isEmpty else { return }
        if coords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: coords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            return
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Pin Views

private struct FocusedSpotPin: View {
    let name: String
    let categoryLabel: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text(name.prefix(20))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.portalPrimary)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}

private struct FocusedEventPin: View {
    let event: Event

    private var isLive: Bool {
        let now = Date()
        return now >= event.startTime && (event.endTime.map { now <= $0 } ?? false)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            Text(String(event.title.prefix(20)))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            if isLive {
                Text("LIVE")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.teal)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
    }
}
