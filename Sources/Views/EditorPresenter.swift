import SwiftUI
import Observation

/// 管理编辑器的打开 / 关闭。编辑器作为覆盖在主页上方的页面显示，
/// 这样从左边缘右滑时可以跟随手指、露出下面的主页。
@Observable
final class EditorPresenter {
    var isOpen = false {
        didSet { Self.isAnyOpen = isOpen }
    }
    /// 供 UIKit 手势判断编辑器是否打开
    static var isAnyOpen = false
    var memo: Memo?
    var presetTag: String?
    /// false：先以阅读模式打开，点「编辑」才开始编辑
    var startEditing = true
    /// 新建笔记时放入的笔记本
    var notebookID: UUID?
    /// 每次打开生成新的 id，让编辑器状态重新开始
    var session = UUID()
    /// 编辑器中是否有未保存的修改（右滑退出时用来决定是否提示）
    var dirty = false
    /// 右滑退出时递增，编辑器收到后执行「返回」逻辑（有修改会提示）
    var backTrigger = 0

    func open(memo: Memo?, presetTag: String? = nil, editing: Bool = true, notebookID: UUID? = nil) {
        self.memo = memo
        self.notebookID = notebookID
        self.presetTag = presetTag
        self.startEditing = editing || memo == nil
        session = UUID()
        dirty = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isOpen = true
        }
    }

    func close() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.95)) {
            isOpen = false
        }
    }
}
