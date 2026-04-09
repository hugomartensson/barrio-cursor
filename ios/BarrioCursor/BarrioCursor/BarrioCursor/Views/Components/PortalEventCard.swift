import SwiftUI

// MARK: - portal· Event Card — Ticket Style
// Horizontal layout: image strip (left) | perforated divider | ticket info (right). Full width, stacks vertically.

private let ticketImageStripWidth: CGFloat = 112
private let ticketDividerWidth: CGFloat = 16
private let perforationCircleSize: CGFloat = 16

struct PortalEventCard: View {
    @EnvironmentObject var authManager: AuthManager
    let event: Event
    /// When set, the bookmark shows save state and is tappable; saved state uses theme green (.portalPrimary).
    var isSaved: Bool = false
    var onSaveToggle: (() -> Void)? = nil
    /// Extra trailing padding on the text column when Discover overlays a save control on the card (keeps title from sitting under the button).
    var reserveTrailingForExternalSave: CGFloat = 0

    private let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private var imageURL: URL? {
        guard let urlString = event.media.first?.url else { return nil }
        return URL(string: urlString)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left — Image strip (ticket stub). Discover may overlay save on the full card (top-trailing).
            ZStack(alignment: .trailing) {
                CachedRemoteImage(
                    url: imageURL,
                    placeholder: {
                        Rectangle()
                            .fill(Color.portalMuted)
                            .overlay { ProgressView() }
                    },
                    failure: {
                        Rectangle()
                            .fill(Color.portalMuted)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.portalMutedForeground)
                            )
                    }
                )
                .frame(width: ticketImageStripWidth)
                .frame(minHeight: 100)
                .clipped()
                LinearGradient(
                    colors: [Color.clear, Color.portalCard.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 24)
                .frame(maxHeight: .infinity)
            }
            .frame(width: ticketImageStripWidth)
            .clipped()

            // Center — Perforated tear-line divider
            ticketPerforationDivider

            // Right — Ticket information
            VStack(alignment: .leading, spacing: 0) {
                // Header: category pill (match filter style — not caps, smaller font)
                HStack {
                    Text(event.category.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.12)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: event.category.color).opacity(0.15))
                        .foregroundColor(Color(hex: event.category.color))
                        .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                    Spacer(minLength: 0)
                    if let onSaveToggle = onSaveToggle {
                        PortalSaveButton(isSaved: isSaved, count: event.saveCount, surface: .light, action: onSaveToggle)
                    }
                }
                Text(event.title)
                    .font(.portalDisplay14)
                    .foregroundColor(.portalForeground)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 4)
                    .accessibilityIdentifier("event_title")

                Spacer(minLength: 8)

                // Details: date block + time & venue
                HStack(alignment: .center, spacing: 12) {
                    // Date block — month + day, primary tint
                    VStack(spacing: 0) {
                        Text(monthFormatter.string(from: event.startTime))
                            .font(.portalMinText.weight(.bold))
                            .tracking(0.8)
                            .foregroundColor(.portalPrimary)
                        Text(dayFormatter.string(from: event.startTime))
                            .font(.portalDisplay18)
                            .foregroundColor(.portalPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.portalPrimary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.portalMinText)
                            Text(timeFormatter.string(from: event.startTime))
                                .font(.portalMetadata)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.portalMinText)
                            Text(event.displayCity)
                                .font(.portalMetadata)
                                .lineLimit(1)
                        }
                    }
                    .foregroundColor(.portalMutedForeground)
                    Spacer(minLength: 0)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12 + reserveTrailingForExternalSave)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 120)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadius)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .portalCardShadow()
    }

    /// Perforated tear-line: circles match page background (punch-through); dashed line clearly visible.
    private var ticketPerforationDivider: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.portalBackground)
                .frame(width: perforationCircleSize, height: perforationCircleSize)
                .overlay(Circle().stroke(Color.portalBorder, lineWidth: 1.5))
                .offset(y: -perforationCircleSize / 2)
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: ticketDividerWidth / 2, y: 0))
                    p.addLine(to: CGPoint(x: ticketDividerWidth / 2, y: geo.size.height))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(Color.portalForeground.opacity(0.2))
            }
            .frame(maxHeight: .infinity)
            .frame(minHeight: 20)
            Circle()
                .fill(Color.portalBackground)
                .frame(width: perforationCircleSize, height: perforationCircleSize)
                .overlay(Circle().stroke(Color.portalBorder, lineWidth: 1.5))
                .offset(y: perforationCircleSize / 2)
        }
        .frame(width: ticketDividerWidth)
        .zIndex(1)
    }
}

#Preview {
    let event = Event(
        id: "1",
        title: "Jazz at Lincoln Center",
        description: "Join us",
        category: .music,
        address: "Rose Theater",
        neighborhood: nil,
        latitude: 40.7,
        longitude: -73.9,
        startTime: Date(),
        endTime: Date().addingTimeInterval(3600),
        createdAt: Date(),
        saveCount: 243,
        distance: nil,
        media: [MediaItem(id: "1", url: "https://picsum.photos/400/533", type: .photo, order: 0, thumbnailUrl: nil)],
        user: EventUser(id: "1", name: "Weekend Atlas")
    )
    PortalEventCard(event: event)
        .environmentObject(AuthManager())
        .padding(.horizontal)
        .background(Color.portalBackground)
}
