import SwiftUI
import Combine

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    @State private var userName: String = ""
    @State private var userHandle: String = ""
    @State private var profilePictureUrl: String? = nil
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var selectedCity: String? = nil
    @State private var cities: [String] = []
    @State private var isFollowing: Bool = false
    @State private var isPrivate: Bool = false
    @State private var profileLocked: Bool = false
    @State private var followRequestStatus: String? = nil // "pending" | nil
    @State private var events: [Event] = []
    @State private var interestedEvents: [Event] = []
    @State private var organizingEvents: [Event] = []
    @State private var organizedEvents: [Event] = []
    @State private var isLoading = true
    @State private var error: Error? = nil // PRD Section 9.1: Store Error instead of String
    @State private var showFollowers = false
    @State private var showFollowing = false
    @State private var selectedTab: ProfileTab = .collections
    
    var isOwnProfile: Bool {
        authManager.currentUser?.id == userId
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.1)
                            .tint(.portalPrimary)
                        Text("Loading profile…")
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.portalBackground)
                } else {
                    profileScrollContent
                }
            }
            .background(Color.portalBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFollowers) {
                FollowersListView(userId: userId, isFollowers: true)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showFollowing) {
                FollowersListView(userId: userId, isFollowers: false)
                    .environmentObject(authManager)
            }
            .task(id: userId) {
                await loadProfile()
            }
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
                    .environmentObject(authManager)
            }
        }
        .id(userId)
    }

    private var profileAvatar: some View {
        let initial = userName.isEmpty ? "?" : String(userName.prefix(1)).uppercased()
        return Group {
            if let url = MediaURL.httpsURL(from: profilePictureUrl) {
                CachedRemoteImage(
                    url: url,
                    placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay { ProgressView() }
                    },
                    failure: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay { Text(initial).font(.title2).foregroundColor(.gray) }
                    }
                )
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Text(initial)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
            }
        }
    }

    private var otherUserTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.portalLabelSemibold)
                                .foregroundColor(selectedTab == tab ? .portalForeground : .portalMutedForeground)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.portalPrimary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.top, 8)
            .padding(.bottom, 4)
            Rectangle()
                .fill(Color.portalBorder.opacity(0.5))
                .frame(height: 1)
        }
        .background(Color.portalBackground)
    }

    private var profileScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    profileAvatar
                    VStack(alignment: .leading, spacing: 8) {
                        Text(userName.isEmpty ? "Profile" : userName)
                            .font(.title2.weight(.bold))
                        if !userHandle.isEmpty {
                            Text("@\(userHandle)")
                                .font(.portalMetadata)
                                .foregroundColor(.portalMutedForeground)
                        }
                        if let city = selectedCity, !city.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 11))
                                Text(city)
                                    .font(.portalMetadata)
                            }
                            .foregroundColor(.portalMutedForeground)
                        }
                        let secondaryCities = cities.filter { $0 != selectedCity }
                        if !secondaryCities.isEmpty {
                            Text("Also in: \(secondaryCities.joined(separator: ", "))")
                                .font(.portalMetadata)
                                .foregroundColor(.portalMutedForeground.opacity(0.7))
                        }
                        HStack(spacing: 24) {
                            Button {
                                showFollowers = true
                            } label: {
                                VStack {
                                    Text("\(followerCount)")
                                        .font(.headline)
                                    Text("Followers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(profileLocked && !isOwnProfile)

                            Button {
                                showFollowing = true
                            } label: {
                                VStack {
                                    Text("\(followingCount)")
                                        .font(.headline)
                                    Text("Following")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .disabled(profileLocked && !isOwnProfile)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal)

                if profileLocked && !isOwnProfile {
                    privateAccountBanner
                }

                if let error = error, !profileLocked {
                    ErrorView(
                        error: error,
                        retry: { Task { await loadProfile() } },
                        dismiss: { self.error = nil }
                    )
                    .padding(.horizontal)
                }

                if !isOwnProfile {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack {
                            if followRequestStatus == "pending" {
                                Text("Requested")
                                    .foregroundColor(.secondary)
                            } else if isFollowing {
                                Text("Following")
                                    .foregroundColor(.white)
                            } else {
                                Text("Follow")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            followRequestStatus == "pending" || isFollowing
                                ? AnyShapeStyle(Color.gray.opacity(0.3))
                                : AnyShapeStyle(Color.portalGradientPrimary)
                        )
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .disabled(followRequestStatus == "pending")

                    otherUserTabBar

                    otherUserTabContent
                        .padding(.bottom, 32)
                } else {
                    Text("Use the Profile tab to manage your account.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
    }

    private var privateAccountBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This account is private")
                .font(.headline)
            Text("Send a follow request. When it’s approved, you’ll see their collections, spots, and events.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var otherUserTabContent: some View {
        if profileLocked {
            lockedOtherUserTabPlaceholder
        } else {
            switch selectedTab {
            case .collections:
                otherUserCollectionsTab
            case .spots:
                otherUserSpotsTab
            case .events:
                otherUserEventsTab
            }
        }
    }

    private var lockedOtherUserTabPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.portalMutedForeground)
            Text("Content is hidden")
                .font(.headline)
            Text("Follow this account to see collections, spots, and events after they approve.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var otherUserCollectionsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No public collections")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, .portalPagePadding)
    }

    private var otherUserSpotsTab: some View {
        Group {
            if !isOwnProfile && !isFollowing && isPrivate {
                LockedSavesView(userName: userName)
                    .padding(.horizontal, .portalPagePadding)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No saved spots")
                        .font(.headline)
                    Text("Saved spots will appear here when available.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
        }
    }

    private var otherUserEventsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !interestedEvents.isEmpty {
                ProfileCarouselSection(title: "Saved events", events: interestedEvents)
            }
            if !organizingEvents.isEmpty {
                ProfileCarouselSection(title: "Events they're hosting", events: organizingEvents)
            }
            if !organizedEvents.isEmpty {
                ProfileCarouselSection(title: "Past events", events: organizedEvents)
            }
            if interestedEvents.isEmpty && organizingEvents.isEmpty && organizedEvents.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No events yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("This user hasn’t created or saved any events.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
        .padding(.horizontal)
    }
    
    private func loadProfile(skipLoadingUI: Bool = false) async {
        guard let token = authManager.token else {
            #if DEBUG
            print("❌ UserProfileView: No auth token available")
            #endif
            await MainActor.run {
                error = NSError(domain: "UserProfileView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])
                isLoading = false
            }
            return
        }
        
        // Validate userId
        guard !userId.isEmpty else {
            #if DEBUG
            print("❌ UserProfileView: Invalid userId (empty)")
            #endif
            await MainActor.run {
                error = NSError(domain: "UserProfileView", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
                isLoading = false
            }
            return
        }
        
        #if DEBUG
        print("📱 UserProfileView: Loading profile for user \(userId)")
        #endif
        await MainActor.run {
            if !skipLoadingUI {
                isLoading = true
                userName = ""
                userHandle = ""
                profilePictureUrl = nil
                followerCount = 0
                followingCount = 0
                events = []
                interestedEvents = []
                organizingEvents = []
                organizedEvents = []
                isFollowing = false
                profileLocked = false
                followRequestStatus = nil
            }
            error = nil
        }
        
        do {
            let profile = try await APIService.shared.getUserProfile(userId: userId, token: token)
            let data = profile.data
            let locked = data.profileLocked == true
            let pendingOutgoing = data.followRequestPending == true
            
            await MainActor.run {
                userName = data.name
                userHandle = data.handle ?? ""
                profilePictureUrl = data.profilePictureUrl
                followerCount = data.followerCount ?? 0
                followingCount = data.followingCount ?? 0
                isPrivate = data.isPrivate ?? false
                selectedCity = data.selectedCity
                cities = data.cities ?? []
                profileLocked = locked
                followRequestStatus = pendingOutgoing ? "pending" : nil
            }
            
            if locked {
                await MainActor.run {
                    events = []
                    interestedEvents = []
                    organizingEvents = []
                    organizedEvents = []
                    isFollowing = false
                    error = nil
                    isLoading = false
                }
                #if DEBUG
                print("✅ UserProfileView: Loaded locked profile for user \(userId)")
                #endif
                return
            }
            
            let eventsResponse = try await APIService.shared.getUserEvents(userId: userId, token: token)
            let hosted = eventsResponse.data
            let now = Date()
            var organizing: [Event] = []
            var organized: [Event] = []
            for e in hosted {
                let end = e.endTime ?? now
                if e.startTime <= now && end > now {
                    organizing.append(e)
                } else if e.startTime > now {
                    organizing.append(e)
                } else {
                    organized.append(e)
                }
            }
            
            var interested: [Event] = []
            if !isOwnProfile {
                let savedRes = try? await APIService.shared.getUserSavedEvents(userId: userId, token: token)
                interested = savedRes?.data ?? []
            }
            
            let followers = try await APIService.shared.getFollowers(userId: userId, token: token)
            let currentUserId = authManager.currentUser?.id
            let followingStatus = currentUserId != nil && followers.data.contains { $0.id == currentUserId }
            
            await MainActor.run {
                events = hosted
                organizingEvents = organizing
                organizedEvents = organized
                interestedEvents = interested
                isFollowing = followingStatus
                if followingStatus {
                    followRequestStatus = nil
                } else if isPrivate && !isOwnProfile {
                    followRequestStatus = pendingOutgoing ? "pending" : nil
                } else {
                    followRequestStatus = nil
                }
                error = nil
                isLoading = false
            }
            #if DEBUG
            print("✅ UserProfileView: Profile loaded successfully for user \(userId)")
            #endif
        } catch let err {
            #if DEBUG
            print("❌ UserProfileView: Error loading profile: \(err.localizedDescription)")
            if let apiError = err as? APIError {
                print("❌ UserProfileView: API Error - \(apiError.errorDescription ?? "Unknown")")
            }
            #endif
            await MainActor.run {
                error = err
                isLoading = false
            }
        }
    }
    
    private func toggleFollow() async {
        guard let token = authManager.token else { return }
        
        do {
            if isFollowing {
                _ = try await APIService.shared.unfollowUser(userId: userId, token: token)
            } else {
                _ = try await APIService.shared.followUser(userId: userId, token: token)
            }
            await loadProfile(skipLoadingUI: true)
        } catch let err {
            #if DEBUG
            print("❌ UserProfileView: Failed to update follow status: \(err.localizedDescription)")
            #endif
        }
    }
}

// Profile carousel: 3 per row, image + venue (address) only
private struct ProfileCarouselSection: View {
    let title: String
    let events: [Event]
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(events) { event in
                    NavigationLink(value: event) {
                        ProfileCarouselMiniature(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ProfileCarouselMiniature: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: MediaURL.httpsURL(from: event.media.first?.url)) { img in
                img.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay { Image(systemName: event.category.icon).foregroundColor(.gray) }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(event.address)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// Simple event card for profile view
struct ProfileEventCard: View {
    let event: Event
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let firstMedia = event.media.first, let url = URL(string: firstMedia.url) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text(event.startTime, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    CategoryChip(category: event.category)
                    Spacer()
                    Label("\(event.saveCount)", systemImage: "bookmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Placeholder for followers/following list
struct FollowersListView: View {
    let userId: String
    let isFollowers: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = FollowersListViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    LoadingView(message: "Loading...")
                } else if let error = viewModel.error {
                    ErrorView(
                        error: error,
                        retry: {
                            Task {
                                await loadUsers()
                            }
                        }
                    )
                } else if viewModel.users.isEmpty {
                    EmptyFollowersView(isFollowers: isFollowers)
                } else {
                    usersList
                }
            }
            .navigationTitle(isFollowers ? "Followers" : "Following")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadUsers()
            }
        }
    }
    
    private var usersList: some View {
        List {
            ForEach(viewModel.users) { user in
                NavigationLink {
                    UserProfileView(userId: user.id)
                        .environmentObject(authManager)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(user.name.prefix(1).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        
                        Text(user.name)
                            .font(.subheadline)
                    }
                }
            }
        }
    }
    
    private func loadUsers() async {
        guard let token = authManager.token else { return }
        await viewModel.loadUsers(userId: userId, isFollowers: isFollowers, token: token)
    }
}

// MARK: - Followers List View Model

@MainActor
class FollowersListViewModel: ObservableObject {
    @Published var users: [FollowerUser] = [] // Works for both followers and following
    @Published var isLoading = false
    @Published var error: Error?
    
    private let api = APIService.shared
    
    func loadUsers(userId: String, isFollowers: Bool, token: String) async {
        isLoading = true
        error = nil
        
        do {
            if isFollowers {
                let response = try await api.getFollowers(userId: userId, token: token)
                users = response.data
            } else {
                let response = try await api.getFollowing(userId: userId, token: token)
                users = response.data
            }
            error = nil
        } catch let err {
            error = err
            #if DEBUG
            if let err = error {
                print("❌ FollowersListViewModel: Error loading users: \(err.localizedDescription)")
            }
            #endif
        }
        
        isLoading = false
    }
}

// MARK: - Empty Followers View

struct EmptyFollowersView: View {
    let isFollowers: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isFollowers ? "person.2.slash" : "person.2")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text(isFollowers ? "No followers yet" : "Not following anyone")
                .font(.headline)
            
            Text(isFollowers 
                ? "When people follow you, they'll appear here."
                : "Start following people to see their events in your feed!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Locked state for saves on other user profiles when not an approved follower
private struct LockedSavesView: View {
    let userName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saves")
                .font(.headline)
                .foregroundColor(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saves are private")
                        .font(.subheadline.weight(.semibold))
                    Text("Follow \(userName.isEmpty ? "this user" : userName) to see what they’ve saved.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    UserProfileView(userId: "test-user-id")
        .environmentObject(AuthManager())
}
