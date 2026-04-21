import SwiftUI

/// Compact "Saved by" row: section header, up to 3 overlapping avatars, "+N" badge, and navigation to full list.
struct SavedByRow: View {
    let itemType: String  // "spot" | "event"
    let itemId: String

    @EnvironmentObject var authManager: AuthManager
    @State private var savers: [SaverItem] = []
    @State private var total: Int = 0
    @State private var isLoading = true
    @State private var showList = false

    private let avatarSize: CGFloat = 36
    private let overlap: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SAVED BY")
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if savers.isEmpty {
                Text("Be the first to save this")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            } else {
                Button {
                    showList = true
                } label: {
                    HStack(spacing: 10) {
                        avatarStack
                        VStack(alignment: .leading, spacing: 2) {
                            Text(summaryLabel)
                                .font(.portalLabel)
                                .foregroundColor(.portalForeground)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.portalMutedForeground)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .task { await load() }
        .navigationDestination(isPresented: $showList) {
            SaversListView(itemType: itemType, itemId: itemId, initialTotal: total)
                .environmentObject(authManager)
        }
    }

    private var previewSavers: [SaverItem] { Array(savers.prefix(3)) }
    private var extraCount: Int { max(0, total - 3) }

    private var summaryLabel: String {
        if total == 1 {
            return savers.first?.name ?? "1 person"
        } else if total == 2 {
            let names = savers.prefix(2).map { $0.name }
            return names.joined(separator: " & ")
        } else {
            return "\(savers.first?.name ?? "Someone") and \(total - 1) others"
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -overlap) {
            ForEach(previewSavers) { saver in
                avatarView(saver)
            }
            if extraCount > 0 {
                Circle()
                    .fill(Color.portalMuted)
                    .frame(width: avatarSize, height: avatarSize)
                    .overlay(
                        Text("+\(extraCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.portalForeground)
                    )
                    .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
            }
        }
    }

    @ViewBuilder
    private func avatarView(_ saver: SaverItem) -> some View {
        Group {
            if let urlStr = saver.profilePictureUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        fallback(saver)
                    }
                }
            } else {
                fallback(saver)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
    }

    private func fallback(_ saver: SaverItem) -> some View {
        let initial = saver.initials?.prefix(1) ?? saver.name.prefix(1)
        return Circle()
            .fill(Color.portalPrimary.opacity(0.4))
            .overlay(
                Text(String(initial))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func load() async {
        guard let token = authManager.token else { isLoading = false; return }
        do {
            let response: SaversListResponse
            if itemType == "spot" {
                response = try await APIService.shared.getSpotSavers(spotId: itemId, token: token)
            } else {
                response = try await APIService.shared.getEventSavers(eventId: itemId, token: token)
            }
            await MainActor.run {
                savers = response.data
                total = response.total
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
