import XCTest

final class PlayUITests: XCTestCase {
    static let shotDir = "/Users/apple/Documents/VirusHunter/shots"

    func save(_ app: XCUIApplication, _ name: String) {
        let png = app.screenshot().pngRepresentation
        try? FileManager.default.createDirectory(atPath: Self.shotDir, withIntermediateDirectories: true)
        try? png.write(to: URL(fileURLWithPath: "\(Self.shotDir)/\(name).png"))
        let att = XCTAttachment(screenshot: app.screenshot()); att.name = name; att.lifetime = .keepAlways; add(att)
    }

    /// A brand-new player lands straight in a Lungs run with the move hint.
    func testFirstLaunchStartsARun() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-resetProgress"]
        app.launch()
        XCTAssertTrue(app.buttons["pauseButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Drag anywhere to fly"].exists)
        sleep(1); save(app, "m01-first-run")
    }

    /// Menus: home → map → lab → skins.
    func testMenus() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-resetProgress", "-skipIntro", "-demoProgress"]
        app.launch()
        XCTAssertTrue(app.buttons["playButton"].waitForExistence(timeout: 10))
        sleep(1); save(app, "m04-home")
        app.buttons["playButton"].tap(); sleep(1); save(app, "m05-map")
        app.buttons["backButton"].tap(); sleep(1)
        app.buttons["labButton"].tap(); sleep(1); save(app, "m06-lab")
        app.buttons["backButton"].tap(); sleep(1)
        app.buttons["skinsButton"].tap(); sleep(1)
        app.buttons["skin-neon"].tap(); sleep(1); save(app, "m07-skins")
    }

    /// A real run with the autopilot: plays, levels up (auto-choose), screenshots along the way.
    func testAutoplayRun() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-skipIntro", "-autoplay", "-startStage", "1"]
        app.launch()
        sleep(4); save(app, "g01-start")
        sleep(8); save(app, "g02-early")
        // catch a level-up screen
        for i in 0..<20 {
            if app.buttons["upgrade0"].exists { save(app, "g03-levelup"); break }
            usleep(500_000)
            if i == 19 { save(app, "g03-nolevelup") }
        }
        sleep(15); save(app, "g04-mid")
        app.buttons["pauseButton"].tap(); sleep(1); save(app, "g05-pause")
        app.buttons["resumeButton"].tap()
        sleep(20); save(app, "g06-later")
    }

    /// Strong build late in the run, then the boss.
    func testBossFight() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-skipIntro", "-autoplay", "-god", "-demoLoadout", "-startStage", "1", "-startTime", "200"]
        app.launch()
        sleep(10); save(app, "b01-swarm")
        sleep(32); save(app, "b02-boss")
        sleep(12); save(app, "b03-boss2")
        for _ in 0..<60 {
            if app.buttons["continueButton"].exists { break }
            sleep(2)
        }
        save(app, "b04-result")
    }

    /// Store screenshot: boss on screen with a strong build.
    func testBossShot() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting", "-skipIntro", "-autoplay", "-god", "-demoLoadout", "-bossNear", "-startStage", "1", "-startTime", "236"]
        app.launch()
        sleep(7)
        for i in 1...6 {
            if app.buttons["upgrade0"].exists { app.buttons["upgrade0"].tap(); sleep(1) }
            save(app, "s0\(i)-boss"); sleep(2)
        }
    }
}
