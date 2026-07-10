import CryptoKit
import SwiftUI

// Sign-in fallback shown when onboarding is already complete but there is no
// session (e.g. the user signed out from Settings). First-run account
// creation happens inside OnboardingView instead. Nonce helpers are namespaced
// here and reused by AppleSignInButton (spec section 5; same contract as
// MyPursefolio).
struct SignInView: View {
    let auth: AuthServicing

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

            AppleSignInButton(auth: auth, onSuccess: {})
                .padding(.horizontal, 32)

            Spacer().frame(height: 40)
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
