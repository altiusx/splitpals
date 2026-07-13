//
//  SplitFlowUITests.swift
//  SplitPalsUITests
//
//  End-to-end smoke test for expense splitting and settle up:
//  onboarding → add friends → group with members → equal-split expense →
//  settle up → mark a payment as done.
//
//  Re-runnable: onboarding is skipped when a user already exists, and
//  friend/group names are suffixed to avoid collisions.
//

import XCTest

final class SplitFlowUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEqualSplitAndSettleUpFlow() throws {
        let suffix = String(Int(Date().timeIntervalSince1970) % 100000)
        let bob = "Bob\(suffix)"
        let carol = "Carol\(suffix)"
        let groupName = "Trip\(suffix)"

        let app = XCUIApplication()
        app.launch()

        // Onboarding (fresh install only)
        let nameField = app.textFields["Your name"]
        if nameField.waitForExistence(timeout: 3) {
            nameField.tap()
            nameField.typeText("Chris\n")
            app.buttons["Get Started"].tap()
        }

        attach(app, name: "01-groups")

        // Add two friends
        let friendsTab = app.buttons["Friends"]
        XCTAssertTrue(friendsTab.waitForExistence(timeout: 5))
        friendsTab.tap()
        for friend in [bob, carol] {
            app.buttons["Add Friend"].tap()
            let friendName = app.textFields["Name"]
            XCTAssertTrue(friendName.waitForExistence(timeout: 3))
            friendName.tap()
            friendName.typeText(friend + "\n")
            app.buttons["Save"].tap()
        }
        attach(app, name: "02-friends")

        // Create a group with both friends as members
        app.buttons["Groups"].tap()
        app.buttons["Add Group"].tap()
        let groupField = app.textFields["Group Name"]
        XCTAssertTrue(groupField.waitForExistence(timeout: 3))
        groupField.tap()
        groupField.typeText(groupName + "\n")
        app.staticTexts[bob].tap()
        app.staticTexts[carol].tap()
        attach(app, name: "03-add-group")
        app.buttons["Save"].tap()

        // Open the group
        let groupCard = app.staticTexts[groupName]
        XCTAssertTrue(groupCard.waitForExistence(timeout: 3))
        attach(app, name: "03b-group-card")
        groupCard.tap()

        // Add an equal-split expense of $10 paid by me
        app.buttons["Add Expense"].tap()
        let descriptionField = app.textFields["Description"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: 3))

        // Probe: Save must be disabled while the form is empty
        let saveButton = app.buttons["Save"]
        XCTAssertFalse(saveButton.isEnabled, "Save must be disabled for an empty expense")

        descriptionField.tap()
        descriptionField.typeText("Dinner\n")

        // Amount display, matched independently of the currency symbol
        app.staticTexts.matching(NSPredicate(format: "label ENDSWITH '0.00'")).firstMatch.tap()
        app.typeText("1000")

        // Probe: exact split with nothing assigned must disable Save
        app.swipeUp()
        let exactSegment = app.buttons["Exact Amounts"]
        if exactSegment.waitForExistence(timeout: 2) && exactSegment.isHittable {
            exactSegment.tap()
            XCTAssertFalse(saveButton.isEnabled, "Save must be disabled while exact amounts don't sum to the total")
            app.buttons["Equally"].tap()
        }
        XCTAssertTrue(saveButton.isEnabled)
        attach(app, name: "04-add-expense")
        saveButton.tap()

        // Expense row shows payer and split count
        let caption = app.staticTexts["Paid by Chris · Split 3 ways"]
        XCTAssertTrue(caption.waitForExistence(timeout: 3))
        attach(app, name: "05-expense-list")

        // Settle Up opens in Manual mode: both friends owe me
        app.buttons["Settle Up"].tap()
        let bobPays = app.staticTexts["\(bob) pays Chris (Me)"]
        let carolPays = app.staticTexts["\(carol) pays Chris (Me)"]
        XCTAssertTrue(bobPays.waitForExistence(timeout: 3))
        XCTAssertTrue(carolPays.exists)
        XCTAssertTrue(amountLabel(app, "3.34").exists || amountLabel(app, "3.33").exists)
        attach(app, name: "06-settle-up-manual")

        // Record a partial payment of $2 for the first debt
        app.buttons["Record a payment"].firstMatch.tap()
        let amountField = app.textFields["Amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        let prefilled = (amountField.value as? String) ?? ""
        amountField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prefilled.count + 1))
        amountField.typeText("2")
        attach(app, name: "07-record-payment")
        app.buttons["Record"].tap()

        // The debt shrinks by $2 and both debts remain
        XCTAssertTrue(amountLabel(app, "1.34").waitForExistence(timeout: 3) || amountLabel(app, "1.33").exists)
        XCTAssertTrue(bobPays.exists && carolPays.exists, "Partial payment must not clear either debt")

        // The payment appears in the history section at the bottom
        app.swipeUp()
        XCTAssertTrue(amountLabel(app, "2.00").waitForExistence(timeout: 3), "Recorded payment should be listed")
        attach(app, name: "08-after-partial")
        app.swipeDown()

        // One tap switches to the simplified (greedy) suggestions
        let simplifiedSegment = app.buttons["Simplified"]
        XCTAssertTrue(simplifiedSegment.waitForExistence(timeout: 3))
        simplifiedSegment.tap()

        // Mark the first suggested payment as done in full
        app.buttons["Mark payment as done"].firstMatch.tap()
        let alert = app.alerts["Mark as Paid?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Mark as Paid"].tap()

        // One transfer remains, the other person's row is gone
        XCTAssertTrue(carolPays.waitForExistence(timeout: 3) || bobPays.exists)
        XCTAssertFalse(bobPays.exists && carolPays.exists, "Settled transfer should disappear")
        attach(app, name: "09-after-settle")
    }

    /// Matches a formatted amount regardless of the currency symbol (e.g. "$3.34" or "S$3.34").
    private func amountLabel(_ app: XCUIApplication, _ digits: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", digits)).firstMatch
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
