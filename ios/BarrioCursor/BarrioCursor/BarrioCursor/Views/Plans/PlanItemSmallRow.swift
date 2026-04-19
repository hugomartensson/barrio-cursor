import SwiftUI

/// Reusable compact row for plan-related lists (Add from Saves, Create Plan, Plan Detail).
struct PlanItemSmallRow: View {
    let imageURL: String?
    let title: String
    let subtitle: String?
    let category: String?
    let categoryColor: Color?
    let mode: Mode

    enum Mode {
        case selectable(isSelected: Bool, onTap: () -> Void)
        case plain(onTap: (() -> Void)?)
    }

    var body: some View {
        switch mode {
        case .selectable(let isSelected, let onTap):
            Button(action: onTap) {
                rowContent(isSelected: isSelected)
            }
            .buttonStyle(.plain)
        case .plain(let onTap):
            if let onTap {
                Button(action: onTap) {
                    rowContent(isSelected: false, showCheckmark: false)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(isSelected: false, showCheckmark: false)
            }
        }
    }

    @ViewBuilder
    private func rowContent(isSelected: Bool, showCheckmark: Bool = true) -> some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                if let cat = category, let color = categoryColor {
                    Text(cat)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)
                    .lineLimit(1)
                if let sub = subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showCheckmark {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.portalPrimary)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.portalBorder)
                }
            }
        }
        .padding(12)
        .background(isSelected ? Color.portalPrimary.opacity(0.06) : Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadiusSm)
                .stroke(isSelected ? Color.portalPrimary : Color.portalBorder,
                        lineWidth: isSelected ? 1.5 : 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let u = imageURL, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.portalMuted
                    }
                }
            } else {
                Color.portalMuted
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
