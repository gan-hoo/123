import SwiftUI

// Apple 原生 Liquid Glass（iOS 26+）。
// 原则：玻璃只用在「控件层」（按钮、工具条、导航），内容（笔记卡片）保持实色。
// iOS 26 以下自动沿用原来的白色圆角样式。

enum Glass {
    /// 当前系统是否使用 Liquid Glass
    static var enabled: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }
}

extension View {
    /// 系统玻璃按钮样式（.glass / .glassProminent）；旧系统不做改动
    @ViewBuilder
    func glassButton(prominent: Bool = false, tint: Color? = nil,
                     shape: ButtonBorderShape = .circle) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent).buttonBorderShape(shape).tint(tint)
            } else {
                self.buttonStyle(.glass).buttonBorderShape(shape).tint(tint)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// 一组按钮共用的背景（如工具条、撤销/重做）：iOS 26 为系统玻璃，旧系统为白色描边阴影
struct GlassShapeBackground<S: Shape>: View {
    let shape: S

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: shape)
                .allowsHitTesting(false)
        } else {
            legacy
        }
        #else
        legacy
        #endif
    }

    private var legacy: some View {
        shape
            .fill(Color(.systemBackground))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }
}
