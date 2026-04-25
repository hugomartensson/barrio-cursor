import SwiftUI
import AVKit

struct EventDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let event: Event
    @State private var isSaved = false
    @State private var saveCount: Int
    @State private var showEditEvent = false
    @State private var showDeleteAlert = false
    @State private var showFullDescription = false
    @State private var showAddToCollection = false
    @State private var showSaveToPlan = false
    @State private var addedInfo: AddedToCollectionInfo? = nil
    @State private var collectionToShow: AddedToCollectionInfo? = nil
    @State private var addedToPlanInfo: AddedToPlanInfo? = nil
    // Persistent button labels — set on add, never cleared by banner dismissal
    @State private var planNameAdded: String? = nil
    @State private var collectionNameAdded: String? = nil
    @State private var showEventMap = false
    @State private var showFullScreenPhoto = false
    @State private var errorMessage: String? = nil
    @State private var cachedPlayers: [String: AVPlayer] = [:]

    private let heroAspectRatio: CGFloat = 4/3
    private let bodyVerticalSpacing: CGFloat = 20

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()

    init(event: Event, isSaved: Bool = false) {
        self.event = event
        _isSaved = State(initialValue: isSaved)
        _saveCount = State(initialValue: event.saveCount)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                bodySection
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.portalBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if let info = addedInfo {
                    AddedToCollectionBanner(
                        info: info,
                        onDismiss: { addedInfo = nil },
                        onGoToCollection: {
                            collectionToShow = info
                            addedInfo = nil
                        }
                    )
                    .environmentObject(authManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let planInfo = addedToPlanInfo {
                    AddedToPlanBanner(
                        info: planInfo,
                        onDismiss: { addedToPlanInfo = nil },
                        onViewPlan: { addedToPlanInfo = nil }
                    )
                    .environmentObject(authManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: addedInfo)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: addedToPlanInfo)
        .fullScreenCover(item: $collectionToShow) { info in
            NavigationStack {
                CollectionDetailView(collectionId: info.collectionId, name: info.collectionName)
                    .environmentObject(authManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { collectionToShow = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSaveToPlan) {
            SaveToPlanSheet(
                itemType: "event",
                itemId: event.id,
                itemTitle: event.title,
                itemCategory: event.category.displayName,
                itemImageURL: event.media.first?.thumbnailUrl ?? event.media.first?.url,
                eventStartTime: event.startTime,
                eventEndTime: event.endTime,
                onSaved: { info in
                    addedToPlanInfo = info
                    planNameAdded = info.planName
                }
            )
            .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showFullScreenPhoto) {
            ZStack {
                Color.black.ignoresSafeArea()
                if let urlStr = event.media.first?.url, let url = URL(string: urlStr) {
                    CachedRemoteImage(
                        url: url,
                        placeholder: { Color.black },
                        failure: { Color.black }
                    )
                    .scaledToFit()
                    .ignoresSafeArea()
                }
                Button { showFullScreenPhoto = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .padding(20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .sheet(isPresented: $showEditEvent) {
            CreateEventView(eventToEdit: event)
        }
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(itemType: "event", itemId: event.id, onAdded: { colId, colName in
                addedInfo = AddedToCollectionInfo(
                    collectionId: colId,
                    collectionName: colName,
                    itemId: event.id,
                    itemType: "event"
                )
                collectionNameAdded = colName
                showAddToCollection = false
            })
            .environmentObject(authManager)
        }
        .alert("Delete Event", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await deleteEvent() }
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
        }
        .sheet(isPresented: $showFullDescription) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(event.title)
                            .font(.title2.weight(.bold))
                            .padding(.horizontal)
                            .padding(.top)
                        
                        Divider()
                        
                        Text(event.description)
                            .font(.body)
                            .padding(.horizontal)
                            .padding(.bottom)
                    }
                }
                .navigationTitle("Event Description")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showFullDescription = false
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Hero (image to top, date on image, category, title)
    private var heroSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / heroAspectRatio
            let topInset = geo.safeAreaInsets.top
            ZStack(alignment: .top) {
                eventHeroImage
                    .frame(width: w, height: h + topInset)
                    .offset(y: -topInset)
                    .clipped()
                    .onTapGesture { showFullScreenPhoto = true }

                eventHeroGradient
                    .frame(width: w, height: h + topInset)
                    .offset(y: -topInset)
                    .allowsHitTesting(false)

                VStack {
                    eventHeroTopBar
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.top, 16 + geo.safeAreaInsets.top)
                    if event.isLive {
                        Text("• HAPPENING NOW")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.portalPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                            .padding(.top, 8)
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom) {
                        eventHeroBottomBlock
                        Spacer(minLength: 8)
                        Button { showEventMap = true } label: {
                            Image(systemName: "map.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.bottom, 16)
                }
                .frame(width: w, height: h)
            }
        }
        .aspectRatio(heroAspectRatio, contentMode: .fit)
        .fullScreenCover(isPresented: $showEventMap) {
            FocusedMapView(
                title: event.title,
                spots: [],
                events: [event],
                focusCoordinate: event.coordinate,
                showContentFilter: false
            )
            .environmentObject(authManager)
        }
    }

    private var eventHeroTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.portalForeground)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.portalBorder.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            if authManager.currentUser?.id == event.user.id {
                Menu {
                    Button {
                        showEditEvent = true
                    } label: {
                        Label("Edit Event", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.portalForeground)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.portalBorder.opacity(0.5), lineWidth: 1))
                }
            }
        }
    }

    /// Date on image (like event cards): SAT / 21 / FEB
    private var eventHeroBottomBlock: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(spacing: 0) {
                Text(Self.weekdayFormatter.string(from: event.startTime))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white)
                Text(Self.dayFormatter.string(from: event.startTime))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(Self.monthFormatter.string(from: event.startTime))
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.portalPrimary.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                Text(event.title)
                    .font(.portalDisplay22)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventHeroGradient: some View {
        Color.portalGradientOverlay
    }

    // MARK: - Body
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: bodyVerticalSpacing) {
            eventDateRow
            eventTimeRow
            eventLocationRow
            Text(event.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.portalForeground.opacity(0.85))
                .lineSpacing(4)
            eventCategoryTag
            DetailActionBar(
                itemType: "event",
                isSaved: isSaved,
                saveCount: saveCount,
                onSave: { Task { await toggleSave() } },
                onAddToPlan: { showSaveToPlan = true },
                onAddToCollection: {
                    addedInfo = nil
                    showAddToCollection = true
                },
                addedToPlanName: planNameAdded,
                addedToCollectionName: collectionNameAdded
            )
            Divider().background(Color.portalBorder)
            CollectionsContainingSection(itemType: "event", itemId: event.id)
                .environmentObject(authManager)
            Divider().background(Color.portalBorder)
            SavedByRow(itemType: "event", itemId: event.id)
                .environmentObject(authManager)
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var eventDateRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(event.startTime, style: .date)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
        }
    }

    private var eventTimeRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(event.startTime, style: .time)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            if event.isLive {
                Text("IN PROGRESS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.portalPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
            }
        }
    }

    private var eventLocationRow: some View {
        let locationLine = AddressFormatting.detailLocationLine(
            neighborhood: event.neighborhood,
            address: event.address
        )
        return HStack(spacing: 8) {
            Image(systemName: "mappin")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(locationLine.isEmpty ? event.displayCity : locationLine)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
                .lineLimit(2)
        }
    }

    private var eventCategoryTag: some View {
        Text(event.category.displayName)
            .font(.portalSectionLabel)
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(hex: event.category.color).opacity(0.2))
            .foregroundColor(.portalForeground)
            .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
    }

    // MARK: - Hero Image
    private var eventHeroImage: some View {
        Group {
            if let urlString = event.media.first?.url,
               let url = URL(string: urlString),
               url.scheme == "http" || url.scheme == "https" {
                CachedRemoteImage(
                    url: url,
                    placeholder: { eventImagePlaceholder },
                    failure: { eventImagePlaceholder }
                )
            } else {
                eventImagePlaceholder
            }
        }
    }

    private var eventImagePlaceholder: some View {
        ZStack {
            Rectangle().fill(Color(hex: event.category.color).opacity(0.15))
            Image(systemName: "calendar")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Color(hex: event.category.color).opacity(0.5))
        }
    }
    
    // MARK: - Actions
    
    private func toggleSave() async {
        guard let token = authManager.token else {
            let errorMsg = "Authentication required"
            #if DEBUG
            print("❌ EventDetailView: Cannot toggle save - no auth token")
            #endif
            await MainActor.run {
                errorMessage = errorMsg
            }
            return
        }
        
        #if DEBUG
        print("📱 EventDetailView: Toggling save for event \(event.id)")
        print("📱 EventDetailView: Current state - isSaved: \(isSaved), count: \(saveCount)")
        #endif
        
        do {
            let result = try await SaveService.shared.toggleEventSave(eventId: event.id, token: token)
            await MainActor.run {
                isSaved = result.isSaved
                saveCount = result.saveCount
                errorMessage = nil
            }
            #if DEBUG
            print("✅ EventDetailView: Save toggled successfully - isSaved: \(result.isSaved), count: \(result.saveCount)")
            #endif
        } catch let error as APIError {
            let errorMsg = "Failed to toggle save: \(error.errorDescription ?? "Unknown error")"
            #if DEBUG
            print("❌ EventDetailView: APIError - \(errorMsg)")
            print("❌ EventDetailView: Error details - \(error)")
            if case .serverError(let detail) = error {
                print("❌ EventDetailView: Server error code: \(detail.code), message: \(detail.message)")
            }
            #endif
            await MainActor.run {
                errorMessage = errorMsg
            }
        } catch let err {
            let errorMsg = "An unexpected error occurred: \(err.localizedDescription)"
            #if DEBUG
            print("❌ EventDetailView: Unexpected error - \(errorMsg)")
            print("❌ EventDetailView: Error type: \(type(of: err))")
            if let nsError = err as NSError? {
                print("❌ EventDetailView: NSError - code: \(nsError.code), domain: \(nsError.domain)")
                print("❌ EventDetailView: User info: \(nsError.userInfo)")
            }
            #endif
            await MainActor.run {
                errorMessage = errorMsg
            }
        }
    }
    
    private func deleteEvent() async {
        guard let token = authManager.token else { return }
        
        do {
            let _ = try await APIService.shared.deleteEvent(id: event.id, token: token)
            dismiss()
        } catch let err {
            #if DEBUG
            print("Error deleting event: \(err)")
            #endif
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(
            event: Event(
                id: "1",
                title: "Jazz Night at Blue Note",
                description: "Live jazz performance featuring local artists. Come enjoy great music and drinks!",
                category: .music,
                address: "131 W 3rd St, New York, NY 10012",
                neighborhood: "West Village",
                latitude: 40.7306,
                longitude: -73.9866,
                startTime: Date(),
                endTime: nil,
                createdAt: Date(),
                saveCount: 42,
                distance: 2500,
                media: [MediaItem(id: "1", url: "https://picsum.photos/800/600", type: .photo, order: 0, thumbnailUrl: nil)],
                user: EventUser(id: "1", name: "John Doe")
            )
        )
        .environmentObject(AuthManager())
    }
}

