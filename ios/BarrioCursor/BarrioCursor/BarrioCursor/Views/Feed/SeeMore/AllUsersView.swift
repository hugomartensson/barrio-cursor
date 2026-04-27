import SwiftUI

struct AllUsersView: View {
    let users: [SuggestedUserItem]

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var nameSearch = ""
    @State private var locationSearch = ""
    @State private var showLocationDropdown = false
    @State private var followingIds: Set<String> = []
    @State private var togglingId: String? = nil
    @State private var profileUserId: String? = nil

    private var filtered: [SuggestedUserItem] {
        var result = users
        let nameTrimmed = nameSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !nameTrimmed.isEmpty {
            result = result.filter {
                $0.name.lowercased().contains(nameTrimmed) ||
                $0.handle.lowercased().contains(nameTrimmed)
            }
        }
        let locTrimmed = locationSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !locTrimmed.isEmpty {
            result = result.filter { $0.city.lowercased().contains(locTrimmed) }
        }
        return result
    }

    var body: some View {
        List {
            // Search row: location pill + name search field on same line
            Section {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // Location pill — opens a live LocationSearchField dropdown (matches Discover)
                        Button {
                            showLocationDropdown.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12))
                                    .foregroundColor(.portalPrimary)
                                Text(locationSearch.isEmpty ? "Location" : locationSearch)
                                    .font(.portalMetadata)
                                    .foregroundColor(locationSearch.isEmpty ? .portalMutedForeground : .portalForeground)
                                    .lineLimit(1)
                                if !locationSearch.isEmpty {
                                    Button {
                                        locationSearch = ""
                                        showLocationDropdown = false
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.portalMutedForeground)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Image(systemName: showLocationDropdown ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.portalMutedForeground)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.portalMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .fixedSize(horizontal: true, vertical: false)

                        // Name / handle search — takes remaining width
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.portalMutedForeground)
                                .font(.system(size: 14))
                            TextField("Search by name or handle", text: $nameSearch)
                                .font(.portalBody)
                            if !nameSearch.isEmpty {
                                Button { nameSearch = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.portalMutedForeground)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.portalMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if showLocationDropdown {
                        LocationSearchField(
                            biasCenter: locationManager.coordinate,
                            onUseCurrentLocation: {
                                locationSearch = ""
                                showLocationDropdown = false
                            },
                            onSelect: { resolved in
                                locationSearch = resolved.neighborhood ?? resolved.formattedAddress
                                showLocationDropdown = false
                            }
                        )
                        .padding(12)
                        .background(Color.portalCard)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portalBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: .portalPagePadding, bottom: 8, trailing: .portalPagePadding))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.portalBackground)
            }

            // User rows
            ForEach(filtered) { user in
                userRow(user)
                    .listRowInsets(EdgeInsets(top: 4, leading: .portalPagePadding, bottom: 4, trailing: .portalPagePadding))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.portalBackground)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.portalBackground.ignoresSafeArea())
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.large)
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

    private func userRow(_ user: SuggestedUserItem) -> some View {
        HStack(spacing: 12) {
            // Avatar
            Button { profileUserId = user.id } label: {
                userAvatar(user)
            }
            .buttonStyle(.plain)

            // Name + location
            Button { profileUserId = user.id } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                        .lineLimit(1)
                    if !user.city.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(user.city)
                                .font(.portalMetadata)
                        }
                        .foregroundColor(.portalMutedForeground)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // Follow button
            let isFollowing = followingIds.contains(user.id)
            if togglingId == user.id {
                ProgressView().scaleEffect(0.8)
            } else {
                Button {
                    Task { await toggleFollow(userId: user.id) }
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
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func userAvatar(_ user: SuggestedUserItem) -> some View {
        Group {
            if let urlStr = user.profileImageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        fallbackAvatar(user)
                    }
                }
            } else {
                fallbackAvatar(user)
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.portalBorder, lineWidth: 1))
    }

    private func fallbackAvatar(_ user: SuggestedUserItem) -> some View {
        Circle()
            .fill(user.accentColor)
            .overlay(
                Text(user.initial)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.portalPrimaryForeground)
            )
    }

    private func toggleFollow(userId: String) async {
        guard let token = authManager.token else { return }
        togglingId = userId
        do {
            if followingIds.contains(userId) {
                _ = try await APIService.shared.unfollowUser(userId: userId, token: token)
                followingIds.remove(userId)
            } else {
                _ = try await APIService.shared.followUser(userId: userId, token: token)
                followingIds.insert(userId)
            }
        } catch {}
        togglingId = nil
    }
}
