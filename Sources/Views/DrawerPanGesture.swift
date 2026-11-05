import SwiftUI
import UIKit

/// 侧边栏拖动手势（UIKit 实现）。
/// 开始时先判断方向：水平滑动才会被识别为侧边栏手势，此时列表等滚动视图不会跟着上下滚动；
/// 垂直滑动则立即放行给滚动视图。
struct DrawerPanGesture: UIViewRepresentable {
    var isOpen: Bool
    var canOpen: Bool
    var edgeWidth: CGFloat
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void
    /// 编辑器打开时：从左边缘右滑退出编辑器
    var editorOpen: Bool = false
    var onEditorChanged: (CGFloat) -> Void = { _ in }
    var onEditorEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: InstallerView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ view: InstallerView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    /// 透明占位视图：进入窗口后把手势挂到窗口上
    final class InstallerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.install(on: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: DrawerPanGesture
        private var pan: UIPanGestureRecognizer?
        private weak var hostWindow: UIWindow?

        init(_ parent: DrawerPanGesture) {
            self.parent = parent
        }

        func install(on window: UIWindow?) {
            guard let window, hostWindow !== window else { return }
            uninstall()
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            recognizer.delegate = self
            recognizer.maximumNumberOfTouches = 1
            window.addGestureRecognizer(recognizer)
            pan = recognizer
            hostWindow = window
        }

        func uninstall() {
            if let pan {
                pan.view?.removeGestureRecognizer(pan)
            }
            pan = nil
            hostWindow = nil
        }

        /// 本次手势是否用于退出编辑器
        private var editorMode = false

        @objc private func handle(_ g: UIPanGestureRecognizer) {
            let tx = g.translation(in: g.view).x
            if g.state == .began {
                editorMode = parent.editorOpen
            }
            switch g.state {
            case .began, .changed:
                if editorMode { parent.onEditorChanged(tx) } else { parent.onChanged(tx) }
            case .ended, .cancelled, .failed:
                let vx = g.velocity(in: g.view).x
                if editorMode { parent.onEditorEnded(tx, vx) } else { parent.onEnded(tx, vx) }
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
            guard let pan = g as? UIPanGestureRecognizer, let view = pan.view else { return false }

            // 有弹窗（编辑笔记、看图）时不拦截
            if let window = view as? UIWindow,
               window.rootViewController?.presentedViewController != nil {
                return false
            }

            let t = pan.translation(in: view)
            let v = pan.velocity(in: view)
            // 以速度方向为主判断（比开始时几像素的位移更可靠）
            let dx = abs(v.x) + abs(v.y) > 1 ? v.x : t.x
            let dy = abs(v.x) + abs(v.y) > 1 ? v.y : t.y

            let startX = pan.location(in: view).x - t.x

            // 编辑器打开时：只接受从左边缘开始的右滑
            if parent.editorOpen {
                return startX <= 44 && dx > 0 && abs(dx) > abs(dy) * 0.7
            }

            let nearEdge = !parent.isOpen && startX <= parent.edgeWidth
            // 水平分量占优即可（约 45°），左边缘附近更宽松（约 55°）
            guard abs(dx) > abs(dy) * (nearEdge ? 0.7 : 0.95) else { return false }

            if parent.isOpen {
                return dx < 0
            }
            guard parent.canOpen, dx > 0 else { return false }
            // 主页任意位置向右滑都可以拉出侧边栏
            return true
        }

        /// 让滚动视图等待本手势判定失败后再开始，避免两者同时响应
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other.view is UIScrollView
        }
    }
}
