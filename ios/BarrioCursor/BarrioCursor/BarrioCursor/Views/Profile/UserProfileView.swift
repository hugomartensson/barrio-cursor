import SwiftUI
import Combine

struct UserProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    let userId: String
    @State private var userName: String = ""
    @State private var profilePictureUrl: String? = nil
    @State private var followerCount: Int = 0
    @State private var followingCount: Int = 0
    @State private var isFollowing: Bool = false
    @State private var isPrivate: Bool = false
    @State private var followRequestStatus: String? = nil // "pending" | nil
    @State private var events: [Event] = []
    @State private var interestedEvents: [Event] = []
    @State private var organizingEvents: [Event] = []
    @State private var organizedEvents: [Event] = []
    @State private var isLoading = true
    @State private var error: Error? = nil // PRD Section 9.1: Store Error instead of String
    @State private var showFollowers = false
    @State private var showFollowing = false
    
    var isOwnProfile: Bool {
        authManager.currentUser?.id == userId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading && userName.isEmpty && error == nil {
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
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Profile header
                    HStack(spacing: 16) {
                        // Profile picture
                        if let profilePictureUrl = profilePictureUrl, let url = URL(string: profilePictureUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay {
                                        Text(userName.prefix(1).uppercased())
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    }
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Text(userName.prefix(1).uppercased())
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(userName)
                                .font(.title2.weight(.bold))
                            
                            // Stats
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
                                .disabled(isPrivate && !isFollowing && !isOwnProfile)
                                
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
                                .disabled(isPrivate && !isFollowing && !isOwnProfile)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Follow button (not shown for own profile)
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
                    }
                    
                    Divider()
                    
                    // Error display
                    if let error = error {
                        ErrorView(
                            error: error,
                            retry: {
                                Task {
                                    await loadProfile()
                                }
                            },
                            dismiss: {
                                self.error = nil
                            }
                        )
                        .padding()
                    }
                    
                    // Carousels (other users only; own profile uses ProfileView tab)
                    if !isOwnProfile && (!interestedEvents.isEmpty || !organizingEvents.isEmpty || !organizedEvents.isEmpty) {
                        profileCarouselsSection
                    } else if events.isEmpty && interestedEvents.isEmpty && !isLoading && error == nil {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.portalMutedForeground)
                            Text("No events yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("This user hasn't created any events.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .opacity(isLoading && userName.isEmpty && error == nil ? 0 : 1)
            }
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
            }
            .sheet(isPresented: $showFollowing) {
                FollowersListView(userId: userId, isFollowers: false)
            }
            .task {
                await loadProfile()
            }
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
                    .environmentObject(authManager)
            }
        }
    }
    
    private var profileCarouselsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // COLLECTIONS — public (and friends-only if following). Placeholder until GET /users/:id/collections exists.
            Text("COLLECTIONS")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("No public collections")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)

            // SAVED SPOTS — visible only if following; otherwise locked.
            Text("SAVED SPOTS")
                .font(.headline)
                .foregroundColor(.secondary)
            if !isOwnProfile && !isFollowing {
                LockedSavesView(userName: userName)
            } else {
                Text("No saved spots")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            // SAVED EVENTS — visible only if following; otherwise locked.
            Text("SAVED EVENTS")
                .font(.headline)
                .foregroundColor(.secondary)
            if !isOwnProfile && !isFollowing {
                LockedSavesView(userName: userName)
            } else if !interestedEvents.isEmpty {
                ProfileCarouselSection(title: "Saved events", events: interestedEvents)
            } else {
                Text("No saved events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            if !organizingEvents.isEmpty {
                ProfileCarouselSection(title: "Events they're hosting", events: organizingEvents)
            }
            if !organizedEvents.isEmpty {
                ProfileCarouselSection(title: "Past events", events: organizedEvents)
            }
        }
        .padding()
    }
    
    private func loadProfile() async {
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
            isLoading = true
            error = nil
            userName = ""
            profilePictureUrl = nil
            followerCount = 0
            followingCount = 0
            isFollowing = false
            events = []
            interestedEvents = []
            organizingEvents = []
            organizedEvents = []
        }
        
        do {
            let profile = try await APIService.shared.getUserProfile(userId: userId, token: token)
            await MainActor.run {
                userName = profile.data.name
                profilePictureUrl = profile.data.profilePictureUrl
                followerCount = profile.data.followerCount ?? 0
                followingCount = profile.data.followingCount ?? 0
                isPrivate = profile.data.isPrivate ?? false
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
            
            await MainActor.run {
                events = hosted
                organizingEvents = organizing
                organizedEvents = organized
                interestedEvents = interested
            }
            
            // Check if following
            let followers = try await APIService.shared.getFollowers(userId: userId, token: token)
            // Check if current user follows this user
            let currentUserId = authManager.currentUser?.id
            let followingStatus = currentUserId != nil && followers.data.contains { $0.id == currentUserId }
            
            // Check for pending follow request (if not following and private account)
            var requestStatus: String? = nil
            if !followingStatus && isPrivate && !isOwnProfile {
                let requests = try await APIService.shared.getFollowRequests(token: token)
                requestStatus = requests.data.first(where: { $0.fromUserId == userId })?.status
            }
            
            await MainActor.run {
                isFollowing = followingStatus
                followRequestStatus = requestStatus
                error = nil // Clear error on success
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
                let response = try await APIService.shared.unfollowUser(userId: userId, token: token)
                isFollowing = response.data.following
                followerCount = response.data.followerCount
            } else {
                let response = try await APIService.shared.followUser(userId: userId, token: token)
                isFollowing = response.data.following
                followerCount = response.data.followerCount
                
                // If private account and not following yet, show "Requested" state
                if !response.data.following {
                    followRequestStatus = "pending"
                }
            }
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
            AsyncImage(url: URL(string: event.media.first?.url ?? "")) { img in
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
