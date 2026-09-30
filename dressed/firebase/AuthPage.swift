import SwiftUI
import FirebaseAuth

struct Authentication: View {
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
                Text(
                    isCreatingAccount
                    ? "Already have an account? Sign in"
                    : "Don't have an account? Create one"
                )
            }
        }
        .padding()
    }

    private func authenticate() {
        errorMessage = ""
        isLoading = true

        if isCreatingAccount {
            Auth.auth().createUser(withEmail: email, password: password) { _, error in
                handleAuthResult(error)
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { _, error in
                handleAuthResult(error)
            }
        }
    }

    private func handleAuthResult(_ error: Error?) {
        isLoading = false

        if let error = error {
            errorMessage = error.localizedDescription
        } else {
            print("Successfully authenticated!")
            print("User ID:", Auth.auth().currentUser?.uid ?? "No UID")
            Task {
                guard let uid = Auth.auth().currentUser?.uid else { return }

                let now = Date()
                var outfit = Outfit(
                    id: "save_test_\(UUID().uuidString)",
                    schemaVersion: 1,
                    ownerId: uid,
                    name: "Test outfit",
                    placementSchemaVersion: 1,
                    placements: [],
                    createdAt: now,
                    updatedAt: now
                )

                do {
                    try await saveOutfit(outfit)
                    print("First save succeeded")

                    outfit.name = "Updated test outfit"
                    outfit.updatedAt = Date()

                    try await saveOutfit(outfit)
                    print("Second save succeeded")
                    print("Check: users/\(uid)/outfits/\(outfit.id)")
                } catch {
                    print("Outfit save failed:", error)
                }
            }
        }
    }
}

#Preview {
    Authentication()
}
