import SwiftUI

// MARK: - Live Event Halo
// Pulsing glow for live events

struct LiveEventHalo: View {
    let color: Color
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        Rectangle()
            .stroke(color, lineWidth: 3)
            .shadow(color: color.opacity(0.5), radius: 8)
            .scaleEffect(pulseScale)
            .opacity(pulseOpacity)
            .animation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: pulseScale
            )
            .onAppear {
                withAnimation {
                    pulseScale = 1.02
                    pulseOpacity = 0.7
                }
            }
    }
}

#Preview {
    ZStack {
        Color.portalBackground
        RoundedRectangle(cornerRadius: 0)
            .frame(width: 200, height: 300)
            .overlay(
                LiveEventHalo(color: .signatureCoral)
            )
    }
    .padding()
}
