import SwiftUI

/// PRD Section 9.1: User-friendly error display with retry option
struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    let dismiss: (() -> Void)?
    
    init(error: Error, retry: (() -> Void)? = nil, dismiss: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
        self.dismiss = dismiss
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.portalMutedForeground)
            
            Text("Something went wrong")
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
            
            Text(userFriendlyMessage)
                .font(.portalBody)
                .foregroundColor(.portalMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            
            if let retry = retry {
                Button {
                    retry()
                } label: {
                    Text("Try Again")
                        .font(.portalLabel)
                        .foregroundColor(.portalPrimaryForeground)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 32)
                        .background(Color.portalPrimary)
                        .cornerRadius(12)
                }
            }
            
            if let dismiss = dismiss {
                Button {
                    dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.portalLabel)
                        .foregroundColor(.portalMutedForeground)
                        .underline()
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var userFriendlyMessage: String {
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }
        
        let nsError = error as NSError
        let errorCode = nsError.code
        
        if errorCode == -1009 || error.localizedDescription.contains("internet") {
            return "No internet connection. Please check your network and try again."
        }
        
        if errorCode == -1001 || error.localizedDescription.contains("timeout") {
            return "Request timed out. Please try again."
        }
        
        if errorCode == -1004 || error.localizedDescription.contains("connect") {
            return "Could not connect to server. Please check your connection and try again."
        }
        
        if error.localizedDescription.contains("permission") || error.localizedDescription.contains("denied") {
            return "Permission denied. Please enable access in Settings."
        }
        
        return error.localizedDescription
    }
}

// MARK: - APIError Extension for User-Friendly Messages

extension APIError {
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "Invalid request. Please try again."
        case .networkError(let error):
            let nsError = error as NSError
            if nsError.code == -1009 {
                return "No internet connection. Please check your network and try again."
            }
            if nsError.code == -1001 {
                return "Request timed out. Please try again."
            }
            if nsError.code == -1004 {
                return "Could not connect to server. Please check your connection and try again."
            }
            return "Network error. Please check your connection and try again."
        case .decodingError:
            return "Failed to load data. Please try again."
        case .serverError(let detail):
            if !detail.message.isEmpty {
                return detail.message
            }
            return "Server error. Please try again later."
        case .unauthorized:
            return "Your session has expired. Please log in again."
        case .notFound:
            return "The requested item could not be found."
        case .unknown(let code):
            if code == 429 {
                return "Too many requests. Please wait a moment and try again."
            }
            if code >= 500 {
                return "Server error. Please try again later."
            }
            return "An unexpected error occurred. Please try again."
        }
    }
}

#Preview {
    ErrorView(
        error: APIError.networkError(NSError(domain: "test", code: -1009)),
        retry: {
            #if DEBUG
            print("Retry")
            #endif
        },
        dismiss: {
            #if DEBUG
            print("Dismiss")
            #endif
        }
    )
}
