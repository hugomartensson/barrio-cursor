import SwiftUI
import PhotosUI
import CoreLocation
import AVFoundation
import UIKit

struct CreateSpotView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var onSpotSaved: () -> Void = {}

    @State private var name = ""
    @State private var description = ""
    @State private var selectedCategory: EventCategory?
    @State private var manualAddress = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedNeighborhood: String?
    @State private var imageData: Data?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCameraSheet = false
    @State private var showCameraSettingsAlert = false
    @State private var showLocationPicker = false
    @State private var showLocationSearch = false
    @State private var isSubmitting = false
    @State private var submissionProgress: String?
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field { case name, description }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !description.isEmpty &&
        selectedCategory != nil &&
        selectedLocation != nil &&
        !manualAddress.isEmpty &&
        imageData != nil
    }

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
            Text("New Spot")
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

    // MARK: - Cover image (16:9, dashed border — matches Create Event design)
    private var coverImageSection: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16/6, contentMode: .fit)
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
                .aspectRatio(16/6, contentMode: .fit)
            } else {
                PortalCoverImagePickerEmptyState(
                    selectedPhotoItems: $selectedPhotoItems,
                    aspectRatio: 16 / 6,
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
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            showCameraSheet = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted { showCameraSheet = true }
                    else { showCameraSettingsAlert = true }
                }
            }
        case .denied, .restricted:
            showCameraSettingsAlert = true
        @unknown default:
            break
        }
    }

    // MARK: - Name / Description (borderless, bottom border only — matches Create Event)
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Spot name", text: $name)
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
            Text("DESCRIPTION")
                .font(.portalSectionLabel)
                .tracking(0.5)
                .foregroundColor(.portalMutedForeground)
            ZStack(alignment: .topLeading) {
                if description.isEmpty {
                    Text("What's this spot about?")
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

    // MARK: - Category pills (wrapping — same as Create Event)
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

    // MARK: - Address (federated search via LocationSearchField)
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showLocationSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "mappin")
                        .font(.system(size: 16))
                        .foregroundColor(.portalPrimary)
                    if manualAddress.isEmpty {
                        Text("Search address or venue")
                            .font(.portalBody)
                            .foregroundColor(.portalMutedForeground)
                    } else {
                        Text(manualAddress)
                            .font(.portalBody)
                            .foregroundColor(.portalForeground)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.portalMutedForeground)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.portalBorder)
            if !locationManager.isLocationDenied {
                Button {
                    showLocationPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 14))
                        Text(selectedLocation != nil ? "Adjust on map" : "Pick location on map")
                            .font(.portalMetadata)
                    }
                    .foregroundColor(.portalPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    /// Max content width on wider screens (matches Create Event — design system max-w-lg)
    private static let maxContentWidth: CGFloat = 512

    // MARK: - Scrollable form content
    private var scrollFormContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            coverImageSection
            nameSection
            descriptionSection
            categorySection
            addressSection
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
                // Fixed publish button with gradient fade (matches Create Event)
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.portalBackground.opacity(0), Color.portalBackground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                    Button {
                        Task { await publishSpot() }
                    } label: {
                        Text("Publish Spot")
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
        .sheet(isPresented: $showLocationSearch) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("LOCATION")
                        .font(.portalSectionLabel)
                        .tracking(0.5)
                        .foregroundColor(.portalMutedForeground)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    LocationSearchField(
                        biasCenter: locationManager.realCoordinate,
                        placeholder: "Search address or venue",
                        onUseCurrentLocation: {
                            Task {
                                if let coord = locationManager.location?.coordinate {
                                    selectedLocation = coord
                                    if let addr = try? await locationManager.reverseGeocode(coord) {
                                        manualAddress = addr
                                    }
                                    selectedNeighborhood = nil
                                }
                                showLocationSearch = false
                            }
                        },
                        onSelect: { resolved in
                            manualAddress = resolved.formattedAddress
                            selectedLocation = resolved.coordinate
                            selectedNeighborhood = resolved.neighborhood
                            showLocationSearch = false
                        }
                    )
                    .padding(.horizontal, .portalPagePadding)
                    Spacer()
                }
                .background(Color.portalBackground.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showLocationSearch = false }
                    }
                }
            }
            .environmentObject(authManager)
            .environmentObject(locationManager)
        }
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                initialLocation: selectedLocation ?? locationManager.coordinate,
                selectedLocation: $selectedLocation,
                onLocationSelected: { location in
                    Task {
                        do {
                            let address = try await locationManager.reverseGeocode(location)
                            manualAddress = address
                        } catch { }
                    }
                }
            )
            .environmentObject(locationManager)
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
        .onAppear { populateInitialLocation() }
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
    }

    private func populateInitialLocation() {
        guard !locationManager.isLocationDenied else { return }
        locationManager.requestLocationIfNeeded()
    }

    private func publishSpot() async {
        guard let token = authManager.token else {
            errorMessage = "Not authenticated"
            return
        }
        guard let imageData = imageData else {
            errorMessage = "Please add an image"
            return
        }
        guard !manualAddress.isEmpty else {
            errorMessage = "Please search for and select a location"
            return
        }

        isSubmitting = true
        submissionProgress = "Preparing..."
        errorMessage = nil
        defer { isSubmitting = false; submissionProgress = nil }

        do {
            submissionProgress = "Uploading image..."
            let urls = try await StorageService.shared.uploadImages([imageData], token: token)
            let imageURL = urls.first ?? ""

            submissionProgress = "Creating spot..."
            _ = try await APIService.shared.createSpot(
                name: name,
                description: description,
                category: (selectedCategory ?? .community).rawValue,
                address: manualAddress,
                imageURL: imageURL,
                imageThumbnailURL: nil,
                neighborhood: selectedNeighborhood,
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                token: token
            )
            NotificationCenter.default.post(name: NSNotification.Name("SpotCreated"), object: nil)
            onSpotSaved()
            dismiss()
        } catch let error as StorageError {
            errorMessage = error.errorDescription
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to create spot: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CreateSpotView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
}
