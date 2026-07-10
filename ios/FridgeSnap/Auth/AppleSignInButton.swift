import AuthenticationServices
import SwiftUI

// Sign in with Apple button + handling, shared by SignInView (re-auth after
// sign-out) and the onboarding account-creation step. Raw nonce goes to
// Supabase, its SHA-256 hash to Apple (spec section 5).
struct AppleSignInButton: View {
    let auth: AuthServicing
    var onSuccess: () -> Void

    @State private var rawNonce = SignInView.randomNonce()
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
                request.nonce = SignInView.sha256(rawNonce)
            } onCompletion: { result in
                handle(result)
            }
            .frame(height: 52)
            .disabled(isWorking)

            if isWorking {
                ProgressView()
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                errorMessage = "Apple did not return a valid credential. Please try again."
                rawNonce = SignInView.randomNonce()
                return
            }
            isWorking = true
            let nonce = rawNonce
            Task {
                do {
                    try await auth.signIn(appleIDToken: token, rawNonce: nonce)
                    onSuccess()
                } catch {
                    errorMessage = error.localizedDescription
                    rawNonce = SignInView.randomNonce()
                }
                isWorking = false
            }
        case .failure:
            // The user cancelled or the sheet failed; a fresh nonce keeps
            // the next attempt valid.
            rawNonce = SignInView.randomNonce()
        }
    }
}
