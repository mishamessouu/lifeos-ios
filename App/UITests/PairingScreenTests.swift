import XCTest

/// Launches the app with an empty memory Keychain and keeps a screenshot of
/// the pairing screen as a build artifact that agents can read.
final class PairingScreenTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testThePairingScreenShows() {
        let app = XCUIApplication()
        app.launchArguments = ["-lifeos-ui-test"]
        app.launch()

        let field = app.textFields["pairing.link"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["pairing.button"].exists)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "pairing-screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
