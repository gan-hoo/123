import XCTest

/// 侧边栏手势的自动化测试：在模拟器上模拟真实手指拖动
final class DrawerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        XCTAssertTrue(waitDrawer(open: false), "启动时侧边栏应为关闭")
    }

    // MARK: - Helpers

    /// 侧边栏中的「全部标签」标题：侧边栏关闭时对辅助功能隐藏
    private var sidebarMarker: XCUIElement { app.staticTexts["全部标签"] }

    private func isDrawerOpen() -> Bool {
        sidebarMarker.exists && sidebarMarker.isHittable
    }

    private func waitDrawer(open: Bool, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isDrawerOpen() == open { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return isDrawerOpen() == open
    }

    private func drag(_ from: CGVector, _ to: CGVector, velocity: XCUIGestureVelocity) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: from)
        let end = window.coordinate(withNormalizedOffset: to)
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: 0)
    }

    /// iOS 26 导航栏中直接 tap() 会因无障碍滚动失败，改为按坐标点击
    private func tapMenuButton() {
        let button = app.buttons["menuButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - 打开

    func testSlowDragFromMiddleOpens() {
        drag(CGVector(dx: 0.3, dy: 0.6), CGVector(dx: 0.75, dy: 0.6), velocity: .slow)
        XCTAssertTrue(waitDrawer(open: true), "从屏幕中间慢慢向右拖应打开侧边栏")
        snapshot("slow-drag-open")
    }

    func testQuickShortFlickOpens() {
        drag(CGVector(dx: 0.4, dy: 0.5), CGVector(dx: 0.62, dy: 0.5), velocity: .fast)
        XCTAssertTrue(waitDrawer(open: true), "轻快短促的右划应打开侧边栏")
    }

    func testDiagonalSwipeOpens() {
        drag(CGVector(dx: 0.2, dy: 0.45), CGVector(dx: 0.75, dy: 0.55), velocity: .default)
        XCTAssertTrue(waitDrawer(open: true), "略微斜向的右滑应打开侧边栏")
    }

    func testEdgeSwipeOpens() {
        drag(CGVector(dx: 0.02, dy: 0.5), CGVector(dx: 0.6, dy: 0.5), velocity: .default)
        XCTAssertTrue(waitDrawer(open: true), "从左边缘右滑应打开侧边栏")
    }

    func testSwipeOnCardOpens() {
        // 从第一张卡片上开始滑
        drag(CGVector(dx: 0.25, dy: 0.3), CGVector(dx: 0.8, dy: 0.32), velocity: .default)
        XCTAssertTrue(waitDrawer(open: true), "在卡片上右滑也应打开侧边栏")
    }

    func testMenuButtonOpens() {
        tapMenuButton()
        XCTAssertTrue(waitDrawer(open: true), "点击菜单按钮应打开侧边栏")
    }

    // MARK: - 不应打开

    func testVerticalScrollDoesNotOpen() {
        drag(CGVector(dx: 0.5, dy: 0.75), CGVector(dx: 0.55, dy: 0.3), velocity: .default)
        XCTAssertTrue(waitDrawer(open: false, timeout: 1.5), "上下滑动不应打开侧边栏")
    }

    func testLeftSwipeDoesNotOpen() {
        drag(CGVector(dx: 0.8, dy: 0.5), CGVector(dx: 0.2, dy: 0.5), velocity: .default)
        XCTAssertTrue(waitDrawer(open: false, timeout: 1.5), "向左滑不应打开侧边栏")
    }

    // MARK: - 关闭

    func testSwipeLeftCloses() {
        drag(CGVector(dx: 0.3, dy: 0.6), CGVector(dx: 0.8, dy: 0.6), velocity: .default)
        XCTAssertTrue(waitDrawer(open: true))
        drag(CGVector(dx: 0.7, dy: 0.5), CGVector(dx: 0.15, dy: 0.5), velocity: .default)
        XCTAssertTrue(waitDrawer(open: false), "向左滑应收起侧边栏")
    }

    func testTapContentCloses() {
        tapMenuButton()
        XCTAssertTrue(waitDrawer(open: true))
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(waitDrawer(open: false), "点击右侧主页区域应收起侧边栏")
    }

    // MARK: - 月历

    func testTapTodayInCalendarFiltersByDay() {
        tapMenuButton()
        XCTAssertTrue(waitDrawer(open: true))
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        let today = f.string(from: Date())
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", today + "，")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 3), "月历中应有今天的格子")
        cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(waitDrawer(open: false), "点日期后侧边栏应收起")
        XCTAssertTrue(app.navigationBars[today].waitForExistence(timeout: 3) || app.staticTexts[today].exists,
                      "主页标题应变为当天日期")
        snapshot("calendar-day-filter")
    }

    // MARK: - 新建笔记

    func testPlusButtonCreatesMemo() {
        let add = app.buttons["newMemo"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "点 ＋ 应打开编辑器")
        editor.tap()
        editor.typeText("自动化测试笔记 ")

        app.buttons["insertTag"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        editor.typeText("测试")
        XCTAssertTrue((editor.value as? String ?? "").contains("#测试"), "点 # 按钮应插入 #")
        snapshot("composer")

        app.buttons["sendMemo"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertFalse(editor.waitForExistence(timeout: 1.5) && editor.isHittable, "发送后编辑器应关闭")
        let created = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "自动化测试笔记")).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 3), "新笔记应出现在列表中")
        snapshot("memo-created")
    }

    // MARK: - 旧示例笔记改名迁移

    func testLegacySampleNotesRenamed() {
        app.terminate()
        app.launchArguments = ["-uiTesting", "-legacySeed"]
        app.launch()
        let welcome = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "欢迎使用 Jin Notes")).firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 5), "旧欢迎笔记应改为 Jin Notes")
        let legacy = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "闪念")).firstMatch
        XCTAssertFalse(legacy.exists, "示例笔记中不应再出现「闪念」")
        snapshot("legacy-migrated")
    }

    // MARK: - 历史版本

    private func tapCenter(_ e: XCUIElement) {
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func testEditCreatesRevisionHistory() {
        let menu = app.buttons["memoMenu"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 3))
        tapCenter(menu)
        let editItem = app.buttons["编辑"].firstMatch
        XCTAssertTrue(editItem.waitForExistence(timeout: 3))
        tapCenter(editItem)

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "应打开编辑器")
        editor.tap()
        editor.typeText("\n这是新增的一行")
        tapCenter(app.buttons["sendMemo"])

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "已编辑")).firstMatch
            .waitForExistence(timeout: 3), "编辑后卡片应显示「已编辑」")

        tapCenter(app.buttons["memoMenu"].firstMatch)
        let historyItem = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "历史版本")).firstMatch
        XCTAssertTrue(historyItem.waitForExistence(timeout: 3), "菜单中应有「历史版本」")
        tapCenter(historyItem)

        XCTAssertTrue(app.staticTexts["当前版本"].waitForExistence(timeout: 3), "历史列表应显示当前版本")
        snapshot("revision-list")

        // 打开旧版本，查看改动
        let cells = app.cells
        XCTAssertGreaterThanOrEqual(cells.count, 2, "应至少有当前版本和一个历史版本")
        tapCenter(cells.element(boundBy: 1))
        let added = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "这是新增的一行")).firstMatch
        XCTAssertTrue(added.waitForExistence(timeout: 3), "改动对比中应显示新增的行")
        XCTAssertTrue(app.buttons["restoreRevision"].exists, "历史版本应可恢复")
        snapshot("revision-diff")
    }

    // MARK: - 编辑器返回时的未保存提示

    func testBackWithChangesAsksToDiscard() {
        tapCenter(app.buttons["newMemo"])
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap()
        editor.typeText("不想保存的内容")
        tapCenter(app.buttons["composerBack"])
        let discard = app.buttons["放弃修改"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3), "有修改时返回应提示是否放弃")
        discard.tap()
        let leaked = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "不想保存的内容")).firstMatch
        XCTAssertFalse(leaked.waitForExistence(timeout: 1.5), "放弃后不应保存")
    }
}
