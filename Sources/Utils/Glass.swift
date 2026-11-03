import SwiftUI

// 苹果 Liquid Glass（iOS 26+）。低版本系统自动退回毛玻璃材质。
// `#if compiler(>=6.2)` 保证用旧版 Xcode 也能编译。

extension View {
    /// 玻璃卡片 / 面板
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            self.legacyGlass(shape, tint: tint)
        }
        #else
        self.legacyGlass(shape, tint: tint)
        #endif
    }

    /// 玻璃胶囊（标签、小按钮）
    @ViewBuilder
    func glassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: Capsule())
        } else {
            self.legacyGlass(Capsule(), tint: tint)
        }
        #else
        self.legacyGlass(Capsule(), tint: tint)
        #endif
    }

    /// 玻璃圆形
    @ViewBuilder
    func glassCircle(tint: Color? = nil, interactive: Bool = true) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint).interactive(interactive), in: Circle())
        } else {
            self.legacyGlass(Circle(), tint: tint)
        }
        #else
        self.legacyGlass(Circle(), tint: tint)
        #endif
    }

    private func legacyGlass<S: InsettableShape>(_ shape: S, tint: Color?) -> some View {
        self
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint.opacity(0.35)) }
                }
            }
            .overlay { shape.strokeBorder(.white.opacity(0.25), lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }

    /// 把一组相邻的玻璃元素放在一起渲染（iOS 26 会互相融合）
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 12) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// 全局背景：柔和的主题色光斑，让玻璃有东西可以折射
struct AppBackground: View {
    @Environment(\.accent) private var accent
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                Color(.systemGroupedBackground)
                Circle()
                    .fill(accent.opacity(scheme == .dark ? 0.45 : 0.30))
                    .frame(width: w * 1.1)
                    .blur(radius: 90)
                    .offset(x: -w * 0.45, y: -geo.size.height * 0.32)
                Circle()
                    .fill(accent.opacity(scheme == .dark ? 0.30 : 0.20))
                    .hueRotation(.degrees(35))
                    .frame(width: w * 0.9)
                    .blur(radius: 100)
                    .offset(x: w * 0.5, y: geo.size.height * 0.05)
                Circle()
                    .fill(accent.opacity(scheme == .dark ? 0.35 : 0.22))
                    .hueRotation(.degrees(-30))
                    .frame(width: w)
                    .blur(radius: 110)
                    .offset(x: -w * 0.2, y: geo.size.height * 0.42)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
