import Foundation
import SwiftData

@Model
final class Memo {
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    /// 非空表示已移入回收站
    var trashedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \MemoImage.memo)
    var images: [MemoImage]? = []

    init(content: String, createdAt: Date = Date()) {
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// 笔记中出现的标签（不含 #）
    var tags: [String] { TagParser.tags(in: content) }

    var sortedImages: [MemoImage] {
        (images ?? []).sorted { $0.order < $1.order }
    }

    /// 是否属于某个标签（含子标签）
    func has(tag: String) -> Bool {
        tags.contains { $0 == tag || $0.hasPrefix(tag + "/") }
    }
}

@Model
final class MemoImage {
    @Attribute(.externalStorage) var data: Data = Data()
    var order: Int = 0
    var memo: Memo?

    init(data: Data, order: Int) {
        self.data = data
        self.order = order
    }
}

enum MemoFilter: Hashable {
    case all
    case pinned
    case tag(String)
    /// 某一天的笔记（取当天 00:00）
    case day(Date)

    var title: String {
        switch self {
        case .all: return "全部笔记"
        case .pinned: return "置顶"
        case .tag(let t): return "#" + t
        case .day(let d): return Fmt.dayTitle.string(from: d)
        }
    }

    func matches(_ memo: Memo) -> Bool {
        switch self {
        case .all: return true
        case .pinned: return memo.isPinned
        case .tag(let t): return memo.has(tag: t)
        case .day(let d): return Calendar.current.isDate(memo.createdAt, inSameDayAs: d)
        }
    }
}

enum Route: Hashable {
    case review
    case trash
    case settings
}
