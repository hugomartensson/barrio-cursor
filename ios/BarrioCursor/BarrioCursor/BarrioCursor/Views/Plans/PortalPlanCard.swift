import SwiftUI

/// Card shown in the Plans tab for each plan.
struct PortalPlanCard: View {
    let plan: PlanData

    private static let thumbSize: CGFloat = 64
    private static let maxThumbs = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + chevron
            HStack(alignment: .top) {
                Text(plan.name)
                    .font(.portalDisplay22)
                    .foregroundColor(.portalForeground)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.portalMutedForeground)
                    .padding(.top, 4)
            }

            // Date + item count
            HStack(spacing: 12) {
                Label(plan.dateRangeLabel, systemImage: "calendar")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                Label("\(plan.itemCount) spots", systemImage: "mappin")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }

            // Thumbnails (left-to-right, no overlap)
            if !plan.previewImageURLs.isEmpty {
                thumbnailStrip
            }
        }
        .padding(14)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadius)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var thumbnailStrip: some View {
        let urls = Array(plan.previewImageURLs.prefix(Self.maxThumbs))
        let extra = plan.previewImageURLs.count - Self.maxThumbs

        HStack(spacing: 6) {
            ForEach(Array(urls.enumerated()), id: \.offset) { _, urlString in
                thumbnailCell(urlString: urlString)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.portalMutedForeground)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .background(Color.portalMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private func thumbnailCell(urlString: String) -> some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color.portalMuted
                    }
                }
            } else {
                Color.portalMuted
            }
        }
        .frame(width: Self.thumbSize, height: Self.thumbSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
