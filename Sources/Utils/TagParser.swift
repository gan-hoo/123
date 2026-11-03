import SwiftUI

struct TagCount: Identifiable, Hashable {
    let tag: String
    let count: Int
    var id: String { tag }
    var depth: Int { tag.split(separator: "/").count - 1 }
    var leaf: String { String(tag.split(separator: "/").last ?? Substring(tag)) }
}

enum TagParser {
    static let tagScheme = "shinian-tag"

    /// `#标签` 前面必须是开头或空白；支持多级标签 `#读书/小说`
    static let regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "(?<![^\\s])#([\\p{L}\\p{N}_/\\-]+)")
    }()

    static func tags(in text: String) -> [String] {
        let ns = text as NSString
        var result: [String] = []
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let raw = ns.substring(with: m.range(at: 1))
            let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if !name.isEmpty && !result.contains(name) {
                result.append(name)
            }
        }
        return result
    }

    /// "a/b/c" -> ["a", "a/b", "a/b/c"]
    static func expand(_ tag: String) -> [String] {
        let parts = tag.split(separator: "/").map(String.init)
        var out: [String] = []
        for i in parts.indices {
            out.append(parts[0...i].joined(separator: "/"))
        }
        return out
    }

    static func tagCounts(from memos: [Memo]) -> [TagCount] {
        var counts: [String: Int] = [:]
        for memo in memos {
            var seen = Set<String>()
            for tag in memo.tags {
                for t in expand(tag) where !seen.contains(t) {
                    seen.insert(t)
                    counts[t, default: 0] += 1
                }
            }
        }
        return counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    static func allTags(from memos: [Memo]) -> [String] {
        tagCounts(from: memos).map(\.tag)
    }

    /// 生成带标签高亮（并可点击）的富文本
    static func attributed(_ text: String, accent: Color) -> AttributedString {
        let ns = text as NSString
        var result = AttributedString()
        var last = 0
        for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                let plain = ns.substring(with: NSRange(location: last, length: m.range.location - last))
                result += AttributedString(plain)
            }
            let full = ns.substring(with: m.range)
            let name = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            var piece = AttributedString(full)
            piece.foregroundColor = accent
            piece.backgroundColor = accent.opacity(0.12)
            var comps = URLComponents()
            comps.scheme = tagScheme
            comps.host = "tag"
            comps.queryItems = [URLQueryItem(name: "name", value: name)]
            if let url = comps.url {
                piece.link = url
            }
            result += piece
            last = m.range.location + m.range.length
        }
        if last < ns.length {
            result += AttributedString(ns.substring(from: last))
        }
        return result
    }

    static func tagName(from url: URL) -> String? {
        guard url.scheme == tagScheme,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        return comps.queryItems?.first(where: { $0.name == "name" })?.value
    }
}
