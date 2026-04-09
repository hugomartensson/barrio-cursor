import SwiftUI

/// PRD Section 9.1: Reusable loading indicator
struct LoadingView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.0)
                .tint(.portalPrimary)
            
            if let message = message {
                Text(message)
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView(message: "Loading...")
}
