import SwiftUI

// MARK: - portal· Filter Pills
// Time pills: active = gradient-primary; inactive = card + border. Category pills: active = category color; inactive = tint + colored icon.

struct PortalFilterPill: View {
    let title: String
    let icon: String?
    let isActive: Bool
    let categoryColor: Color?
    let action: () -> Void

    init(title: String, icon: String? = nil, isActive: Bool, categoryColor: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isActive = isActive
        self.categoryColor = categoryColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(foregroundColorForIcon)
                }
                Text(title)
                    .font(.portalLabelSemibold)
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                    .stroke(Color.portalBorder, lineWidth: (categoryColor != nil && isActive) ? 0 : (isActive ? 0 : 1))
            )
            .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("filter_pill_\(title.replacingOccurrences(of: " ", with: "_"))")
    }

    private var foregroundColor: Color {
        if categoryColor != nil {
            return isActive ? .white : .portalForeground
        }
        return isActive ? .portalPrimaryForeground : .portalForeground
    }

    private var foregroundColorForIcon: Color {
        if let cat = categoryColor {
            return isActive ? .white : cat
        }
        return isActive ? .portalPrimaryForeground : .portalForeground
    }

    private var backgroundColor: some View {
        Group {
            if let cat = categoryColor {
                if isActive {
                    cat
                } else {
                    cat.opacity(0.1)
                }
            } else {
                if isActive {
                    LinearGradient(
                        colors: [Color(hex: "#2F7168"), Color(hex: "#3D8A80")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.portalCard
                }
            }
        }
    }
}

// MARK: - Time filter pill
// Shared between Discover (FeedView) and the See-More AllEvents list so the
// gradient-active styling and dropdown chevron stay in sync.
struct TimeFilterPill: View {
    let selected: DiscoverTimeIntent?
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let time = selected {
                    Text(time.label)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalPrimaryForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Time")
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                    .stroke(Color.portalBorder, lineWidth: selected != nil ? 0 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var background: some View {
        if selected != nil {
            LinearGradient(
                colors: [Color(hex: "#2F7168"), Color(hex: "#3D8A80")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.portalCard
        }
    }
}

#Preview("Filter pills") {
    HStack(spacing: .portalCardGap) {
        PortalFilterPill(title: "All", isActive: true) {}
        PortalFilterPill(title: "Date", icon: "calendar", isActive: false) {}
        PortalFilterPill(title: "This Weekend", icon: "chevron.down", isActive: false) {}
    }
    .padding()
    .background(Color.portalBackground)
}
