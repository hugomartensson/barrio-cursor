import SwiftUI

/// Full list of users who saved a spot or event, with Follow/Following toggles.
struct SaversListView: View {
    let itemType: String  // "spot" | "event"
    let itemId: String
    let initialTotal: Int

    @EnvironmentObject var authManager: AuthManager
    @State private var savers: [SaverItem] = []
    @State private var isLoading = true
    @State private var togglingId: String? = nil
    @State private var localFollowing: Set<String> = []
    @State private var profileUserId: String? = nil

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if savers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No saves yet")
                        .font(.portalBody)
                        .foregroundColor(.portalMutedForeground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(savers) { saver in
                        saverRow(saver)
                            .listRowInsets(EdgeInsets(top: 6, leading: .portalPagePadding, bottom: 6, trailing: .portalPagePadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.portalBackground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.portalBackground.ignoresSafeArea())
        .navigationTitle("Saved by")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .sheet(item: Binding<SpotIdWrapper?>(
            get: { profileUserId.map { SpotIdWrapper(id: $0) } },
            set: { profileUserId = $0?.id }
        )) { wrapper in
            NavigationStack {
                UserProfileView(userId: wrapper.id)
                    .environmentObject(authManager)
            }
        }
    }

    private func saverRow(_ saver: SaverItem) -> some View {
        HStack(spacing: 12) {
            Button { profileUserId = saver.id } label: {
                saverAvatar(saver)
            }
            .buttonStyle(.plain)

            Button { profileUserId = saver.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(saver.name)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                        .lineLimit(1)
                    if let handle = saver.handle {
                        Text("@\(handle)")
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            let isFollowing = localFollowing.contains(saver.id)
            if saver.id == authManager.currentUser?.id {
                EmptyView()
            } else if togglingId == saver.id {
                ProgressView().scaleEffect(0.8)
            } else {
                Button {
                    Task { await toggleFollow(saver: saver) }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isFollowing ? .portalMutedForeground : .portalPrimaryForeground)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(isFollowing ? Color.portalMuted : Color.portalPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func saverAvatar(_ saver: SaverItem) -> some View {
        Group {
            if let urlStr = saver.profilePictureUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        fallbackAvatar(saver)
                    }
                }
            } else {
                fallbackAvatar(saver)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.portalBorder, lineWidth: 1))
    }

    private func fallbackAvatar(_ saver: SaverItem) -> some View {
        let initial = saver.initials?.prefix(1) ?? saver.name.prefix(1)
        return Circle()
            .fill(Color.portalPrimary.opacity(0.3))
            .overlay(
                Text(String(initial))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.portalPrimaryForeground)
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
                localFollowing = Set(response.data.filter { $0.isFollowing }.map { $0.id })
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func toggleFollow(saver: SaverItem) async {
        guard let token = authManager.token else { return }
        togglingId = saver.id
        do {
            if localFollowing.contains(saver.id) {
                _ = try await APIService.shared.unfollowUser(userId: saver.id, token: token)
                localFollowing.remove(saver.id)
            } else {
                _ = try await APIService.shared.followUser(userId: saver.id, token: token)
                localFollowing.insert(saver.id)
            }
        } catch {}
        togglingId = nil
    }
}
