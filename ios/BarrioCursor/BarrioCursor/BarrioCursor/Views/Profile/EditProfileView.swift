import SwiftUI
import PhotosUI

/// PRD Section 7.2: Profile Editing - name, profile picture, privacy toggle.
/// Layout matches CreateSpotView: Portal design system, sticky header, scroll form, fixed CTA.
struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var isPrivate: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hasLoadedInitialValues = false

    @FocusState private var nameFocused: Bool
    @FocusState private var bioFocused: Bool

    private let maxBioLength = 280

    private static let maxContentWidth: CGFloat = 512

    // MARK: - Sticky header (matches CreateSpotView)
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
            Text("Edit Profile")
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

    // MARK: - Profile picture section
    private var profilePictureSection: some View {
        VStack(spacing: 12) {
            if let profileImage = profileImage {
                Image(uiImage: profileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.portalBorder, lineWidth: 2)
                    )
            } else if let profilePictureUrl = authManager.currentUser?.profilePictureUrl,
                      let url = URL(string: profilePictureUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(.portalPrimary)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        defaultAvatar
                    @unknown default:
                        defaultAvatar
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.portalBorder, lineWidth: 2)
                )
            } else {
                defaultAvatar
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Change Photo")
                    .font(.portalBody)
                    .foregroundColor(.portalPrimary)
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        profileImage = image
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Name field (borderless + bottom line, matches CreateSpotView)
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Name", text: $name)
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
                .textInputAutocapitalization(.words)
                .focused($nameFocused)
                .accessibilityIdentifier("name")
            Rectangle()
                .frame(height: 1)
                .foregroundColor(nameFocused ? Color.portalPrimary : Color.portalBorder)
        }
        .padding(.vertical, 8)
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BIO")
                .font(.portalSectionLabel)
                .tracking(1.2)
                .foregroundColor(.portalMutedForeground)
            ZStack(alignment: .topLeading) {
                if bio.isEmpty {
                    Text("Short bio (optional)")
                        .font(.portalBody)
                        .foregroundColor(.portalMutedForeground)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $bio)
                    .font(.portalBody)
                    .foregroundColor(.portalForeground)
                    .focused($bioFocused)
                    .frame(minHeight: 72)
                    .padding(.leading, 0)
                    .padding(.top, 4)
                    .onChange(of: bio) { _, newValue in
                        if newValue.count > maxBioLength {
                            bio = String(newValue.prefix(maxBioLength))
                        }
                    }
                    .accessibilityIdentifier("bio")
            }
            HStack {
                Spacer(minLength: 0)
                Text("\(bio.count)/\(maxBioLength)")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
            Rectangle()
                .frame(height: 1)
                .foregroundColor(bioFocused ? Color.portalPrimary : Color.portalBorder)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Privacy section (Portal section label + toggle + caption)
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVACY")
                .font(.portalSectionLabel)
                .tracking(1.2)
                .foregroundColor(.portalMutedForeground)
            Toggle("Private Account", isOn: $isPrivate)
                .tint(.portalPrimary)
            Text("When your account is private, only people you approve can see your events and follow you.")
                .font(.portalMetadata)
                .foregroundColor(.portalMutedForeground)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Scroll form content
    private var scrollFormContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            profilePictureSection
            nameSection
            bioSection
            Spacer().frame(height: 24) // extra breathing room between Bio and Privacy (P2)
            privacySection
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
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.portalBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                stickyHeader
                ScrollView {
                    scrollFormContent
                }
                .scrollDismissesKeyboard(.interactively)
                // Fixed Save button with gradient fade (matches CreateSpotView)
                VStack(spacing: 0) {
                    LinearGradient(
                        colors: [Color.portalBackground.opacity(0), Color.portalBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 24)
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        Text("Save Changes")
                            .font(.portalLabel)
                            .foregroundColor(isSaving || name.isEmpty ? .portalMutedForeground : .portalPrimaryForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isSaving || name.isEmpty ? Color.portalMuted : Color.portalPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(
                                color: isSaving || name.isEmpty ? .clear : Color.portalPrimary.opacity(0.35),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    }
                    .disabled(isSaving || name.isEmpty)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("save")
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                    .frame(maxWidth: Self.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .background(Color.portalBackground)
            }
        }
        .task {
            if !hasLoadedInitialValues {
                name = authManager.currentUser?.name ?? ""
                bio = authManager.currentUser?.bio ?? ""
                isPrivate = authManager.currentUser?.isPrivate ?? false
                hasLoadedInitialValues = true
            }
            if let token = authManager.token, !token.isEmpty,
               let profile = try? await APIService.shared.getProfile(token: token) {
                await MainActor.run {
                    name = profile.data.name
                    bio = profile.data.bio ?? ""
                    isPrivate = profile.data.isPrivate ?? false
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .overlay {
            if isSaving || isUploading {
                VStack(spacing: 24) {
                    ProgressView().scaleEffect(1.0).tint(.portalPrimary)
                    Text(isUploading ? "Uploading photo..." : "Saving...")
                        .font(.portalBody)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(hex: "#e94560"), Color(hex: "#ff6b6b")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 120)
            .overlay {
                Text(name.prefix(1).uppercased())
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            var profilePictureUrl: String? = nil

            if let image = profileImage {
                isUploading = true
                let (uploadUrl, publicUrl) = try await APIService.shared.getSignedUploadUrl(
                    contentType: "image/jpeg",
                    duration: nil,
                    token: authManager.token ?? ""
                )

                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw NSError(domain: "EditProfileView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
                }

                var uploadRequest = URLRequest(url: URL(string: uploadUrl)!)
                uploadRequest.httpMethod = "PUT"
                uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                uploadRequest.httpBody = imageData

                let (_, response) = try await URLSession.shared.data(for: uploadRequest)

                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                    profilePictureUrl = publicUrl
                } else {
                    throw NSError(domain: "EditProfileView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image"])
                }

                isUploading = false
            }

            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            let response = try await APIService.shared.updateUser(
                name: name,
                profilePictureUrl: profilePictureUrl,
                isPrivate: isPrivate,
                bio: trimmedBio.isEmpty ? "" : trimmedBio,
                token: authManager.token ?? ""
            )

            await MainActor.run {
                if var u = authManager.currentUser {
                    u.name = response.data.name
                    u.profilePictureUrl = response.data.profilePictureUrl
                    u.isPrivate = response.data.isPrivate ?? false
                    u.bio = response.data.bio
                    authManager.currentUser = u
                    authManager.persistUserToKeychain(u)
                }
            }

            dismiss()
        } catch let err {
            errorMessage = err.localizedDescription
            showError = true
        }

        isSaving = false
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthManager())
}
