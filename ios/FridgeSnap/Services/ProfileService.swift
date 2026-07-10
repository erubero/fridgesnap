import Foundation
import Supabase

// Persists onboarding's dietary prefs + staples answer to profiles
// (spec section 2: assumed staples asked once, never asked again;
// dietary_prefs/allergies injected into every generation prompt).
@MainActor
protocol ProfileServicing: AnyObject {
    func updatePreferences(dietaryPrefs: [String], allergies: String, staples: Bool) async throws
}

@MainActor
final class SupabaseProfileService: ProfileServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func updatePreferences(dietaryPrefs: [String], allergies: String, staples: Bool) async throws {
        guard let session = try? await client.auth.session else { throw ServiceError.notSignedIn }
        struct DietaryPrefsJSON: Encodable {
            let diets: [String]
            let allergies: String
        }
        struct Payload: Encodable {
            let dietary_prefs: DietaryPrefsJSON
            let staples: Bool
        }
        try await client
            .from("profiles")
            .update(Payload(
                dietary_prefs: DietaryPrefsJSON(diets: dietaryPrefs, allergies: allergies),
                staples: staples
            ))
            .eq("id", value: session.user.id)
            .execute()
    }
}

@MainActor
final class MockProfileService: ProfileServicing {
    func updatePreferences(dietaryPrefs _: [String], allergies _: String, staples _: Bool) async throws {
        try? await Task.sleep(for: .seconds(0.3))
    }
}
