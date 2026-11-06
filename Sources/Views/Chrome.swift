import SwiftUI
import UIKit

// 统一的按钮外观：白色圆形 / 胶囊 + 细边 + 柔和阴影（深色模式用浅一点的灰）

extension Color {
    /// 按钮底色：浅色模式白色，深色模式比背景稍亮
    static let chromeFill = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
    })
}

struct ChromeBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        shape
            .fill(Color.chromeFill)
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}

/// 圆形图标按钮
struct RoundIconButton: View {
    let systemName: String
    var size: CGFloat = 40
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(ChromeBackground(shape: Circle()))
        }
        .buttonStyle(.plain)
    }
}

/// 二级页面统一的圆形返回按钮（保留右滑返回）
private struct RoundBackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RoundIconButton(systemName: "chevron.left") { dismiss() }
                        .accessibilityIdentifier("navBack")
                        .accessibilityLabel("返回")
                }
            }
    }
}

extension View {
    func roundBackButton() -> some View { modifier(RoundBackButton()) }
}

/// 隐藏系统返回按钮后，仍然可以从左边缘右滑返回
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 编辑器打开时由编辑器自己的右滑退出处理
        viewControllers.count > 1 && !EditorPresenter.isAnyOpen
    }
}
