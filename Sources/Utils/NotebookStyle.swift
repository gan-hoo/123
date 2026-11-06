import SwiftUI

/// 笔记本可选的颜色
enum NotebookColor: String, CaseIterable, Identifiable {
    case purple, blue, teal, green, yellow, orange, red, pink, brown, gray, black

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purple: return Color(red: 0.36, green: 0.33, blue: 0.93)
        case .blue: return Color(red: 0.18, green: 0.50, blue: 0.96)
        case .teal: return Color(red: 0.10, green: 0.68, blue: 0.72)
        case .green: return Color(red: 0.19, green: 0.70, blue: 0.40)
        case .yellow: return Color(red: 0.98, green: 0.92, blue: 0.40)
        case .orange: return Color(red: 0.98, green: 0.58, blue: 0.20)
        case .red: return Color(red: 0.92, green: 0.30, blue: 0.30)
        case .pink: return Color(red: 0.93, green: 0.42, blue: 0.62)
        case .brown: return Color(red: 0.80, green: 0.56, blue: 0.48)
        case .gray: return Color(red: 0.55, green: 0.57, blue: 0.60)
        case .black: return Color.primary
        }
    }
}

enum NotebookStyle {
    static let icons: [String] = [
        "book.closed.fill", "heart.fill", "star.fill", "moon.fill",
        "house.fill", "leaf.fill", "briefcase.fill", "graduationcap.fill",
        "airplane", "camera.fill", "music.note", "lightbulb.fill",
        "cart.fill", "pawprint.fill", "fork.knife", "figure.run",
        "sparkles", "folder.fill", "rectangle.stack.fill", "bubble.left.fill",
    ]
}

extension Notebook {
    var color: Color { (NotebookColor(rawValue: colorName) ?? .purple).color }
}
