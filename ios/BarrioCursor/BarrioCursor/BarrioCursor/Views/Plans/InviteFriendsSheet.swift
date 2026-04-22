import SwiftUI

struct InviteFriendsSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let planId: String
    let existingMemberIds: Set<String>
    var onInvited: (() -> Void)?

    @State private var mutuals: [FollowerUser] = []
    @State private var selectedIds: Set<String> = []
    @State private var isLoading = false
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if mutuals.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "person.2")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.portalMutedForeground)
                        Text("No mutual followers")
                            .font(.portalLabelSemibold)
                            .foregroundColor(.portalForeground)
                        Text("You can only invite people who follow you back.")
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.horizontal, .portalPagePadding)
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(mutuals) { user in
                                userRow(user)
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            .background(Color.portalBackground)
            .navigationTitle("Invite Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.portalMutedForeground)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("Invite") { Task { await sendInvites() } }
                            .font(.portalLabelSemibold)
                            .foregroundColor(selectedIds.isEmpty ? .portalMutedForeground : .portalPrimary)
                            .disabled(selectedIds.isEmpty)
                    }
                }
            }
            .task { await loadMutuals() }
        }
    }

    @ViewBuilder
    private func userRow(_ user: FollowerUser) -> some View {
        let isAlreadyMember = existingMemberIds.contains(user.id)
        let isSelected = selectedIds.contains(user.id)

        Button {
            if isAlreadyMember { return }
            if isSelected {
                selectedIds.remove(user.id)
            } else {
                selectedIds.insert(user.id)
            }
        } label: {
            HStack(spacing: 14) {
                // Avatar
                Group {
                    if let urlStr = user.profilePictureUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                initialsView(user.name)
                            }
                        }
                    } else {
                        initialsView(user.name)
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())

                Text(user.name)
                    .font(.portalLabel)
                    .foregroundColor(isAlreadyMember ? .portalMutedForeground : .portalForeground)

                Spacer()

                if isAlreadyMember {
                    Text("Invited")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                } else {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Color.portalPrimary : Color.portalBorder, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        if isSelected {
                            Circle()
                                .fill(Color.portalPrimary)
                                .frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyMember)
    }

    private func initialsView(_ name: String) -> some View {
        ZStack {
            Circle().fill(Color.portalMuted)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.portalMutedForeground)
        }
    }

    private func loadMutuals() async {
        guard let token = authManager.token else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await PlanService.shared.getMutualFollowers(token: token)
            await MainActor.run {
                mutuals = result
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func sendInvites() async {
        guard let token = authManager.token, !selectedIds.isEmpty else { return }
        await MainActor.run { isSending = true }
        do {
            try await PlanService.shared.inviteMembers(planId: planId, userIds: Array(selectedIds), token: token)
            await MainActor.run {
                isSending = false
                onInvited?()
                dismiss()
            }
        } catch {
            await MainActor.run { isSending = false }
        }
    }
}
