import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import AVFoundation
import UIKit

struct CreateEventView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    let eventToEdit: Event?
    let initialLocation: CLLocationCoordinate2D?
    let onEventSaved: () -> Void

    init(eventToEdit: Event? = nil, initialLocation: CLLocationCoordinate2D? = nil, onEventSaved: @escaping () -> Void = {}) {
        self.eventToEdit = eventToEdit
        self.initialLocation = initialLocation
        self.onEventSaved = onEventSaved
    }

    // Form fields
    @State private var title = ""
    @State private var description = ""
    @State private var selectedCategory: EventCategory?
    @State private var startDate = CreateEventView.defaultStartDate()
    @State private var endDate = CreateEventView.defaultStartDate().addingTimeInterval(3 * 60 * 60)
    @State private var imageData: Data?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCameraSheet = false
    @State private var showCameraSettingsAlert = false
    @State private var showLocationPicker = false
    @State private var showLocationSearch = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var manualAddress = ""
    @State private var selectedNeighborhood: String?
    @State private var selectedSpotId: String?
    @State private var isSubmitting = false
    @State private var submissionProgress: String?
    @State private var errorMessage: String?

    private var isEditMode: Bool { eventToEdit != nil }

    @State private var showDatePicker = false
    @State private var showStartTimePicker = false
    @State private var showEndTimePicker = false
    @FocusState private var focusedField: Field?
    private enum Field { case title, description }

    private var isFormValid: Bool {
        !title.isEmpty &&
        !description.isEmpty &&
        selectedCategory != nil &&
        selectedLocation != nil &&
        !manualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        imageData != nil &&
        endDate > startDate
    }

    private static let timeSlots: [(hour: Int, minute: Int)] = (9..<24).flatMap { h in [(h, 0), (h, 30)] }

    private func timeString(hour: Int, minute: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        guard let d = Calendar.current.date(from: comps) else { return "\(hour):\(minute)" }
        return formatter.string(from: d)
    }

    private func dateFromTimeSlot(_ slot: (hour: Int, minute: Int), on date: Date) -> Date {
        Calendar.current.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: date) ?? date
    }

    // MARK: - Sticky header (spec)
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
            Text(isEditMode ? "Edit Event" : "New Event")
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

    // MARK: - Cover image (16:9, dashed border, design system)
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

    // MARK: - Title / Description (borderless, bottom border only)
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Event title", text: $title)
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
                .focused($focusedField, equals: .title)
                .accessibilityIdentifier("title")
            Rectangle()
                .frame(height: 1)
                .foregroundColor(focusedField == .title ? Color.portalPrimary : Color.portalBorder)
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
                    Text("What's this event about?")
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

    // MARK: - Category pills (wrapping: two rows)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manualAddress)
                                .font(.portalBody)
                                .foregroundColor(.portalForeground)
                                .lineLimit(2)
                            if let spotId = selectedSpotId, !spotId.isEmpty {
                                Label("Barrio Spot", systemImage: "mappin.circle.fill")
                                    .font(.portalMetadata)
                                    .foregroundColor(.portalPrimary)
                            }
                        }
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

    // MARK: - When (date + start/end time slots)
    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHEN")
                .font(.portalSectionLabel)
                .tracking(0.5)
                .foregroundColor(.portalMutedForeground)
            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(.portalPrimary)
                    Text(dateFormatted(startDate))
                        .font(.portalBody)
                        .foregroundColor(Calendar.current.isDateInToday(startDate) && startDate.timeIntervalSinceNow < 0 ? .portalMutedForeground : .portalForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .background(Color.portalCard)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.portalBorder, lineWidth: 1))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.portalPrimary.opacity(0.5), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            HStack(spacing: 12) {
                Button {
                    showStartTimePicker = true
                } label: {
                    whenButtonLabel(icon: "clock", text: startTimeFormatted, isPlaceholder: false, iconMuted: false)
                }
                .buttonStyle(.plain)
                Button {
                    showEndTimePicker = true
                } label: {
                    whenButtonLabel(icon: "clock", text: endTimeFormatted, isPlaceholder: false, iconMuted: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private func dateFormatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private var startTimeFormatted: String {
        let c = Calendar.current
        let h = c.component(.hour, from: startDate)
        let m = c.component(.minute, from: startDate)
        return timeString(hour: h, minute: m)
    }

    private var endTimeFormatted: String {
        let c = Calendar.current
        let h = c.component(.hour, from: endDate)
        let m = c.component(.minute, from: endDate)
        return timeString(hour: h, minute: m)
    }

    private func whenButtonLabel(icon: String, text: String, isPlaceholder: Bool, iconMuted: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconMuted ? Color.portalMutedForeground : Color.portalPrimary)
            Text(text)
                .font(.portalBody)
                .foregroundColor(isPlaceholder ? .portalMutedForeground : .portalForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(Color.portalCard)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.portalBorder, lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.portalPrimary.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    /// Max content width on wider screens (e.g. iPad) — design system max-w-lg
    private static let maxContentWidth: CGFloat = 512

    // MARK: - Scrollable form content
    private var scrollFormContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            coverImageSection
            titleSection
            descriptionSection
            categorySection
            addressSection
            whenSection
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
                // Fixed publish button with gradient fade (design system)
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.portalBackground.opacity(0), Color.portalBackground], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                    Button {
                        Task {
                            if isEditMode { await updateEvent() }
                            else { await createEvent() }
                        }
                    } label: {
                        Text(isEditMode ? "Save Changes" : "Publish Event")
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
                                    selectedSpotId = nil
                                }
                                showLocationSearch = false
                            }
                        },
                        onSelect: { resolved in
                            manualAddress = resolved.formattedAddress
                            selectedLocation = resolved.coordinate
                            selectedNeighborhood = resolved.neighborhood
                            selectedSpotId = resolved.spotId
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
                            selectedSpotId = nil
                        } catch {
                            #if DEBUG
                            print("⚠️ CreateEventView: Failed to reverse geocode: \(error)")
                            #endif
                        }
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
        .sheet(isPresented: $showDatePicker) {
            datePickerSheet
        }
        .sheet(isPresented: $showStartTimePicker) {
            timeSlotSheet(isStart: true)
        }
        .sheet(isPresented: $showEndTimePicker) {
            timeSlotSheet(isStart: false)
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
        .onAppear { populateInitialState() }
        .onChange(of: selectedPhotoItems) { (_: [PhotosPickerItem], newValue: [PhotosPickerItem]) in
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
        .onChange(of: startDate) { _, _ in
            if endDate <= startDate {
                endDate = startDate.addingTimeInterval(3 * 60 * 60)
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("Date", selection: Binding(
                get: { startDate },
                set: { newDate in
                    let cal = Calendar.current
                    let startOfDay = cal.startOfDay(for: newDate)
                    let h = cal.component(.hour, from: startDate)
                    let m = cal.component(.minute, from: startDate)
                    startDate = cal.date(bySettingHour: h, minute: m, second: 0, of: startOfDay) ?? startOfDay
                    if endDate < startDate {
                        endDate = cal.date(byAdding: .hour, value: 3, to: startDate) ?? startDate
                    }
                }
            ), in: Date()..., displayedComponents: .date)
            .datePickerStyle(.graphical)
            .navigationTitle("Pick a date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
    }

    private func timeSlotSheet(isStart: Bool) -> some View {
        let binding = isStart
            ? Binding(get: { startDate }, set: { startDate = $0; if endDate <= startDate { endDate = startDate.addingTimeInterval(3 * 60 * 60) } })
            : Binding(get: { endDate }, set: { endDate = $0 })
        let title = isStart ? "Start" : "End"
        return NavigationStack {
            List {
                ForEach(Array(CreateEventView.timeSlots.enumerated()), id: \.offset) { _, slot in
                    let date = dateFromTimeSlot(slot, on: startDate)
                    Button {
                        binding.wrappedValue = date
                        if isStart { showStartTimePicker = false }
                        else { showEndTimePicker = false }
                    } label: {
                        HStack {
                            Text(timeString(hour: slot.hour, minute: slot.minute))
                                .font(.portalBody)
                                .foregroundColor(.portalForeground)
                            Spacer()
                            if abs(binding.wrappedValue.timeIntervalSince(date)) < 60 {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.portalPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isStart { showStartTimePicker = false }
                        else { showEndTimePicker = false }
                    }
                }
            }
        }
    }

    private func populateInitialState() {
        if let event = eventToEdit {
            title = event.title
            description = event.description
            selectedCategory = event.category
            startDate = event.startTime
            endDate = event.endTime ?? event.startTime.addingTimeInterval(3 * 60 * 60)
            selectedLocation = event.coordinate
            manualAddress = event.address
            if let firstMedia = event.media.first, let url = URL(string: firstMedia.url) {
                Task {
                    if let (data, _) = try? await URLSession.shared.data(from: url) {
                        imageData = data
                    }
                }
            }
        } else {
            startDate = CreateEventView.defaultStartDate()
            endDate = startDate.addingTimeInterval(3 * 60 * 60)
            if let loc = initialLocation {
                selectedLocation = loc
            } else if !locationManager.isLocationDenied {
                selectedLocation = locationManager.coordinate
            }
        }
    }

    // MARK: - Create / Update

    private func createEvent() async {
        guard let token = authManager.token else {
            errorMessage = "Not authenticated"
            return
        }
        guard let location = selectedLocation else {
            errorMessage = "Please select a location"
            return
        }
        guard !manualAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter an address or venue name"
            return
        }
        guard let imageData = imageData else {
            errorMessage = "Please add an image"
            return
        }
        guard endDate > startDate else {
            errorMessage = "End time must be after start time."
            return
        }

        isSubmitting = true
        submissionProgress = "Preparing..."
        errorMessage = nil
        defer { isSubmitting = false; submissionProgress = nil }

        do {
            submissionProgress = "Uploading image..."
            let urls = try await StorageService.shared.uploadImages([imageData], token: token)
            let mediaURLs: [(url: String, type: MediaType, thumbnailUrl: String?)] = urls.map { (url: $0, type: .photo, thumbnailUrl: nil) }

            guard let currentToken = authManager.token else {
                errorMessage = "Not authenticated"
                return
            }
            let address: String
            if !manualAddress.isEmpty {
                address = manualAddress
            } else {
                address = try await locationManager.reverseGeocode(location)
            }

            submissionProgress = "Creating event..."
            _ = try await APIService.shared.createEvent(
                title: title,
                description: description,
                category: selectedCategory ?? .community,
                address: address,
                neighborhood: selectedNeighborhood,
                latitude: selectedLocation?.latitude,
                longitude: selectedLocation?.longitude,
                spotId: selectedSpotId,
                startTime: startDate,
                endTime: endDate,
                mediaURLs: mediaURLs,
                token: currentToken
            )
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            dismiss()
        } catch let error as StorageError {
            errorMessage = error.errorDescription
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
        }
    }

    private func updateEvent() async {
        guard let event = eventToEdit else { return }
        guard let token = authManager.token else {
            errorMessage = "Not authenticated"
            return
        }
        guard let location = selectedLocation else {
            errorMessage = "Please select a location"
            return
        }
        guard endDate > startDate else {
            errorMessage = "End time must be after start time."
            return
        }
        guard let imageData = imageData else {
            errorMessage = "Please add an image"
            return
        }

        isSubmitting = true
        submissionProgress = "Preparing..."
        errorMessage = nil
        defer { isSubmitting = false; submissionProgress = nil }

        do {
            submissionProgress = "Uploading image..."
            let urls = try await StorageService.shared.uploadImages([imageData], token: token)
            let mediaInputs: [APIService.MediaInput] = urls.map { APIService.MediaInput(url: $0, type: MediaType.photo.rawValue, thumbnailUrl: nil) }

            let address: String
            if !manualAddress.isEmpty {
                address = manualAddress
            } else {
                address = try await locationManager.reverseGeocode(location)
            }

            submissionProgress = "Saving changes..."
            _ = try await APIService.shared.updateEvent(
                id: event.id,
                title: title,
                description: description,
                category: selectedCategory,
                address: address,
                startTime: startDate,
                endTime: endDate,
                media: mediaInputs,
                token: token
            )
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
            onEventSaved()
            dismiss()
        } catch let error as StorageError {
            errorMessage = error.errorDescription
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

// MARK: - Default date

extension CreateEventView {
    static func defaultStartDate(from date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
        return calendar.date(from: components) ?? nextHour
    }
}

// MARK: - Location picker

struct LocationPickerView: View {
    let initialLocation: CLLocationCoordinate2D
    @Binding var selectedLocation: CLLocationCoordinate2D?
    let onLocationSelected: ((CLLocationCoordinate2D) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationManager: LocationManager

    @State private var cameraPosition: MapCameraPosition
    @State private var pinLocation: CLLocationCoordinate2D

    init(initialLocation: CLLocationCoordinate2D, selectedLocation: Binding<CLLocationCoordinate2D?>, onLocationSelected: ((CLLocationCoordinate2D) -> Void)? = nil) {
        self.initialLocation = initialLocation
        self._selectedLocation = selectedLocation
        self.onLocationSelected = onLocationSelected
        let location = selectedLocation.wrappedValue ?? initialLocation
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
        _pinLocation = State(initialValue: location)
    }

    private func recenterOnUserLocation() {
        locationManager.requestLocationIfNeeded()
        let center = locationManager.coordinate
        pinLocation = center
        cameraPosition = .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition, interactionModes: .all) {
                    Marker("Event Location", coordinate: pinLocation)
                        .tint(Color.portalPrimary)
                }
                .onMapCameraChange { context in
                    pinLocation = context.region.center
                }
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.portalPrimary)
                if !locationManager.isLocationDenied {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            Button {
                                recenterOnUserLocation()
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.portalPrimary)
                                    .padding(12)
                                    .background(Circle().fill(.ultraThinMaterial))
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(16)
                            .accessibilityLabel("My location")
                        }
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        selectedLocation = pinLocation
                        onLocationSelected?(pinLocation)
                        dismiss()
                    }
                    .font(.portalLabel)
                    .foregroundColor(.portalPrimary)
                }
            }
        }
    }
}

// MARK: - Image picker

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageSelected: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageSelected: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageSelected = onImageSelected
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageSelected(image)
            } else {
                // Non-image (e.g. video) picked with images-only picker — ignore
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    CreateEventView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
}
