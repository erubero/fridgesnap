import Foundation

/// Runtime access to keys injected via ios/Config/Secrets.xcconfig -> Info.plist.
/// All values are empty in a keyless checkout; services fall back to mocks then.
enum AppConfig {
    static var supabaseURL: URL? {
        guard let raw = plistString("SUPABASE_URL"), !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    static var supabaseAnonKey: String? {
        plistString("SUPABASE_ANON_KEY")
    }

    static var revenueCatAPIKey: String? {
        plistString("REVENUECAT_API_KEY")
    }

    /// True when the app can talk to the real backend. False selects mock services
    /// so the whole app runs in the Simulator with zero secrets.
    static var isConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey?.isEmpty == false
    }

    private static func plistString(_ key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let value, !value.isEmpty, !value.contains("REPLACE_ME") else { return nil }
        return value
    }
}
