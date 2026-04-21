import SwiftUI
import CoreLocation

/// Drop-in replacement for the inline location-search dropdowns in Discover, Map,
/// and Create flows.  Wraps the server-backed federated search (Barrio spots +
/// neighborhoods + Google Places) behind a single debounced text field with a
/// sectioned results list.
///
/// Usage:
/// ```swift
/// LocationSearchField(
///     biasCenter: locationManager.coordinate,
///     onUseCurrentLocation: { ... },
///     onSelect: { resolved in
///         discoverFilters.searchLocation = resolved.coordinate
///     }
/// )
/// .environmentObject(authManager)
/// ```
struct LocationSearchField: View {
    // MARK: - Inputs
    var biasCenter: CLLocationCoordinate2D
    var placeholder: String = "Search location..."
    var onUseCurrentLocation: (() -> Void)?
    var onSelect: (ResolvedLocation) -> Void

    // MARK: - Dependencies
    @EnvironmentObject private var authManager: AuthManager

    // MARK: - Private state
    @State private var service = LocationSearchService()
    @State private var queryText = ""
    @FocusState private var isFocused: Bool
    @State private var isResolvingPlace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "Use Current Location" button (optional)
            if let useCurrentLocation = onUseCurrentLocation {
                Button(action: useCurrentLocation) {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.portalPrimary)
                        Text("Use Current Location")
                            .font(.portalLabelSemibold)
                            .foregroundColor(.portalForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.portalBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.portalMutedForeground)

                TextField(placeholder, text: $queryText)
                    .font(.portalMetadata)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onChange(of: queryText) { _, newValue in
                        guard let token = authManager.token else { return }
                        service.search(query: newValue, near: biasCenter, token: token)
                    }

                if !queryText.isEmpty {
                    Button {
                        queryText = ""
                        service.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.portalMutedForeground)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.portalBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Loading indicator
            if service.isSearching || isResolvingPlace {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text(isResolvingPlace ? "Locating..." : "Searching...")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            // Results
            if !service.sections.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Barrio spots section
                        if !service.sections.spots.isEmpty {
                            sectionHeader("Spots on Barrio")
                            ForEach(service.sections.spots) { spot in
                                resultRow(
                                    icon: "mappin.circle.fill",
                                    iconColor: .portalPrimary,
                                    title: spot.name,
                                    subtitle: spot.address
                                ) {
                                    let resolved = ResolvedLocation(
                                        coordinate: spot.coordinate,
                                        formattedAddress: spot.address,
                                        neighborhood: spot.neighborhood,
                                        placeId: nil,
                                        spotId: spot.id
                                    )
                                    commit(resolved: resolved)
                                }
                            }
                        }

                        // Neighborhoods section
                        if !service.sections.neighborhoods.isEmpty {
                            sectionHeader("Neighborhoods")
                            ForEach(service.sections.neighborhoods) { n in
                                resultRow(
                                    icon: "map",
                                    iconColor: .portalMutedForeground,
                                    title: n.name,
                                    subtitle: n.city
                                ) {
                                    let resolved = ResolvedLocation(
                                        coordinate: n.coordinate,
                                        formattedAddress: "\(n.name), \(n.city)",
                                        neighborhood: n.name,
                                        placeId: nil,
                                        spotId: nil
                                    )
                                    commit(resolved: resolved)
                                }
                            }
                        }

                        // Google Places section
                        if !service.sections.places.isEmpty {
                            sectionHeader("Places")
                            ForEach(service.sections.places) { place in
                                resultRow(
                                    icon: "building.2",
                                    iconColor: .portalMutedForeground,
                                    title: place.primaryText,
                                    subtitle: place.secondaryText.isEmpty ? nil : place.secondaryText
                                ) {
                                    resolveAndCommit(place: place)
                                }
                            }
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: 260)
            }
        }
        .onAppear { isFocused = true }
    }

    // MARK: - Sub-views

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.portalMutedForeground)
            .tracking(0.8)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }

    private func resultRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                        .lineLimit(1)
                    if let sub = subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.portalBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 3)
    }

    // MARK: - Commit helpers

    private func commit(resolved: ResolvedLocation) {
        queryText = ""
        service.clear()
        onSelect(resolved)
    }

    private func resolveAndCommit(place: PlaceSearchResult) {
        guard let token = authManager.token, !isResolvingPlace else { return }
        isResolvingPlace = true
        Task {
            do {
                let resolved = try await service.resolvePlace(placeId: place.placeId, token: token)
                isResolvingPlace = false
                commit(resolved: resolved)
            } catch {
                isResolvingPlace = false
            }
        }
    }
}
