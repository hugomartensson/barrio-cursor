import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    let onSwitchToLogin: () -> Void
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private var passwordError: String? {
        if password.isEmpty { return nil }
        if password.count < 8 { return "Password must be at least 8 characters" }
        if !password.contains(where: { $0.isUppercase }) { return "Include an uppercase letter" }
        if !password.contains(where: { $0.isNumber }) { return "Include a number" }
        if !confirmPassword.isEmpty && password != confirmPassword { return "Passwords don't match" }
        return nil
    }
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                AuthTextField(
                    icon: "person",
                    placeholder: "Full Name",
                    text: $name,
                    style: .default
                )
                
                AuthTextField(
                    icon: "envelope",
                    placeholder: "Email",
                    text: $email,
                    keyboardType: .emailAddress,
                    style: .default
                )
                
                AuthTextField(
                    icon: "lock",
                    placeholder: "Password",
                    text: $password,
                    isSecure: true,
                    style: .default
                )
                
                AuthTextField(
                    icon: "lock.fill",
                    placeholder: "Confirm Password",
                    text: $confirmPassword,
                    isSecure: true,
                    style: .default
                )
            }
            
            if let error = passwordError {
                Text(error)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
            }
            
            if let error = authManager.errorMessage {
                Text(error)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
            }
            
            Button {
                Task {
                    await authManager.signup(email: email, password: password, name: name)
                }
            } label: {
                Text(authManager.isLoading ? "Creating account..." : "Create Account")
            }
            .buttonStyle(AuthPrimaryButtonStyle())
            .accessibilityIdentifier("Create Account")
            .disabled(authManager.isLoading || !isFormValid)
            .opacity(isFormValid ? 1 : 0.5)
            
            Button {
                onSwitchToLogin()
            } label: {
                HStack(spacing: 4) {
                    Text("Already a user?")
                        .foregroundColor(.portalMutedForeground)
                    Text("Log in here")
                        .foregroundColor(.portalPrimary)
                        .underline()
                }
                .font(.portalLabel)
            }
            .accessibilityIdentifier("switch_to_login")
        }
    }
}

#Preview {
    ZStack {
        Color.portalBackground.ignoresSafeArea()
        SignupView(onSwitchToLogin: {})
            .environmentObject(AuthManager())
    }
}
