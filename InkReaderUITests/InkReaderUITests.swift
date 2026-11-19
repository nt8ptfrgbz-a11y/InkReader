import XCTest

final class InkReaderUITests: XCTestCase {
    @MainActor
    func testReadingChaptersSettingsBookmarksAndRestore() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["continueReading"].waitForExistence(timeout: 15))
        let shelf = XCTAttachment(screenshot: app.screenshot()); shelf.name = "01-书架"; shelf.lifetime = .keepAlways; add(shelf)
        app.buttons["continueReading"].tap()
        XCTAssertTrue(app.buttons["showContents"].waitForExistence(timeout: 15))
        app.buttons["showContents"].tap()
        XCTAssertTrue(app.buttons["chapter-1"].waitForExistence(timeout: 8))
        app.buttons["chapter-1"].tap()
        XCTAssertTrue(app.staticTexts["readingProgress"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["readingProgress"].label.hasPrefix("2 / 50"))
        app.webViews.firstMatch.swipeUp()
        let reading = XCTAttachment(screenshot: app.screenshot()); reading.name = "02-正文"; reading.lifetime = .keepAlways; add(reading)
        app.buttons["addBookmark"].tap()
        app.buttons["showSettings"].tap()
        XCTAssertTrue(app.buttons["theme-night"].waitForExistence(timeout: 8))
        app.buttons["theme-night"].tap()
        app.sliders["fontSize"].adjust(toNormalizedSliderPosition: 0.55)
        app.buttons["closeSettings"].tap()
        let night = XCTAttachment(screenshot: app.screenshot()); night.name = "03-夜读"; night.lifetime = .keepAlways; add(night)
        app.buttons["backToLibrary"].tap()
        app.terminate()
        app.launch()
        app.buttons["continueReading"].tap()
        XCTAssertTrue(app.staticTexts["readingProgress"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["readingProgress"].label.hasPrefix("2 / 50"))
        app.buttons["showContents"].tap()
        app.segmentedControls.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "书签")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["第02章 雪中来信"].waitForExistence(timeout: 5))
        app.buttons["closeContents"].tap()
        app.buttons["showSettings"].tap()
        app.buttons["theme-paper"].tap()
        app.buttons["closeSettings"].tap()
    }

    @MainActor
    func testSearchWholeBook() throws {
        let app = XCUIApplication(); app.launch()
        app.buttons["continueReading"].tap()
        XCTAssertTrue(app.buttons["searchNovel"].waitForExistence(timeout: 10))
        app.buttons["searchNovel"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap(); field.typeText("合欢铃")
        XCTAssertTrue(app.buttons["searchResult-0"].waitForExistence(timeout: 12))
        app.buttons["searchResult-0"].tap()
        XCTAssertTrue(app.staticTexts["readingProgress"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["readingProgress"].label.hasPrefix("1 / 50"))
        let search = XCTAttachment(screenshot: app.screenshot()); search.name = "04-搜索定位"; search.lifetime = .keepAlways; add(search)
    }
}
