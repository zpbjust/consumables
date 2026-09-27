//
//  comsuableUITests.swift
//  comsuableUITests
//
//  Created by Nash Zhou on 2026/9/16.
//

import XCTest

final class comsuableUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testFirstItemFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-test-data", "--reset-onboarding"]
        app.launch()

        let getStarted = app.buttons["welcomeGetStarted"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
        getStarted.tap()

        let addFirstItem = app.buttons["addFirstItem"]
        XCTAssertTrue(addFirstItem.waitForExistence(timeout: 5))
        addFirstItem.tap()

        let nameField = app.textFields["itemNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Kitchen water filter")
        XCTAssertTrue(app.keyboards.element.exists)
        app.navigationBars["Add item"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 2))

        let modelField = app.textFields["itemModelField"]
        modelField.tap()
        modelField.typeText("GXRLQK")
        app.swipeUp()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 2))

        let save = app.buttons["saveItemButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()

        XCTAssertTrue(app.staticTexts["Home Passport"].exists)
        XCTAssertFalse(app.textFields["homeSearchField"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "Add item").count, 1)
        XCTAssertFalse(app.staticTexts["Quick actions"].exists)
        XCTAssertFalse(app.staticTexts["Recent activity"].exists)
        XCTAssertFalse(app.buttons["View schedule"].exists)
        XCTAssertFalse(app.buttons["Open full schedule"].exists)

        let homeCard = app.buttons["homeCard-My home"]
        XCTAssertTrue(homeCard.waitForExistence(timeout: 5))
        homeCard.tap()
        app.buttons["All items"].tap()
        XCTAssertTrue(app.staticTexts["Kitchen water filter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["GXRLQK"].exists)

        app.buttons["Items"].tap()
        let stickyFilters = app.descendants(matching: .any)["itemsStickyFilters"]
        XCTAssertTrue(stickyFilters.waitForExistence(timeout: 3))
        app.swipeUp()
        XCTAssertTrue(stickyFilters.exists)
        XCTAssertTrue(app.textFields["itemSearchField"].isHittable)
    }
}
