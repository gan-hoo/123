import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupNotebook: Codable {
    var uid: UUID
    var name: String
    var icon: String
    var colorName: String
    var order: Int
}

struct BackupMemo: Codable {
    var notebookID: UUID?
    var title: String?
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var trashedAt: Date?
    var images: [Data]
    var imageKeys: [String]?
    var revisions: [BackupRevision]?
}

struct BackupRevision: Codable {
    var content: String
    var savedAt: Date
    var imageCount: Int
}

struct BackupFile: Codable {
    var app = "JinNotes"
    var version = 1
    var exportedAt = Date()
    var memos: [BackupMemo]
    var notebooks: [BackupNotebook]?
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum Backup {
    static var defaultFilename: String {
        "JinNotes-备份-\(Fmt.fileDate.string(from: Date()))"
    }

    static func makeDocument(_ memos: [Memo], notebooks: [Notebook] = []) throws -> BackupDocument {
        var file = BackupFile(memos: memos.map {
            BackupMemo(notebookID: $0.notebookID,
                       title: $0.title,
                       content: $0.content,
                       createdAt: $0.createdAt,
                       updatedAt: $0.updatedAt,
                       isPinned: $0.isPinned,
                       trashedAt: $0.trashedAt,
                       images: $0.sortedImages.map(\.data),
                       imageKeys: $0.sortedImages.map(\.key),
                       revisions: $0.sortedRevisions.map { r in
                           BackupRevision(content: r.content, savedAt: r.savedAt, imageCount: r.imageCount)
                       })
        })
        file.notebooks = notebooks.map {
            BackupNotebook(uid: $0.uid, name: $0.name, icon: $0.icon, colorName: $0.colorName, order: $0.order)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return BackupDocument(data: try encoder.encode(file))
    }

    private static func key(_ date: Date, _ content: String) -> String {
        "\(Int((date.timeIntervalSince1970 * 1000).rounded()))|\(content)"
    }

    /// 合并导入：已存在（创建时间 + 内容相同）的笔记会被跳过。返回新增条数。
    static func restore(from url: URL, into context: ModelContext) throws -> Int {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(BackupFile.self, from: data)

        // 先恢复笔记本（已存在的跳过）
        let existingBooks = Set(try context.fetch(FetchDescriptor<Notebook>()).map(\.uid))
        for b in file.notebooks ?? [] where !existingBooks.contains(b.uid) {
            let nb = Notebook(name: b.name, icon: b.icon, colorName: b.colorName, order: b.order)
            nb.uid = b.uid
            context.insert(nb)
        }

        let existing = try context.fetch(FetchDescriptor<Memo>())
        var keys = Set(existing.map { key($0.createdAt, $0.content) })

        var added = 0
        for item in file.memos {
            let k = key(item.createdAt, item.content)
            if keys.contains(k) { continue }
            keys.insert(k)

            let memo = Memo(content: item.content, createdAt: item.createdAt)
            memo.updatedAt = item.updatedAt
            memo.title = item.title ?? ""
            memo.notebookID = item.notebookID
            memo.isPinned = item.isPinned
            memo.trashedAt = item.trashedAt
            context.insert(memo)
            var imgs: [MemoImage] = []
            for (i, d) in item.images.enumerated() {
                let k = (item.imageKeys ?? []).indices.contains(i) ? item.imageKeys![i] : ""
                let img = MemoImage(data: d, order: i, key: k)
                context.insert(img)
                imgs.append(img)
            }
            memo.images = imgs
            var revs: [MemoRevision] = []
            for r in item.revisions ?? [] {
                let rev = MemoRevision(content: r.content, savedAt: r.savedAt, imageCount: r.imageCount)
                context.insert(rev)
                revs.append(rev)
            }
            memo.revisions = revs
            added += 1
        }
        try context.save()
        return added
    }
}
