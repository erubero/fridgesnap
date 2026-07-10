import Foundation
import Supabase

// Fire-and-forget event logging into analytics_events (spec section 10).
// Event names are the spec's contract; keep them exact so the nightly
// popular_combos job and any future dashboard can rely on them.
enum AnalyticsEvent {
    static let scanCompleted = "scan_completed"
    static let ingredientsEdited = "ingredients_edited"
    static let levelSelected = "level_selected"
    static let recipeGenerated = "recipe_generated"
    static let recipeRegenerated = "recipe_regenerated"
    static let cookStarted = "cook_started"
    static let cookCompleted = "cook_completed"
    static let recipeSaved = "recipe_saved"
}

@MainActor
protocol AnalyticsServicing: AnyObject {
    func log(_ name: String, props: [String: String])
}

extension AnalyticsServicing {
    func log(_ name: String) { log(name, props: [:]) }
}

@MainActor
final class SupabaseAnalyticsService: AnalyticsServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func log(_ name: String, props: [String: String]) {
        struct Payload: Encodable {
            let user_id: String
            let name: String
            let props: [String: String]
        }
        Task {
            // RLS requires user_id = auth.uid(); silently drop the event if
            // there is no session rather than surface a network error to the UI.
            guard let session = try? await client.auth.session else { return }
            try? await client
                .from("analytics_events")
                .insert(Payload(user_id: session.user.id.uuidString.lowercased(), name: name, props: props))
                .execute()
        }
    }
}

// Simulator and keyless builds: print instead of a network call.
@MainActor
final class MockAnalyticsService: AnalyticsServicing {
    func log(_ name: String, props: [String: String]) {
        let propsText = props.isEmpty ? "" : " \(props)"
        print("[analytics] \(name)\(propsText)")
    }
}
