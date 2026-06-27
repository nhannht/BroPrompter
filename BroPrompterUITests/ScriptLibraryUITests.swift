import XCTest

/// Layer 2 end-to-end tests (BROP-30): drive the real app through the script
/// library flows. Each launch uses the isolated `-uitests` store, reset unless a
/// test needs data to survive a relaunch.
@MainActor
final class ScriptLibraryUITests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testCreateScriptAddsRow() {
    let app = launchApp()
    XCTAssertTrue(app.staticTexts["No Scripts"].waitForExistence(timeout: defaultTimeout))

    app.buttons["New Script"].firstMatch.click()

    XCTAssertTrue(app.staticTexts["Untitled Script"].waitForExistence(timeout: defaultTimeout))
    XCTAssertTrue(app.textFields["scriptTitleField"].waitForExistence(timeout: defaultTimeout))
  }

  func testCreateViaCommandNShortcut() {
    let app = launchApp()
    app.typeKey("n", modifierFlags: .command)
    XCTAssertTrue(app.staticTexts["Untitled Script"].waitForExistence(timeout: defaultTimeout))
  }

  func testEditTitleAndBodyUpdatesSidebarAndFooter() {
    let app = launchApp()
    createScript(in: app)

    let title = app.textFields["scriptTitleField"]
    XCTAssertTrue(title.waitForExistence(timeout: defaultTimeout))
    title.click()
    title.typeText("Keynote")
    XCTAssertTrue(app.staticTexts["Keynote"].waitForExistence(timeout: defaultTimeout))

    let body = app.textViews["scriptBodyEditor"]
    body.click()
    body.typeText("one two three")
    XCTAssertTrue(app.staticTexts["3 words"].waitForExistence(timeout: defaultTimeout))
  }

  func testSearchFiltersList() {
    let app = launchApp()
    createScript(in: app, title: "Alpha")
    createScript(in: app, title: "Beta")

    let search = app.searchFields["Search scripts"]
    XCTAssertTrue(search.waitForExistence(timeout: defaultTimeout))
    search.click()
    search.typeText("Alpha")

    XCTAssertTrue(app.staticTexts["Alpha"].waitForExistence(timeout: defaultTimeout))
    XCTAssertFalse(app.staticTexts["Beta"].exists)
  }

  func testDeleteRemovesScript() {
    let app = launchApp()
    createScript(in: app, title: "Doomed")

    app.menuBars.menuBarItems["Script"].click()
    app.menuBars.menuItems["Delete Script"].click()

    // Scope to the alert sheet: macOS also surfaces a "Delete" button on the
    // Touch Bar for the default action, which makes a bare query ambiguous.
    let deleteButton = app.sheets.buttons["Delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: defaultTimeout))
    deleteButton.click()

    XCTAssertFalse(app.staticTexts["Doomed"].waitForExistence(timeout: shortTimeout))
  }

  func testPlayInTeleprompterMenuItemDisabled() {
    let app = launchApp()
    app.menuBars.menuBarItems["Script"].click()
    let play = app.menuBars.menuItems["Play in Teleprompter"]
    XCTAssertTrue(play.waitForExistence(timeout: defaultTimeout))
    XCTAssertFalse(play.isEnabled)
    app.typeKey(.escape, modifierFlags: [])
  }

  func testImportCreatesScriptFromInjectedFile() {
    let app = launchApp(environment: [
      "UITEST_IMPORT_TITLE": "Imported Talk",
      "UITEST_IMPORT_BODY": "hello from a file",
    ])

    // Cmd-Shift-I (Import Text File) avoids matching the menu title's ellipsis.
    app.typeKey("i", modifierFlags: [.command, .shift])

    XCTAssertTrue(app.staticTexts["Imported Talk"].waitForExistence(timeout: defaultTimeout))
  }

  func testScriptsPersistAcrossRelaunch() {
    let app = launchApp()
    createScript(in: app, title: "Persisted Talk")
    app.typeKey("s", modifierFlags: .command)
    app.terminate()

    let relaunched = launchApp(reset: false)
    XCTAssertTrue(relaunched.staticTexts["Persisted Talk"].waitForExistence(timeout: defaultTimeout))
  }

  // MARK: Private

  private let defaultTimeout: TimeInterval = 10
  private let shortTimeout: TimeInterval = 3

  private func launchApp(
    reset: Bool = true,
    environment: [String: String] = [:]
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = reset ? ["-uitests", "-uitestsReset"] : ["-uitests"]
    app.launchEnvironment.merge(environment) { _, new in new }
    app.launch()
    return app
  }

  private func createScript(in app: XCUIApplication, title: String? = nil) {
    app.buttons["New Script"].firstMatch.click()
    guard let title else { return }
    let field = app.textFields["scriptTitleField"]
    XCTAssertTrue(field.waitForExistence(timeout: defaultTimeout))
    field.click()
    field.typeText(title)
    XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: defaultTimeout))
  }
}
