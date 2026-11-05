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

        // 下滑列表后的顶部
        let win = app.windows.firstMatch
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(forDuration: 0.05, thenDragTo: win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        sleep(1)
        shoot(app, "\(appearance)-1b-home-scrolled")
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
            .press(forDuration: 0.05, thenDragTo: win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        sleep(1)

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
            let editor = app.textViews.firstMatch
            if editor.waitForExistence(timeout: 3) {
                editor.tap()
                editor.typeText("今天读到一句话 #读书")
            }
            sleep(1)
            shoot(app, "\(appearance)-3-composer")
        }
        // 编辑已有笔记（全屏）
        let back = app.buttons["composerBack"]
        if back.exists {
            back.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let discard = app.buttons["放弃修改"]
            if discard.waitForExistence(timeout: 2) {
                discard.tap()
            }
            sleep(1)
        }
        let cardMenu = app.buttons["memoMenu"].firstMatch
        if cardMenu.waitForExistence(timeout: 3) {
            cardMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let edit = app.buttons["编辑"].firstMatch
            if edit.waitForExistence(timeout: 3) {
                edit.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                sleep(2)
                shoot(app, "\(appearance)-4-edit")
            }
        }
        app.terminate()
    }

    func testScreenshotsLight() { run(appearance: "light") }
    func testScreenshotsDark() { run(appearance: "dark") }
}
