import SwiftUI

/// 可选的主题色
enum ThemeColor: String, CaseIterable, Identifiable {
    case mint, ocean, indigo, lavender, sakura, coral, amber, forest, graphite

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mint: return "薄荷绿"
        case .ocean: return "海盐蓝"
        case .indigo: return "靛青"
        case .lavender: return "薰衣草"
        case .sakura: return "樱花粉"
        case .coral: return "珊瑚橙"
        case .amber: return "琥珀黄"
        case .forest: return "松针绿"
        case .graphite: return "石墨灰"
        }
    }

    var color: Color {
        switch self {
        case .mint: return Color(red: 0.188, green: 0.780, blue: 0.470)
        case .ocean: return Color(red: 0.180, green: 0.560, blue: 0.950)
        case .indigo: return Color(red: 0.345, green: 0.337, blue: 0.839)
        case .lavender: return Color(red: 0.600, green: 0.420, blue: 0.900)
        case .sakura: return Color(red: 0.930, green: 0.380, blue: 0.560)
        case .coral: return Color(red: 0.980, green: 0.450, blue: 0.330)
        case .amber: return Color(red: 0.930, green: 0.640, blue: 0.100)
        case .forest: return Color(red: 0.180, green: 0.520, blue: 0.360)
        case .graphite: return Color(red: 0.420, green: 0.450, blue: 0.500)
        }
    }
}

/// 外观：跟随系统 / 浅色 / 深色
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum Theme {
    static let colorKey = "themeColor"
    static let appearanceKey = "appearance"
}

private struct AccentKey: EnvironmentKey {
    static let defaultValue: Color = ThemeColor.mint.color
}

extension EnvironmentValues {
    /// 当前主题色
    var accent: Color {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}

/// 在根视图上应用主题
struct ThemedRoot<Content: View>: View {
    @AppStorage(Theme.colorKey) private var colorRaw = ThemeColor.mint.rawValue
    @AppStorage(Theme.appearanceKey) private var appearanceRaw = Appearance.system.rawValue

    @ViewBuilder var content: Content

    var body: some View {
        let color = (ThemeColor(rawValue: colorRaw) ?? .mint).color
        content
            .tint(color)
            .environment(\.accent, color)
            .preferredColorScheme((Appearance(rawValue: appearanceRaw) ?? .system).colorScheme)
    }
}
