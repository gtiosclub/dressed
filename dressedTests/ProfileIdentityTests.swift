import XCTest
@testable import dressed

final class ProfileIdentityTests: XCTestCase {
    func testDisplayNameWinsOverEmail() {
        XCTAssertEqual(profileDisplayName(displayName: "Eric Kim", email: "someone@example.com"), "Eric Kim")
    }

    func testBlankDisplayNameFallsBackToEmailLocalPart() {
        XCTAssertEqual(profileDisplayName(displayName: "  ", email: "eric@example.com"), "eric")
        XCTAssertEqual(profileDisplayName(displayName: nil, email: "eric@example.com"), "eric")
    }

    func testMissingNameAndEmailGiveNil() {
        XCTAssertNil(profileDisplayName(displayName: nil, email: nil))
        XCTAssertNil(profileDisplayName(displayName: "", email: "@example.com"))
    }

    func testInitialIsUppercaseFirstLetterOrDigit() {
        XCTAssertEqual(profileInitial("eric"), "E")
        XCTAssertEqual(profileInitial("_vivian"), "V")
        XCTAssertEqual(profileInitial("42fits"), "4")
    }

    func testInitialFallsBackToQuestionMark() {
        XCTAssertEqual(profileInitial(nil), "?")
        XCTAssertEqual(profileInitial("__"), "?")
    }
}
