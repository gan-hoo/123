import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BackupMemo: Codable {
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var trashedAt: Date?
    var images: [Data]
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

    static func makeDocument(_ memos: [Memo]) throws -> BackupDocument {
        let file = BackupFile(memos: memos.map {
            BackupMemo(content: $0.content,
                       createdAt: $0.createdAt,
                       updatedAt: $0.updatedAt,
                       isPinned: $0.isPinned,
                       trashedAt: $0.trashedAt,
                       images: $0.sortedImages.map(\.data),
                       revisions: $0.sortedRevisions.map { r in
                           BackupRevision(content: r.content, savedAt: r.savedAt, imageCount: r.imageCount)
                       })
        })
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

        let existing = try context.fetch(FetchDescriptor<Memo>())
        var keys = Set(existing.map { key($0.createdAt, $0.content) })

        var added = 0
        for item in file.memos {
            let k = key(item.createdAt, item.content)
            if keys.contains(k) { continue }
            keys.insert(k)

            let memo = Memo(content: item.content, createdAt: item.createdAt)
            memo.updatedAt = item.updatedAt
            memo.isPinned = item.isPinned
            memo.trashedAt = item.trashedAt
            context.insert(memo)
            var imgs: [MemoImage] = []
            for (i, d) in item.images.enumerated() {
                let img = MemoImage(data: d, order: i)
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
