import AuthenticationServices
import CryptoKit
import SwiftUI

// Sign in with Apple gate, shown only when the real backend is configured
// and there is no session. The raw nonce goes to Supabase, its SHA-256 hash
// to Apple (spec section 5; same contract as MyPursefolio).
struct SignInView: View {
    let auth: AuthServicing
    @State private var rawNonce = SignInView.randomNonce()
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🍳")
                .font(.system(size: 72))
            Text("FridgeSnap")
                .font(.largeTitle.bold())
            Text("Photograph your fridge. Pick how lazy you feel. Dinner happens anyway.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.email]
                request.nonce = Self.sha256(rawNonce)
            } onCompletion: { result in
                handle(result)
            }
            .frame(height: 52)
            .padding(.horizontal, 32)
            .disabled(isWorking)

            if isWorking {
                ProgressView()
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer().frame(height: 40)
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
                rawNonce = Self.randomNonce()
                return
            }
            isWorking = true
            let nonce = rawNonce
            Task {
                do {
                    try await auth.signIn(appleIDToken: token, rawNonce: nonce)
                } catch {
                    errorMessage = error.localizedDescription
                    rawNonce = Self.randomNonce()
                }
                isWorking = false
            }
        case .failure:
            // The user cancelled or the sheet failed; a fresh nonce keeps
            // the next attempt valid.
            rawNonce = Self.randomNonce()
        }
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
