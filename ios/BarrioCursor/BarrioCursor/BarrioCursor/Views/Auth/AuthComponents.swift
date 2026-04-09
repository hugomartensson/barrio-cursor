import SwiftUI

/// Shared auth layout primitives aligned with the PRD design system.

struct AuthScreenContainer<Content: View>: View {
    let title: String?
    let subtitle: String?
    let content: Content
    
    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color.portalBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    PortalWordmark()
                    if let title = title, !title.isEmpty {
                        Text(title)
                            .font(.portalDisplay22)
                            .foregroundColor(.portalForeground)
                    }
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.portalBody)
                            .foregroundColor(.portalMutedForeground)
                    }
                }
                .padding(.top, 48)
                
                content
                    .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

struct AuthCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(Color.portalCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.portalLabel)
            .foregroundColor(.portalPrimaryForeground)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                Color.portalPrimary
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .cornerRadius(12)
    }
}
