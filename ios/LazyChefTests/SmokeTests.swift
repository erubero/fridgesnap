import XCTest
@testable import LazyChef

final class SmokeTests: XCTestCase {
    func testKeylessCheckoutIsNotConfigured() {
        // A checkout without Secrets.xcconfig must select mock services.
        XCTAssertFalse(AppConfig.isConfigured)
        XCTAssertNil(AppConfig.supabaseURL)
    }
}
