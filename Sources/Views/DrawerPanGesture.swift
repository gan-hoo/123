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

        @objc private func handle(_ g: UIPanGestureRecognizer) {
            let tx = g.translation(in: g.view).x
            switch g.state {
            case .began, .changed:
                parent.onChanged(tx)
            case .ended, .cancelled, .failed:
                parent.onEnded(tx, g.velocity(in: g.view).x)
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
            let dx = t.x != 0 ? t.x : v.x
            let dy = t.y != 0 ? t.y : v.y

            let startX = pan.location(in: view).x - t.x
            let nearEdge = !parent.isOpen && startX <= parent.edgeWidth
            // 以水平方向为主，垂直滑动交给列表滚动；左边缘附近更宽松
            guard abs(dx) > abs(dy) * (nearEdge ? 0.7 : 1.0) else { return false }

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
