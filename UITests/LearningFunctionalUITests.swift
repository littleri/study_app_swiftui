import XCTest

/// Real gestures, form input, navigation and relaunches against bundled content.
/// Tests use a fresh persisted fixture session and do not inject learning results.
final class LearningFunctionalUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .portrait
  }

  private func launch(_ route: String, session: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--fixture", "--fixture-session", session, "--route", route, "--chapter", "c2s1",
    ]
    app.launch()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
    return app
  }

  private func wait(
    _ message: String, timeout: TimeInterval = 12, _ condition: @escaping () -> Bool
  ) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in condition() }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, message)
  }

  private func reveal(_ element: XCUIElement, app: XCUIApplication) {
    _ = element.waitForExistence(timeout: 2)
    let gutter: CGFloat = app.windows.firstMatch.frame.width < 700 ? 0.08 : 0.95
    for _ in 0..<16 {
      // LazyVGrid descendants do not exist in the accessibility tree until
      // scrolled near the viewport, especially on iPhone.
      if element.exists && element.isHittable { return }
      app.coordinate(withNormalizedOffset: CGVector(dx: gutter, dy: 0.78))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: gutter, dy: 0.30)))
    }
    XCTAssertTrue(element.exists, "Missing control after scrolling: \(element)")
    XCTAssertTrue(element.isHittable, "Control remained outside viewport: \(element)")
  }

  private func tap(_ element: XCUIElement, app: XCUIApplication) {
    reveal(element, app: app)
    XCTAssertTrue(element.isEnabled)
    element.tap()
  }

  private func dismissKeyboard(_ app: XCUIApplication) {
    let keyboard = app.keyboards.firstMatch
    guard keyboard.exists else { return }
    let hide = keyboard.buttons.matching(
      NSPredicate(format: "label IN %@", ["Hide keyboard", "隐藏键盘", "收起键盘"])
    ).firstMatch
    let done = app.buttons["learning.keyboard.done"].firstMatch
    if done.exists {
      XCTAssertTrue(
        done.isHittable, "Completion control should remain reachable above the keyboard")
      done.tap()
    } else if hide.exists {
      hide.tap()
    } else {
      XCTFail("Expected a reachable completion control or the system Hide Keyboard key")
    }
    wait("The system keyboard should dismiss before scrolling") { !keyboard.exists }
  }

  private func evidence(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testAssignmentDiagnosisMistakeRedoAndMasteryPersist() throws {
    let session = UUID().uuidString
    let app = launch("assignment", session: session)
    let submit = app.buttons["assignment.submit"].firstMatch
    XCTAssertTrue(submit.waitForExistence(timeout: 20))
    XCTAssertFalse(submit.isEnabled, "Unanswered objective questions must not advance")
    tap(app.buttons["assignment.judgment.错误"], app: app)
    tap(submit, app: app)
    XCTAssertTrue(app.buttons["assignment.choice.A"].waitForExistence(timeout: 10))
    XCTAssertFalse(submit.isEnabled)
    tap(app.buttons["assignment.choice.A"], app: app)
    tap(submit, app: app)
    let shortAnswer = app.textViews.firstMatch
    reveal(shortAnswer, app: app)
    shortAnswer.tap()
    shortAnswer.typeText("Functional test: a deliberately incomplete meiosis explanation.")
    XCTAssertTrue((shortAnswer.value as? String ?? "").contains("deliberately incomplete"))
    dismissKeyboard(app)
    tap(submit, app: app)
    XCTAssertTrue(app.staticTexts["诊断解析"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.staticTexts["需要再巩固"].exists)
    evidence("learning-submitted-real-answers-diagnosis", app: app)
    tap(app.buttons["diagnosis.continue"], app: app)
    // Select the new objective-error record produced by this submission, not
    // the pre-existing demonstration mistake seeded with the textbook.
    let recordID = "mistake_quiz_c2s1_01"
    tap(app.buttons["mistake.select." + recordID], app: app)
    let redoID = "mistake.redo." + recordID
    let redo = app.buttons[redoID]
    reveal(redo, app: app)
    redo.tap()
    let compare = app.buttons["mistake.compare"]
    tap(compare, app: app)
    XCTAssertTrue(app.staticTexts["请先写下你的答案，再对照解析。"].waitForExistence(timeout: 5))
    let answer = app.textViews.firstMatch
    reveal(answer, app: app)
    answer.tap()
    answer.typeText("Homologous chromosomes separate first; sister chromatids separate later.")
    XCTAssertTrue((answer.value as? String ?? "").contains("Homologous"))
    dismissKeyboard(app)
    tap(compare, app: app)
    XCTAssertTrue(app.staticTexts["我的新答案"].waitForExistence(timeout: 10))
    tap(app.buttons["概念混淆"], app: app)
    let mastered = app.buttons["mistake.mastery.mastered"]
    tap(mastered, app: app)
    wait("Mastery selection should update") { mastered.value as? String == "selected" }
    evidence("learning-mistake-redone-and-mastered", app: app)
    tap(app.buttons["mistake.finish"], app: app)
    app.terminate()

    let reopened = launch("mistakes", session: session)
    tap(reopened.buttons["mistake.select." + recordID], app: reopened)
    tap(reopened.buttons[redoID], app: reopened)
    tap(reopened.buttons["填入上次答案"], app: reopened)
    tap(reopened.buttons["mistake.compare"], app: reopened)
    let restoredMastery = reopened.buttons["mistake.mastery.mastered"]
    reveal(restoredMastery, app: reopened)
    XCTAssertEqual(
      restoredMastery.value as? String, "selected", "Mastery must survive an application relaunch")
    evidence("learning-mistake-mastery-restored", app: reopened)
  }

  private func turnPage(_ app: XCUIApplication, forward: Bool) {
    let start = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.77 : 0.23, dy: 0.42))
    let end = app.coordinate(withNormalizedOffset: CGVector(dx: forward ? 0.23 : 0.77, dy: 0.42))
    start.press(forDuration: 0.08, thenDragTo: end)
  }

  private func returnToIntroduction(_ app: XCUIApplication) {
    let page = app.staticTexts["lesson.page"].firstMatch
    XCTAssertTrue(page.waitForExistence(timeout: 20))
    for _ in 0..<5 {
      if page.value as? String == "1" { return }
      let previous = page.value as? String
      turnPage(app, forward: false)
      wait("Backward page gesture should restore the introduction") {
        page.value as? String != previous
      }
    }
    XCTAssertEqual(page.value as? String, "1")
  }

  func testLessonPagingConceptDismissalAndCompletion() throws {
    let session = UUID().uuidString
    let app = launch("lesson", session: session)
    let page = app.staticTexts["lesson.page"].firstMatch
    XCTAssertTrue(page.waitForExistence(timeout: 20))
    returnToIntroduction(app)
    XCTAssertEqual(page.value as? String, "1")
    tap(app.buttons["lesson.concept"], app: app)
    let close = app.buttons["lesson.concept.close"]
    XCTAssertTrue(close.waitForExistence(timeout: 8))
    XCTAssertTrue(app.staticTexts["核心概念"].exists)
    close.tap()
    wait("Concept overlay should dismiss") { !close.exists }
    turnPage(app, forward: true)
    wait("Forward gesture should change the actual lesson page") { page.value as? String == "2" }
    turnPage(app, forward: false)
    wait("Backward gesture should restore introduction") { page.value as? String == "1" }
    for number in 2...5 {
      turnPage(app, forward: true)
      wait("Lesson page \(number) should be reachable") { page.value as? String == String(number) }
    }
    evidence("learning-last-lesson-page", app: app)
    tap(app.buttons["完成本节"].firstMatch, app: app)
    XCTAssertTrue(app.staticTexts["学习计划"].firstMatch.waitForExistence(timeout: 10))
    app.terminate()
    let reopened = launch("lesson", session: session)
    XCTAssertTrue(reopened.staticTexts["lesson.page"].firstMatch.waitForExistence(timeout: 20))
    XCTAssertEqual(
      reopened.staticTexts["lesson.page"].firstMatch.value as? String, "5",
      "Reading position must survive relaunch")
  }

  private func creditBalance(_ app: XCUIApplication) -> Int {
    let credits = app.staticTexts["lesson.video.credits"].firstMatch
    XCTAssertTrue(credits.waitForExistence(timeout: 10))
    return Int(credits.label.filter(\.isNumber)) ?? -1
  }

  func testVideoCancelPreservesCreditsAndBundledMP4ActuallyPlays() throws {
    let session = UUID().uuidString
    let app = launch("lesson", session: session)
    returnToIntroduction(app)
    let open = app.buttons["lesson.video.open.asset_ai_meiosis_dna_replication_v1"]
    tap(open, app: app)
    let initialBalance = creditBalance(app)
    XCTAssertGreaterThanOrEqual(initialBalance, 10)
    tap(app.buttons["lesson.video.cancel"], app: app)
    wait("Cancellation must close the confirmation") { !app.buttons["lesson.video.confirm"].exists }
    tap(open, app: app)
    XCTAssertEqual(
      creditBalance(app), initialBalance, "Cancelling the confirmation must not spend credits")
    tap(app.buttons["lesson.video.confirm"], app: app)
    let player = app.descendants(matching: .any)["lesson.video.player"].firstMatch
    XCTAssertTrue(player.waitForExistence(timeout: 20))
    wait("Real AVPlayer time must advance while playing the bundled MP4", timeout: 15) {
      (Double(player.value as? String ?? "") ?? 0) >= 0.5
    }
    let playback = XCTAttachment(
      string:
        "AVPlayer periodic currentTime: \(player.value as? String ?? "missing") seconds; asserted >= 0.5. Credit balance before confirmation: \(initialBalance)."
    )
    playback.name = "learning-video-live-playback-measurement"
    playback.lifetime = .keepAlways
    add(playback)
    evidence("learning-bundled-mp4-real-playback", app: app)
    tap(app.buttons["lesson.video.close"], app: app)
    tap(open, app: app)
    XCTAssertEqual(
      creditBalance(app), initialBalance - 10, "Successful playback must charge exactly once")
    tap(app.buttons["lesson.video.cancel"], app: app)
    app.terminate()
    let reopened = launch("lesson", session: session)
    tap(reopened.buttons["lesson.video.open.asset_ai_meiosis_dna_replication_v1"], app: reopened)
    XCTAssertEqual(
      creditBalance(reopened), initialBalance - 10,
      "The completed video credit transaction must persist")
    tap(reopened.buttons["lesson.video.cancel"], app: reopened)
  }
}
