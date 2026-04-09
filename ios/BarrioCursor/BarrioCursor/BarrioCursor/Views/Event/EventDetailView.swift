import SwiftUI
import AVKit

/// One friend (person the current user follows) who saved the event — for mini-avatar display in "Friends who saved this".
struct EventFriendSaved: Hashable {
    let name: String
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2, let f = parts.first?.prefix(1), let l = parts.last?.prefix(1) {
            return "\(f)\(l)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

struct EventDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let event: Event
    /// Friends who saved this event (people the user follows) — mini avatars. Populate from API when endpoint returns followers-who-saved.
    let mutualsWhoSaved: [EventFriendSaved]
    @State private var showUserProfile = false
    @State private var userIdToShow: String? = nil
    @State private var isSaved = false
    @State private var saveCount: Int
    @State private var showEditEvent = false
    @State private var showDeleteAlert = false
    @State private var showFullDescription = false
    @State private var showAddToCollection = false
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

    init(event: Event, isSaved: Bool = false, mutualsWhoSaved: [EventFriendSaved] = []) {
        self.event = event
        self.mutualsWhoSaved = mutualsWhoSaved
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
        .background(Color.portalBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditEvent) {
            CreateEventView(eventToEdit: event)
        }
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(itemType: "event", itemId: event.id) {
                showAddToCollection = false
            }
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
        .sheet(isPresented: $showUserProfile) {
            if let userId = userIdToShow {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authManager)
                }
            } else {
                NavigationStack {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("User not found")
                            .font(.headline)
                        Text("Unable to load user profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .navigationTitle("Error")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showUserProfile = false
                            }
                        }
                    }
                }
            }
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
            ZStack(alignment: .top) {
                eventHeroImage
                    .frame(width: w, height: h)
                    .clipped()

                eventHeroGradient
                    .frame(width: w, height: h)
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
                    eventHeroBottomBlock
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 16)
                }
                .frame(width: w, height: h)
            }
        }
        .aspectRatio(heroAspectRatio, contentMode: .fit)
        .ignoresSafeArea(edges: .top)
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
            HStack(spacing: .portalCardGap) {
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
                PortalSaveButton(isSaved: isSaved, count: saveCount, surface: .dark) {
                    Task { await toggleSave() }
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
            Divider().background(Color.portalBorder)
            eventCreatorRow
            Divider().background(Color.portalBorder)
            eventMutualsSavedRow
            addToCollectionButton
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addToCollectionButton: some View {
        Button {
            showAddToCollection = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 16))
                Text("Add to collection")
                    .font(.portalLabel)
            }
            .foregroundColor(.portalPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.portalPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
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
        HStack(spacing: 12) {
            Image(systemName: "mappin")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(event.displayCity)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
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

    private var eventCreatorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATED BY")
                .font(.portalSectionLabel)
                .tracking(2)
                .foregroundColor(.portalMutedForeground)
            Button {
                userIdToShow = event.user.id
                showUserProfile = true
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.portalPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(event.user.name.prefix(1).uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.portalPrimaryForeground)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.user.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.portalForeground)
                        Text("@\(event.user.name.replacingOccurrences(of: " ", with: "").lowercased())")
                            .font(.system(size: 10))
                            .foregroundColor(.portalMutedForeground)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        }
    }

    /// Mutuals who saved this event — mini avatars + count.
    private var eventMutualsSavedRow: some View {
        EventMutualsSavedRow(mutualsWhoSaved: mutualsWhoSaved, totalSaveCount: saveCount)
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

// MARK: - Mutuals who saved (mini avatars + count)
private struct EventMutualsSavedRow: View {
    let mutualsWhoSaved: [EventFriendSaved]
    let totalSaveCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FRIENDS WHO SAVED THIS")
                .font(.portalSectionLabel)
                .tracking(2)
                .foregroundColor(.portalMutedForeground)
            HStack(spacing: 12) {
                mutualsAvatarStack
                mutualsCountText
            }
        }
    }

    private var mutualsAvatarStack: some View {
        let friends = Array(mutualsWhoSaved.prefix(3))
        return HStack(spacing: -8) {
            ForEach(Array(friends.enumerated()), id: \.offset) { _, friend in
                Circle()
                    .fill(Color.portalSecondary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(friend.initials)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.portalForeground)
                    )
                    .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
            }
        }
    }

    @ViewBuilder
    private var mutualsCountText: some View {
        if !mutualsWhoSaved.isEmpty {
            let names = mutualsWhoSaved.prefix(2).map(\.name).joined(separator: ", ")
            let moreCount = mutualsWhoSaved.count > 2 ? mutualsWhoSaved.count - 2 : 0
            let more = moreCount > 0 ? " + \(moreCount) more" : ""
            HStack(spacing: 0) {
                Text(names)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.portalForeground)
                Text(more)
                    .font(.system(size: 12))
                    .foregroundColor(.portalMutedForeground)
            }
        } else {
            Text("\(totalSaveCount) saved")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
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
            ),
            mutualsWhoSaved: [
                EventFriendSaved(name: "Jess"),
                EventFriendSaved(name: "Marcus"),
                EventFriendSaved(name: "Alex Rivera")
            ]
        )
        .environmentObject(AuthManager())
    }
}

