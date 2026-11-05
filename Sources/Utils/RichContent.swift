import Foundation

/// 图文混排：笔记正文中用 `[[img:KEY]]` 标记图片所在位置
enum RichContent {
    static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "\\[\\[img:([A-Za-z0-9\\-]+)\\]\\]")
    }()

    static func marker(_ key: String) -> String { "[[img:\(key)]]" }

    enum Segment: Identifiable {
        case text(String, Int)
        case image(String, Int)

        var id: Int {
            switch self {
            case .text(_, let i), .image(_, let i): return i
            }
        }
    }

    /// 拆成「文字段 / 图片段」，文字段去掉两端多余换行，空段落省略
    static func segments(_ content: String) -> [Segment] {
        let ns = content as NSString
        var result: [Segment] = []
        var last = 0
        var n = 0
        func addText(_ s: String) {
            let t = s.trimmingCharacters(in: .newlines)
            if !t.trimmingCharacters(in: .whitespaces).isEmpty {
                result.append(.text(t, n)); n += 1
            }
        }
        for m in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                addText(ns.substring(with: NSRange(location: last, length: m.range.location - last)))
            }
            result.append(.image(ns.substring(with: m.range(at: 1)), n)); n += 1
            last = m.range.location + m.range.length
        }
        if last < ns.length {
            addText(ns.substring(from: last))
        }
        return result
    }

    /// 正文中引用到的图片 key（按出现顺序，去重）
    static func referencedKeys(_ content: String) -> [String] {
        let ns = content as NSString
        var keys: [String] = []
        for m in regex.matches(in: content, range: NSRange(location: 0, length: ns.length)) {
            let k = ns.substring(with: m.range(at: 1))
            if !keys.contains(k) { keys.append(k) }
        }
        return keys
    }

    /// 去掉图片标记的纯文字（用于字数、搜索、复制、分享）
    static func plainText(_ content: String) -> String {
        let ns = content as NSString
        let stripped = regex.stringByReplacingMatches(in: content, range: NSRange(location: 0, length: ns.length), withTemplate: "")
        return stripped
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 图片标记显示为「[图片]」（用于历史版本、导出等纯文字场景）
    static func displayText(_ content: String) -> String {
        let ns = content as NSString
        return regex.stringByReplacingMatches(in: content, range: NSRange(location: 0, length: ns.length), withTemplate: "[图片]")
    }
}
