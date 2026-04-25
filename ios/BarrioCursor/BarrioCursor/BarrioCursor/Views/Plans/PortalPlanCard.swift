import SwiftUI

/// Card shown in the Plans tab for each plan.
struct PortalPlanCard: View {
    let plan: PlanData
    var onAccept: (() -> Void)? = nil
    var onDecline: (() -> Void)? = nil

    private static let thumbSize: CGFloat = 64
    private static let maxThumbs = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + chevron (or no chevron for invitations)
            HStack(alignment: .top) {
                Text(plan.name)
                    .font(.portalDisplay22)
                    .foregroundColor(.portalForeground)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !plan.isPendingInvitation {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                        .padding(.top, 4)
                }
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

            // Member avatars (if any)
            if let members = plan.members, !members.isEmpty {
                memberAvatars(members)
            }

            // Thumbnails (left-to-right, no overlap)
            if !plan.previewImageURLs.isEmpty {
                thumbnailStrip
            }

            // Accept / Decline for pending invitations
            if plan.isPendingInvitation {
                invitationActions
            }
        }
        .padding(14)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadius)
                .stroke(plan.isPendingInvitation ? Color.portalPrimary.opacity(0.5) : Color.portalBorder, lineWidth: 1)
        )
    }

    // MARK: - Member Avatars

    @ViewBuilder
    private func memberAvatars(_ members: [PlanMember]) -> some View {
        let accepted = members.filter { $0.status == "accepted" }
        let invited = members.filter { $0.status == "invited" }
        let visible = accepted + invited   // accepted first, then pending
        let shown = Array(visible.prefix(3))
        let extra = visible.count - 3

        HStack(spacing: -8) {
            ForEach(shown) { member in
                avatarCircle(urlString: member.profilePictureUrl, initials: String(member.name.prefix(1)).uppercased())
                    .saturation(member.status == "accepted" ? 1.0 : 0.0)
                    .opacity(member.status == "accepted" ? 1.0 : 0.55)
            }
            if extra > 0 {
                ZStack {
                    Circle()
                        .fill(Color.portalMuted)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Color.portalCard, lineWidth: 2))
                    Text("+\(extra)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                }
            }
        }
    }

    @ViewBuilder
    private func avatarCircle(urlString: String?, initials: String) -> some View {
        Group {
            if let u = urlString, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        initialsCircle(initials)
                    }
                }
            } else {
                initialsCircle(initials)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.portalCard, lineWidth: 2))
    }

    private func initialsCircle(_ initials: String) -> some View {
        ZStack {
            Circle().fill(Color.portalMuted)
            Text(initials)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.portalMutedForeground)
        }
    }

    // MARK: - Thumbnail Strip

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

    // MARK: - Invitation Actions

    private var invitationActions: some View {
        HStack(spacing: 10) {
            Button {
                onAccept?()
            } label: {
                Text("Accept")
                    .font(.portalLabelSemibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.portalPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            }
            .buttonStyle(.plain)

            Button {
                onDecline?()
            } label: {
                Text("Decline")
                    .font(.portalLabel)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.portalMuted.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            }
            .buttonStyle(.plain)
        }
    }
}
