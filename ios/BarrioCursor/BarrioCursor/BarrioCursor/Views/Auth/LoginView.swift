import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    
    let onSwitchToSignup: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                AuthTextField(
                    icon: "envelope",
                    placeholder: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    style: .default,
                    accessibilityIdentifierOverride: "login_email"
                )
                
                AuthTextField(
                    icon: "lock",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true,
                    style: .default,
                    accessibilityIdentifierOverride: "login_password"
                )
            }
            
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
                    .accessibilityIdentifier("error_message")
            }
            
            Button {
                Task {
                    await authManager.login(email: email, password: password)
                }
            } label: {
                Text(authManager.isLoading ? "Logging in..." : "Log In")
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
            .accessibilityIdentifier("login_submit")
            
            Button {
                onSwitchToSignup()
            } label: {
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .foregroundColor(.portalMutedForeground)
                    Text("Sign Up")
                        .foregroundColor(.portalPrimary)
                        .underline()
                }
                .font(.portalLabel)
            }
            .accessibilityIdentifier("switch_to_signup")
        }
    }
}

// MARK: - Auth Text Field Component
// Underlined input; supports default (light) and authDark (dark auth screen)

enum AuthTextFieldStyle {
    case `default`
    case authDark
}

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var style: AuthTextFieldStyle = .default
    /// Optional explicit a11y id for UI tests; when nil, placeholder is used.
    var accessibilityIdentifierOverride: String? = nil
    
    private var iconColor: Color {
        style == .authDark ? .portalMutedForeground : .portalMutedForeground
    }
    private var textColor: Color {
        style == .authDark ? .portalForeground : .portalForeground
    }
    private var underlineColor: Color {
        style == .authDark ? .portalBorder : .portalMutedForeground.opacity(0.3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if style == .authDark {
                Text(placeholder.uppercased())
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(iconColor)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(.password)
                        .font(.portalBody)
                        .foregroundColor(textColor)
                        .accessibilityIdentifier(accessibilityIdentifierOverride ?? placeholder)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.portalBody)
                        .foregroundColor(textColor)
                        .accessibilityIdentifier(accessibilityIdentifierOverride ?? placeholder)
                }
            }
            .padding(.vertical, 8)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(underlineColor)
        }
    }
}

#Preview {
    ZStack {
        Color.portalBackground.ignoresSafeArea()
        LoginView(onSwitchToSignup: {})
            .environmentObject(AuthManager())
    }
}
