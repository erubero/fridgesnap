import XCTest
@testable import FridgeSnap

final class LoadingAnimationTests: XCTestCase {
    // Every case must have a bundled JSON that parses as a Lottie document.
    // Catches a renamed or dropped file before it ships a blank wait screen.
    func testAllAnimationsAreBundledAndValid() throws {
        for animation in LoadingAnimation.allCases {
            let url = try XCTUnwrap(animation.bundleURL, "\(animation.rawValue).json missing from bundle")
            let data = try Data(contentsOf: url)
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertNotNil(json["w"], "\(animation.rawValue): no width, not a Lottie file")
            XCTAssertNotNil(json["op"], "\(animation.rawValue): no out-point, not a Lottie file")
        }
    }

    func testRandomCoversAllCasesOverManyDraws() {
        var generator = SystemRandomNumberGenerator()
        let drawn = Set((0..<200).map { _ in LoadingAnimation.random(using: &generator) })
        XCTAssertEqual(drawn, Set(LoadingAnimation.allCases))
    }
}
