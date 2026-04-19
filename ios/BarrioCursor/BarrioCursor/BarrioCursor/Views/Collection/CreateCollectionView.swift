import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

/// Visibility for a new collection (Private / Friends / Public).
private enum CreateCollectionVisibility: String, CaseIterable {
    case private_ = "private"
    case friends = "friends"
    case public_ = "public"
    var label: String {
        switch self {
        case .private_: return "Private"
        case .friends: return "Friends"
        case .public_: return "Public"
        }
    }
}

/// New collection screen — metadata only (name, description, category). No spot/event selection; add items later from detail pages.
struct CreateCollectionView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    /// When set, form submits as PATCH /collections/:id (edit mode).
    var collectionToEdit: CollectionData? = nil
    /// Called after successful update in edit mode (e.g. reload detail).
    var onUpdated: (() -> Void)? = nil
    /// Called after successful create (no new id).
    var onCreated: (() -> Void)?
    /// Called after successful create with the new collection id (e.g. to add current item and dismiss).
    var onCreatedWithId: ((String) -> Void)?

    @State private var name = ""
    @State private var description = ""
    @State private var selectedCategory: EventCategory?
    @State private var visibility: CreateCollectionVisibility = .private_
    @State private var imageData: Data?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCameraSheet = false
    @State private var showCameraSettingsAlert = false
    @State private var isSubmitting = false
    @State private var submissionProgress: String?
    @State private var errorMessage: String?
    @State private var savedSpots: [SavedSpotEntry] = []
    @State private var selectedSavedSpotIds: Set<String> = []
    @State private var isLoadingSavedSpots = false
    /// Edit mode: user tapped remove on the existing server cover (PATCH clears cover).
    @State private var removedExistingCoverImage = false

    @FocusState private var focusedField: Field?
    private enum Field { case name, description }

    private var isFormValid: Bool {
        let hasBasics = !name.isEmpty && !description.isEmpty
        if collectionToEdit != nil {
            return hasBasics
        }
        return hasBasics && selectedCategory != nil
    }

    private static let maxContentWidth: CGFloat = 512

    // MARK: - Sticky header
    private var stickyHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.portalForeground)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(collectionToEdit == nil ? "New Collection" : "Edit Collection")
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.portalBorder)
        }
    }

    // MARK: - Cover image (4:1 aspect — shorter dashed area so name field sits higher)
    private var coverImageSection: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4/1, contentMode: .fit)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        imageData = nil
                        selectedPhotoItems = []
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.portalForeground.opacity(0.6)))
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4/1, contentMode: .fit)
            } else if collectionToEdit != nil, !removedExistingCoverImage,
                      let url = MediaURL.httpsURL(from: collectionToEdit?.coverImageURL) {
                ZStack(alignment: .topTrailing) {
                    CachedRemoteImage(
                        url: url,
                        placeholder: {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .aspectRatio(4/1, contentMode: .fit)
                                .overlay { ProgressView() }
                        },
                        failure: {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .aspectRatio(4/1, contentMode: .fit)
                        }
                    )
                    .aspectRatio(4/1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    Button {
                        removedExistingCoverImage = true
                        selectedPhotoItems = []
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.portalForeground.opacity(0.6)))
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(4/1, contentMode: .fit)
            } else {
                PortalCoverImagePickerEmptyState(
                    selectedPhotoItems: $selectedPhotoItems,
                    aspectRatio: 4 / 1,
                    onCameraTap: { showImageSourcePicker() }
                )
            }
        }
    }

    private func showImageSourcePicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = "Camera is not available on this device."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraSheet = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        showCameraSheet = true
                    } else {
                        showCameraSettingsAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraSettingsAlert = true
        @unknown default:
            break
        }
    }

    // MARK: - Name / Description (borderless, bottom border only)
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                "",
                text: $name,
                prompt: Text("Collection name")
                    .font(.portalDisplay22)
                    .foregroundColor(Color.portalForeground.opacity(0.42))
            )
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
                .focused($focusedField, equals: .name)
                .accessibilityIdentifier("title")
            Rectangle()
                .frame(height: 1)
                .foregroundColor(focusedField == .name ? Color.portalPrimary : Color.portalBorder)
        }
        .padding(.vertical, 8)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("What's this collection about?")
                        .font(.portalBody)
                        .foregroundColor(.portalMutedForeground)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $description)
                    .font(.portalBody)
                    .foregroundColor(.portalForeground)
                    .focused($focusedField, equals: .description)
                    .accessibilityIdentifier("description")
                    .frame(minHeight: 80)
                    .padding(.leading, 0)
                    .padding(.top, 4)
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(focusedField == .description ? Color.portalPrimary : Color.portalBorder)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Category pills (same as Create Event)
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CATEGORY")
                .font(.portalSectionLabel)
                .tracking(0.5)
                .foregroundColor(.portalMutedForeground)
            let categories = Array(EventCategory.allCases)
            let row1 = Array(categories.prefix(4))
            let row2 = Array(categories.dropFirst(4))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(row1, id: \.self) { category in
                        categoryPill(category)
                    }
                }
                HStack(spacing: 8) {
                    ForEach(row2, id: \.self) { category in
                        categoryPill(category)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func categoryPill(_ category: EventCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(category.displayName)
                .font(.portalCategoryPill)
                .foregroundColor(selectedCategory == category ? .portalPrimaryForeground : .portalForeground)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? Color.portalPrimary : Color.portalCard)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.portalBorder, lineWidth: selectedCategory == category ? 0 : 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visibility")
                .font(.portalSectionLabel)
                .tracking(0.18)
                .foregroundColor(.portalMutedForeground)
            HStack(spacing: 8) {
                ForEach(CreateCollectionVisibility.allCases, id: \.rawValue) { option in
                    Button {
                        visibility = option
                    } label: {
                        Text(option.label)
                            .font(.portalMetadata)
                            .foregroundColor(visibility == option ? .portalPrimaryForeground : .portalForeground)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(visibility == option ? Color.portalPrimary : Color.portalCard)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.portalBorder, lineWidth: visibility == option ? 0 : 1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var scrollFormContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            coverImageSection
            nameSection
            descriptionSection
            categorySection
            visibilitySection
            if let error = errorMessage {
                Text(error)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
                    .padding(.top, 4)
            }
            Color.clear.frame(height: 100)
        }
        .padding(.horizontal, .portalPagePadding)
        .frame(maxWidth: Self.maxContentWidth)
        .frame(maxWidth: .infinity)
        .scrollDismissesKeyboard(.interactively)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.portalBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                stickyHeader
                ScrollView {
                    scrollFormContent
                }
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.portalBackground.opacity(0), Color.portalBackground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                    Button {
                        Task { await submitCollection() }
                    } label: {
                        Text(collectionToEdit == nil ? "Create Collection" : "Save Changes")
                            .font(.portalLabel)
                            .foregroundColor(isFormValid && !isSubmitting ? .portalPrimaryForeground : .portalMutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid && !isSubmitting ? Color.portalPrimary : Color.portalMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: isFormValid && !isSubmitting ? Color.portalPrimary.opacity(0.35) : .clear, radius: 4, x: 0, y: 2)
                    }
                    .disabled(!isFormValid || isSubmitting)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("create")
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                    .frame(maxWidth: Self.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.portalBackground)
            }
        }
        .sheet(isPresented: $showCameraSheet) {
            ImagePicker(
                sourceType: .camera,
                onImageSelected: { image in
                    if let jpegData = image.jpegData(compressionQuality: 0.8) {
                        imageData = jpegData
                    } else {
                        errorMessage = "Failed to process image"
                    }
                }
            )
        }
        .alert("Camera access", isPresented: $showCameraSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Camera access is needed to take photos. You can enable it in Settings → Privacy → Camera.")
        }
        .overlay {
            if isSubmitting, let progress = submissionProgress {
                VStack(spacing: 24) {
                    ProgressView().scaleEffect(1.0).tint(.portalPrimary)
                    Text(progress)
                        .font(.portalBody)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.ultraThinMaterial)
            }
        }
        .onChange(of: selectedPhotoItems) { _, newValue in
            Task {
                guard let item = newValue.first else {
                    imageData = nil
                    return
                }
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpegData = image.jpegData(compressionQuality: 0.8) {
                    imageData = jpegData
                } else {
                    imageData = nil
                }
            }
        }
        .task {
            await loadSavedSpotsForPicker()
        }
        .onAppear {
            guard let c = collectionToEdit else { return }
            name = c.name
            description = c.description ?? ""
            if let v = c.visibility, let vis = CreateCollectionVisibility(rawValue: v) {
                visibility = vis
            }
            selectedCategory = EventCategory.allCases.first
        }
    }

    private func loadSavedSpotsForPicker() async {
        guard let token = authManager.token, !token.isEmpty else { return }
        isLoadingSavedSpots = true
        defer { isLoadingSavedSpots = false }
        do {
            let response = try await APIService.shared.getSavedSpots(token: token)
            savedSpots = response.data
        } catch {
            savedSpots = []
        }
    }

    /// Resize + compress an image for cover upload. Target: 1280 px wide max, quality 0.75.
    /// Keeps the payload well under 1 MB as base64.
    private func prepareImageForUpload(_ image: UIImage) -> Data? {
        let maxWidth: CGFloat = 1280
        let scale = image.size.width > maxWidth ? maxWidth / image.size.width : 1.0
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func submitCollection() async {
        guard let token = authManager.token else {
            errorMessage = "Not authenticated"
            return
        }
        isSubmitting = true
        submissionProgress = collectionToEdit == nil ? "Creating…" : "Saving…"
        errorMessage = nil
        defer { isSubmitting = false; submissionProgress = nil }
        do {
            var coverURL: String?
            if let raw = imageData, let uiImage = UIImage(data: raw),
               let jpegData = prepareImageForUpload(uiImage) {
                submissionProgress = "Uploading cover…"
                let b64 = jpegData.base64EncodedString()
                coverURL = try await APIService.shared.uploadImage(
                    base64Image: b64,
                    contentType: "image/jpeg",
                    token: token
                )
            }

            if let edit = collectionToEdit {
                submissionProgress = "Saving…"
                let clearCover = removedExistingCoverImage && coverURL == nil
                _ = try await APIService.shared.updateCollection(
                    id: edit.id,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    visibility: visibility.rawValue,
                    coverImageUrl: coverURL,
                    clearCoverImage: clearCover,
                    token: token
                )
                onUpdated?()
                dismiss()
                return
            }

            submissionProgress = "Creating…"
            let response = try await APIService.shared.createCollection(
                name: name,
                description: description.isEmpty ? nil : description,
                visibility: visibility.rawValue,
                coverImageURL: coverURL,
                token: token
            )
            let newId = response.data.id
            for spotId in selectedSavedSpotIds {
                do {
                    _ = try await APIService.shared.addItemToCollection(
                        collectionId: newId,
                        itemType: "spot",
                        itemId: spotId,
                        token: token
                    )
                } catch {
                    // Continue adding other spots if one fails
                }
            }
            if let onCreatedWithId = onCreatedWithId {
                onCreatedWithId(newId)
            } else {
                onCreated?()
            }
            dismiss()
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Add to Collection (event/spot detail → pick collection or create new)
struct AddToCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    let itemType: String
    let itemId: String
    /// Called with the collection name when the item is successfully added.
    var onAdded: ((_ collectionName: String) -> Void)?

    @State private var collections: [CollectionData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateCollection = false
    @State private var addingToId: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading collections…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Button {
                                showCreateCollection = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.portalPrimary)
                                    Text("Create new collection")
                                        .font(.portalLabel)
                                        .foregroundColor(.portalForeground)
                                }
                            }
                            .accessibilityIdentifier("create_new_collection")
                        }
                        Section {
                            ForEach(collections.filter { $0.owned == true }) { col in
                                Button {
                                    Task { await addItem(to: col.id) }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(col.name)
                                                .font(.portalBody)
                                                .foregroundColor(.portalForeground)
                                            if let count = col.itemCount {
                                                Text("\(count) items")
                                                    .font(.portalMetadata)
                                                    .foregroundColor(.portalMutedForeground)
                                            }
                                        }
                                        Spacer()
                                        if addingToId == col.id {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                                .disabled(addingToId != nil)
                            }
                        } header: {
                            Text("Your collections")
                                .font(.portalSectionLabel)
                                .foregroundColor(.portalMutedForeground)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Add to collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task { await loadCollections() }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionView(onCreatedWithId: { newId in
                    showCreateCollection = false
                    Task {
                        await addItem(to: newId)
                    }
                })
                .environmentObject(authManager)
            }
            .overlay(alignment: .bottom) {
                if let msg = errorMessage {
                    Text(msg)
                        .font(.portalMetadata)
                        .foregroundColor(.portalDestructive)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.portalBackground)
                }
            }
        }
    }

    private func loadCollections() async {
        guard let token = authManager.token else { return }
        isLoading = true
        errorMessage = nil
        do {
            let response = try await APIService.shared.getCollections(token: token)
            collections = response.data
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func addItem(to collectionId: String) async {
        guard let token = authManager.token else { return }
        addingToId = collectionId
        errorMessage = nil
        let collectionName = collections.first(where: { $0.id == collectionId })?.name ?? "collection"
        do {
            _ = try await APIService.shared.addItemToCollection(collectionId: collectionId, itemType: itemType, itemId: itemId, token: token)
            await MainActor.run {
                onAdded?(collectionName)
                dismiss()
            }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        addingToId = nil
    }
}

#Preview("Create Collection") {
    CreateCollectionView()
        .environmentObject(AuthManager())
}
