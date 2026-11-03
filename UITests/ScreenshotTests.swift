import XCTest

/// 生成界面截图（浅色 / 深色），供 CI 导出查看
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func run(appearance: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-appearance", appearance]
        app.launch()
        sleep(2)
        shoot(app, "\(appearance)-1-home")

        // 侧边栏
        let menu = app.buttons["menuButton"]
        if menu.waitForExistence(timeout: 3) {
            menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(1)
            shoot(app, "\(appearance)-2-drawer")
            app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            sleep(1)
        }

        // 新建笔记
        let add = app.buttons["newMemo"]
        if add.waitForExistence(timeout: 3) {
            add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            sleep(2)
            app.typeText("今天读到一句话 #读书")
            sleep(1)
            shoot(app, "\(appearance)-3-composer")
        }
        app.terminate()
    }

    func testScreenshotsLight() { run(appearance: "light") }
    func testScreenshotsDark() { run(appearance: "dark") }
}
