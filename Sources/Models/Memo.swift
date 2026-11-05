import Foundation
import SwiftData

@Model
final class Memo {
    /// 标题（可选）
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    /// 非空表示已移入回收站
    var trashedAt: Date? = nil

    @Relationship(deleteRule: .cascade, inverse: \MemoImage.memo)
    var images: [MemoImage]? = []

    /// 历史版本（每次编辑保存前的旧内容）
    @Relationship(deleteRule: .cascade, inverse: \MemoRevision.memo)
    var revisions: [MemoRevision]? = []

    init(content: String, createdAt: Date = Date()) {
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    /// 笔记中出现的标签（不含 #）
    var tags: [String] { TagParser.tags(in: content) }

    /// 历史版本，最新的在前
    var sortedRevisions: [MemoRevision] {
        (revisions ?? []).sorted { $0.savedAt > $1.savedAt }
    }

    var revisionCount: Int { revisions?.count ?? 0 }

    /// 把当前内容存为一个历史版本
    func snapshot(in context: ModelContext) {
        let rev = MemoRevision(content: content, savedAt: updatedAt, imageCount: images?.count ?? 0)
        rev.title = title
        context.insert(rev)
        rev.memo = self
        if revisions == nil { revisions = [] }
        revisions?.append(rev)
    }

    /// 去掉图片标记的纯文字
    var plainText: String { RichContent.plainText(content) }

    /// 标题 + 正文纯文字（用于搜索、复制、分享）
    var fullText: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? plainText : t + "\n" + plainText
    }

    /// 正文没有引用到的图片（旧版本笔记的图片），显示在末尾
    var unplacedImages: [MemoImage] {
        let keys = Set(RichContent.referencedKeys(content))
        return sortedImages.filter { $0.key.isEmpty || !keys.contains($0.key) }
    }

    func imageData(forKey key: String) -> Data? {
        images?.first(where: { $0.key == key })?.data
    }

    var sortedImages: [MemoImage] {
        (images ?? []).sorted { $0.order < $1.order }
    }

    /// 是否属于某个标签（含子标签）
    func has(tag: String) -> Bool {
        tags.contains { $0 == tag || $0.hasPrefix(tag + "/") }
    }
}

@Model
final class MemoRevision {
    var title: String = ""
    var content: String = ""
    /// 这个版本最后保存的时间
    var savedAt: Date = Date()
    var imageCount: Int = 0
    var memo: Memo?

    init(content: String, savedAt: Date, imageCount: Int = 0) {
        self.content = content
        self.savedAt = savedAt
        self.imageCount = imageCount
    }
}

@Model
final class MemoImage {
    @Attribute(.externalStorage) var data: Data = Data()
    var order: Int = 0
    /// 对应正文中的 [[img:key]] 标记；旧版本的图片为空字符串
    var key: String = ""
    var memo: Memo?

    init(data: Data, order: Int, key: String = "") {
        self.data = data
        self.order = order
        self.key = key
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
