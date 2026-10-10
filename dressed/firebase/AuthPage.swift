import SwiftUI

struct Authentication: View {
    @ObservedObject var session: SessionViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text(isCreatingAccount ? "Create Account" : "Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)

            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            Button {
                authenticate()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(isCreatingAccount ? "Create Account" : "Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Button {
                isCreatingAccount.toggle()
                errorMessage = ""
            } label: {
                Text(isCreatingAccount
                    ? "Already have an account? Sign in"
                    : "Don't have an account? Create one")
            }
        }
        .padding()
    }

    private func authenticate() {
        errorMessage = ""
        isLoading = true

        Task {
            do {
                if isCreatingAccount {
                    try await session.createAccount(email: email, password: password)
                } else {
                    try await session.signIn(email: email, password: password)
                }
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    Authentication(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
}
