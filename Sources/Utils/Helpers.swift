import SwiftUI
import UIKit

enum Fmt {
    static let full: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    static let fileDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f
    }()

    static func relative(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0: return "今天"
        case 1: return "昨天"
        case 2..<365: return "\(days) 天前"
        default: return "\(days / 365) 年前"
        }
    }
}

enum ImageUtil {
    /// 缩放到最长边 1600 并压缩成 JPEG
    static func compress(_ data: Data, maxSide: CGFloat = 1600) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

enum Exporter {
    static func markdown(_ memos: [Memo]) -> String {
        var out = "# 拾念笔记导出\n\n导出时间：\(Fmt.full.string(from: Date()))\n共 \(memos.count) 条\n\n"
        for memo in memos.sorted(by: { $0.createdAt > $1.createdAt }) {
            out += "## \(Fmt.full.string(from: memo.createdAt))\n\n"
            out += memo.content
            let n = memo.images?.count ?? 0
            if n > 0 { out += "\n\n_(\(n) 张图片)_" }
            out += "\n\n---\n\n"
        }
        return out
    }

    static func writeMarkdown(_ memos: [Memo]) -> URL? {
        let name = "拾念导出-\(Fmt.fileDate.string(from: Date())).md"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try markdown(memos).write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
