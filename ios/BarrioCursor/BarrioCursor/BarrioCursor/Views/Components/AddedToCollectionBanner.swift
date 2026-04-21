import SwiftUI

/// Top banner shown after a spot or event is added to a collection.
/// Auto-dismissed after 5 seconds; the parent controls visibility via a binding to an optional `AddedInfo`.
struct AddedToCollectionBanner: View {
    @EnvironmentObject var authManager: AuthManager

    let info: AddedToCollectionInfo
    /// Called to dismiss the banner (from parent or after undo).
    let onDismiss: () -> Void
    /// Called when user taps "View" to navigate to the collection.
    let onGoToCollection: () -> Void

    @State private var isUndoing = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.portalPrimary)
                .font(.system(size: 15))

            Text("Added to \(info.collectionName)")
                .font(.portalLabel)
                .foregroundColor(.portalForeground)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 4)

            if isUndoing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Undo") {
                    Task { await performUndo() }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.portalMutedForeground)
                .buttonStyle(.plain)

                Rectangle()
                    .fill(Color.portalBorder)
                    .frame(width: 1, height: 14)

                Button("View") {
                    onGoToCollection()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.portalPrimary)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.portalBorder)
                .frame(height: 0.5)
        }
        .task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            onDismiss()
        }
    }

    private func performUndo() async {
        guard let token = authManager.token else {
            onDismiss()
            return
        }
        isUndoing = true
        _ = try? await APIService.shared.removeItemFromCollection(
            collectionId: info.collectionId,
            itemId: info.itemId,
            token: token
        )
        isUndoing = false
        onDismiss()
    }
}

struct AddedToCollectionInfo: Identifiable, Equatable {
    var id: String { collectionId + "_" + itemId }
    let collectionId: String
    let collectionName: String
    let itemId: String
    let itemType: String
}
