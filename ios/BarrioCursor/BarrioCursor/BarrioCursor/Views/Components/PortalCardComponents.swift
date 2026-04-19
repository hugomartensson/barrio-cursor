import SwiftUI

// MARK: - portal· Shared discovery card UI (Event, Spot, Collection)

/// Save control: teal-filled circle when saved; outlined circle on light surfaces when not.
enum PortalSaveButtonSurface {
    case light
    case dark
}

struct PortalSaveButton: View {
    let isSaved: Bool
    var count: Int = 0
    var surface: PortalSaveButtonSurface = .light
    var diameter: CGFloat = 36
    let action: () -> Void

    private var idleIconColor: Color {
        Color.portalPrimary
    }

    private var countTextColor: Color {
        isSaved ? Color.portalPrimaryForeground : Color.portalPrimary
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(max(0, n))"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSaved ? Color.portalPrimary : Color.white)
                VStack(spacing: 1) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.portalPrimaryForeground : idleIconColor)
                    Text(formatCount(count))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(countTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .padding(.vertical, 4)
            }
            .frame(width: max(diameter, 44), height: max(diameter, 44))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Saved" : "Save")
    }
}

/// Glassmorphic save-count badge for image cards (top-right).
struct GlassmorphicBadge: View {
    let count: Int
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bookmark")
                .font(.portalMinText)
            Text(formatCount(count))
                .font(.portalBadge)
        }
        .foregroundStyle(Color.portalForeground.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.portalBorder.opacity(0.4), lineWidth: 1))
    }
    
    private func formatCount(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }
}

/// Category pill with colored background — same style everywhere (dropdown, cards). Rectangular, slight radius.
struct CategoryPillView: View {
    let label: String
    let color: Color
    var body: some View {
        Text(label)
            .font(.portalCategoryPill)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
    }
}

/// Bottom gradient overlay for image cards. Use inside GeometryReader; height = heightFraction * cardHeight.
struct CardBottomGradient: View {
    let heightFraction: CGFloat
    let cardHeight: CGFloat
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [
                    Color.portalCard.opacity(0),
                    Color.portalCard.opacity(0.85),
                    Color.portalCard
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: cardHeight * heightFraction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

/// Dark editorial gradient (foreground) for magazine-style Spot and Collection cards.
struct EditorialBottomGradient: View {
    let heightFraction: CGFloat
    let cardHeight: CGFloat
    /// Stronger at bottom (Spot: ~60%; Collection can use same or slightly more)
    var body: some View {
        VStack {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [
                    Color.portalForeground.opacity(0),
                    Color.portalForeground.opacity(0.25),
                    Color.portalForeground.opacity(0.55),
                    Color.portalForeground.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: cardHeight * heightFraction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
