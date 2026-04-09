import SwiftUI
import PhotosUI

/// Empty-state cover: single “Add cover image” tap → Take photo / Choose from library.
/// (Do not nest `PhotosPicker` inside `Menu` — that breaks library selection on device.)
struct PortalCoverImagePickerEmptyState: View {
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let aspectRatio: CGFloat
    let onCameraTap: () -> Void

    @State private var showSourceChooser = false
    @State private var showLibrarySheet = false

    var body: some View {
        Button {
            showSourceChooser = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.portalPrimary)
                Text("Add cover image")
                    .font(.portalBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.portalPrimary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .background(Color.portalPrimary.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(.portalPrimary.opacity(0.4))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog("Add cover image", isPresented: $showSourceChooser, titleVisibility: .visible) {
            Button("Take photo") {
                onCameraTap()
            }
            Button("Choose from library") {
                showLibrarySheet = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLibrarySheet) {
            NavigationStack {
                VStack(spacing: 20) {
                    PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 1, matching: .images) {
                        Label("Select a photo", systemImage: "photo.on.rectangle")
                            .font(.portalLabelSemibold)
                            .foregroundColor(.portalPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.portalCard)
                            .clipShape(RoundedRectangle(cornerRadius: CGFloat.portalRadiusSm))
                            .overlay(
                                RoundedRectangle(cornerRadius: CGFloat.portalRadiusSm)
                                    .stroke(Color.portalBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .padding(.portalPagePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.portalBackground)
                .navigationTitle("Photo library")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showLibrarySheet = false }
                            .foregroundColor(.portalPrimary)
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPhotoItems) { _, new in
            if !new.isEmpty {
                showLibrarySheet = false
            }
        }
    }
}
