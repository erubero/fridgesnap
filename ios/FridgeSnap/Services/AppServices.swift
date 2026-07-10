import Foundation
import Supabase

// Central service container. Picks real Supabase-backed services when
// Secrets.xcconfig is filled in, mocks otherwise, so the app always runs
// end to end in the Simulator with zero secrets.
@MainActor
@Observable
final class AppServices {
    let auth: AuthServicing
    let scan: ScanServicing
    let generation: GenerationServicing
    let isUsingMocks: Bool

    init() {
        if let url = AppConfig.supabaseURL, let key = AppConfig.supabaseAnonKey {
            let client = SupabaseClient(supabaseURL: url, supabaseKey: key)
            auth = SupabaseAuthService(client: client)
            scan = SupabaseScanService(client: client)
            generation = SupabaseGenerationService(client: client)
            isUsingMocks = false
        } else {
            auth = MockAuthService()
            scan = MockScanService()
            generation = MockGenerationService()
            isUsingMocks = true
        }
    }
}
