import SwiftUI

// MARK: - portal· Wordmark
// "portal" in display font 48pt, dot in primary amber.

struct PortalWordmark: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("portal")
                .font(.portalWordmarkItalic)
                .foregroundColor(.portalForeground)
            Text("·")
                .font(.portalWordmark)
                .foregroundColor(.portalPrimary)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

#Preview {
    PortalWordmark()
        .padding()
        .background(Color.portalBackground)
}
