import SwiftUI

// MARK: - portal· Design System — Motion
// PRD: Fade-in (0.4s, Y+8), slide-up (0.5s, Y+20), staggered (80ms per item).

struct PortalFadeInModifier: ViewModifier {
    var delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct PortalSlideUpModifier: ViewModifier {
    var delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    appeared = true
                }
            }
    }
}

extension View {
    /// PRD: Fade-in, 0.4s ease-out, Y+8 → 0
    func portalFadeIn(delay: Double = 0) -> some View {
        modifier(PortalFadeInModifier(delay: delay))
    }

    /// PRD: Slide-up, 0.5s ease-out, Y+20 → 0
    func portalSlideUp(delay: Double = 0) -> some View {
        modifier(PortalSlideUpModifier(delay: delay))
    }

    /// Staggered appear: fade-in with delay = index * 0.08
    func portalStaggeredAppear(index: Int) -> some View {
        modifier(PortalFadeInModifier(delay: Double(index) * 0.08))
    }
}
