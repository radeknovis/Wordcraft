import XCTest

final class DemoTests: XCTestCase {
    @MainActor
    func testBuiltInSuggestionsForSampleText() {
        let app = XCUIApplication()
        app.launch()

        let picker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Backend,")).first
        picker.tap()
        app.buttons["Built-in demo"].tap()
        app.buttons["Generate suggestions"].tap()

        for word in ["think", "can", "will"] {
            XCTAssertTrue(app.staticTexts[word].waitForExistence(timeout: 5), word)
        }
        XCTAssertTrue(app.staticTexts["Source: Built-in demo"].exists)
    }
}
