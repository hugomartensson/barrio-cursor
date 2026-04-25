import SwiftUI

/// Shows collections that contain this spot or event, visible to the current user.
struct CollectionsContainingSection: View {
    let itemType: String  // "spot" | "event"
    let itemId: String

    @EnvironmentObject var authManager: AuthManager
    @State private var collections: [CollectionData] = []
    @State private var isLoading = true
    @State private var selectedCollection: CollectionRoute? = nil

    private var headerTitle: String {
        "COLLECTIONS WITH THIS \(itemType.uppercased())"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headerTitle)
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else if collections.isEmpty {
                Text("Not part of any collection yet")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .portalCardGap) {
                        ForEach(collections.map { PortalCollectionItem(from: $0) }) { item in
                            Button {
                                selectedCollection = CollectionRoute(id: item.id, name: item.title)
                            } label: {
                                PortalCollectionCard(
                                    collection: item,
                                    isSaved: false,
                                    onSaveToggle: nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -.portalPagePadding)
                .frame(height: 300)
            }
        }
        .task { await load() }
        .navigationDestination(isPresented: Binding(
            get: { selectedCollection != nil },
            set: { if !$0 { selectedCollection = nil } }
        )) {
            if let route = selectedCollection {
                CollectionDetailView(collectionId: route.id, name: route.name)
                    .environmentObject(authManager)
            }
        }
    }

    private func load() async {
        guard let token = authManager.token else { isLoading = false; return }
        do {
            let response: CollectionsListResponse
            if itemType == "spot" {
                response = try await APIService.shared.getSpotCollections(spotId: itemId, token: token)
            } else {
                response = try await APIService.shared.getEventCollections(eventId: itemId, token: token)
            }
            await MainActor.run {
                collections = response.data
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
