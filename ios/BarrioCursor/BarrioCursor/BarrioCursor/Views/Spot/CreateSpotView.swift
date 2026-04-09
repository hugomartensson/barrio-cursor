import SwiftUI
import PhotosUI
import MapKit
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
    @State private var imageData: Data?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCameraSheet = false
    @State private var showCameraSettingsAlert = false
    @State private var showLocationPicker = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var isSubmitting = false
    @State private var submissionProgress: String?
    @State private var errorMessage: String?
    @State private var addressSuggestions: [MKMapItem] = []
    @State private var showAddressSuggestions = false
    @State private var suppressAddressSearch = false

    @FocusState private var focusedField: Field?
    private enum Field { case name, description, address }

    private var isFormValid: Bool {
        !name.isEmpty &&
        !description.isEmpty &&
        selectedCategory != nil &&
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
            let row1 = Array(categories.prefix(3))
            let row2 = Array(categories.dropFirst(3))
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

    // MARK: - Address (map pin + input — matches Create Event)
    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "mappin")
                    .font(.system(size: 16))
                    .foregroundColor(.portalPrimary)
                TextField("Address or venue name", text: $manualAddress)
                    .font(.portalBody)
                    .foregroundColor(.portalForeground)
                    .focused($focusedField, equals: .address)
                    .onSubmit { Task { await geocodeAddress() } }
                    .onChange(of: manualAddress) { _, _ in
                        if suppressAddressSearch { suppressAddressSearch = false; return }
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !manualAddress.isEmpty { searchAddresses() }
                            else { addressSuggestions = []; showAddressSuggestions = false }
                        }
                    }
            }
            .padding(.vertical, 4)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(focusedField == .address ? Color.portalPrimary : Color.portalBorder)
            if showAddressSuggestions && !addressSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(addressSuggestions.prefix(5).enumerated()), id: \.offset) { _, item in
                        Button {
                            selectAddressSuggestion(item)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 12))
                                    .foregroundColor(.portalMutedForeground)
                                Text(item.name ?? formatAddress(from: item))
                                    .font(.portalMetadata)
                                    .foregroundColor(.portalForeground)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
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
        .sheet(isPresented: $showLocationPicker) {
            LocationPickerView(
                initialLocation: selectedLocation ?? locationManager.coordinate,
                selectedLocation: $selectedLocation,
                onLocationSelected: { location in
                    Task {
                        do {
                            let address = try await locationManager.reverseGeocode(location)
                            suppressAddressSearch = true
                            manualAddress = address
                        } catch { }
                    }
                }
            )
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
        selectedLocation = locationManager.coordinate
        Task {
            do {
                let address = try await locationManager.reverseGeocode(locationManager.coordinate)
                suppressAddressSearch = true
                manualAddress = address
            } catch { }
        }
    }

    private func searchAddresses() {
        guard !manualAddress.isEmpty else {
            addressSuggestions = []
            showAddressSuggestions = false
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = manualAddress
        request.resultTypes = .address
        if let location = selectedLocation ?? locationManager.location?.coordinate {
            request.region = MKCoordinateRegion(
                center: location,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            Task { @MainActor in
                if let response = response {
                    addressSuggestions = response.mapItems
                    showAddressSuggestions = !response.mapItems.isEmpty
                } else {
                    addressSuggestions = []
                    showAddressSuggestions = false
                }
            }
        }
    }

    private func selectAddressSuggestion(_ item: MKMapItem) {
        selectedLocation = item.placemark.location?.coordinate ?? CLLocationCoordinate2D()
        suppressAddressSearch = true
        manualAddress = formatAddress(from: item)
        addressSuggestions = []
        showAddressSuggestions = false
    }

    private func formatAddress(from item: MKMapItem) -> String {
        let p = item.placemark
        var components: [String] = []
        if let n = p.subThoroughfare, let s = p.thoroughfare {
            components.append("\(n) \(s)")
        } else if let s = p.thoroughfare {
            components.append(s)
        }
        if let city = p.locality { components.append(city) }
        return components.isEmpty ? (item.name ?? "") : components.joined(separator: ", ")
    }

    private func geocodeAddress() async {
        guard !manualAddress.isEmpty else { return }
        errorMessage = nil
        do {
            let coordinate = try await locationManager.geocodeAddress(manualAddress)
            selectedLocation = coordinate
            showAddressSuggestions = false
        } catch {
            errorMessage = "Could not find location for address. Please try a more specific address."
        }
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
            errorMessage = "Please enter an address"
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
                neighborhood: nil,
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
