import Foundation
import Supabase

// Sign in with Apple through Supabase. The raw nonce is sent to Supabase and
// its SHA-256 hash to Apple (same contract MyPursefolio uses).
@MainActor
protocol AuthServicing: AnyObject {
    var isSignedIn: Bool { get }
    var userID: String? { get }
    func restoreSession() async
    func signIn(appleIDToken: String, rawNonce: String) async throws
    func signOut() async
}

@MainActor
@Observable
final class SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient
    private(set) var isSignedIn = false
    private(set) var userID: String?

    init(client: SupabaseClient) {
        self.client = client
    }

    func restoreSession() async {
        do {
            let session = try await client.auth.session
            userID = session.user.id.uuidString
            isSignedIn = true
        } catch {
            isSignedIn = false
            userID = nil
        }
    }

    func signIn(appleIDToken: String, rawNonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: appleIDToken, nonce: rawNonce)
        )
        userID = session.user.id.uuidString
        isSignedIn = true
    }

    func signOut() async {
        try? await client.auth.signOut()
        isSignedIn = false
        userID = nil
    }
}

// Simulator and keyless builds: always signed in so the whole flow works.
@MainActor
@Observable
final class MockAuthService: AuthServicing {
    private(set) var isSignedIn = true
    private(set) var userID: String? = "00000000-0000-0000-0000-00000000C0DE"

    func restoreSession() async {}
    func signIn(appleIDToken _: String, rawNonce _: String) async throws {}
    func signOut() async {}
}
