import XCTest

final class MacPanelUITests: XCTestCase {
    func testSettingsSlidesInAndTheDayOpensBesideTheTimeline() throws {
        #if os(macOS)
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let settings = app.buttons["open-settings"]
        if !settings.waitForExistence(timeout: 8) {
            let identifiers = app.buttons.allElementsBoundByIndex.map(\.identifier)
            if identifiers.isEmpty || identifiers == ["_XCUI:FullScreenWindow"] {
                throw XCTSkip("XCTest could not read the SwiftUI window on this Mac.")
            }
            XCTFail("Settings should be in the Mac toolbar. Visible buttons: \(identifiers)")
            return
        }
        settings.click()

        let closeSettings = app.buttons["close-settings"]
        XCTAssertTrue(closeSettings.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["On this device"].exists)
        closeSettings.click()
        XCTAssertTrue(closeSettings.waitForNonExistence(timeout: 3))

        XCTAssertTrue(app.buttons["selected-day"].waitForExistence(timeout: 3))
        app.typeKey("d", modifierFlags: [.command, .shift])

        let thisDay = app.staticTexts["This day"]
        XCTAssertTrue(thisDay.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Nothing recorded for this day."].waitForExistence(timeout: 2))

        let closeDay = app.buttons["Close"]
        XCTAssertTrue(closeDay.waitForExistence(timeout: 2))
        closeDay.click()
        XCTAssertTrue(thisDay.waitForNonExistence(timeout: 3))
        #else
        throw XCTSkip("The sliding settings panel and day column are the Mac layout.")
        #endif
    }
}
