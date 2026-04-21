import SwiftUI

/// Inline three-button action bar rendered inside the detail scroll view,
/// directly below the description. Replaces the floating bottom bar.
struct DetailActionBar: View {
    let itemType: String  // "spot" | "event"
    let isSaved: Bool
    let saveCount: Int
    let onSave: () -> Void
    let onAddToPlan: () -> Void
    let onAddToCollection: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                label: isSaved ? "Saved" : "Save",
                count: saveCount,
                tint: isSaved ? Color.portalPrimary : Color.portalForeground,
                action: onSave
            )

            Divider()
                .frame(height: 36)
                .foregroundColor(Color.portalBorder)

            actionButton(
                icon: "calendar.badge.plus",
                label: "Add to Plan",
                count: nil,
                tint: .portalForeground,
                action: onAddToPlan
            )

            Divider()
                .frame(height: 36)
                .foregroundColor(Color.portalBorder)

            actionButton(
                icon: "folder.badge.plus",
                label: "Add to Collection",
                count: nil,
                tint: .portalForeground,
                action: onAddToCollection
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadiusSm)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func actionButton(
        icon: String,
        label: String,
        count: Int?,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(tint)
                        .frame(width: 26, height: 26)

                    if let count, count > 0 {
                        Text(count < 1000 ? "\(count)" : "\(count / 1000)k")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(tint)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -4)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tint)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
