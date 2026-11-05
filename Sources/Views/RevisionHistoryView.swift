import SwiftUI
import SwiftData

/// 笔记的历史版本列表
struct RevisionHistoryView: View {
    let memo: Memo
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accent) private var accent

    /// 版本列表：当前版本在最前，之后是历史版本（新 → 旧）
    private var versions: [VersionItem] {
        var items = [VersionItem(id: "current", title: memo.title, content: memo.content, date: memo.updatedAt,
                                 imageCount: memo.images?.count ?? 0, revision: nil)]
        for rev in memo.sortedRevisions {
            items.append(VersionItem(id: "\(rev.persistentModelID.hashValue)-\(rev.savedAt.timeIntervalSince1970)",
                                     title: rev.title, content: rev.content, date: rev.savedAt,
                                     imageCount: rev.imageCount, revision: rev))
        }
        return items
    }

    var body: some View {
        let items = versions
        NavigationStack {
            List {
                Section {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            RevisionDetailView(
                                memo: memo,
                                item: item,
                                newer: index > 0 ? items[index - 1] : nil,
                                onRestored: { dismiss() }
                            )
                        } label: {
                            row(item, isCurrent: index == 0)
                        }
                    }
                } footer: {
                    Text("每次编辑保存时，旧内容会自动保存为一个历史版本。")
                }
            }
            .navigationTitle("历史版本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: VersionItem, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(Fmt.full.string(from: item.date))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if isCurrent {
                    Text("当前版本")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(accent, in: Capsule())
                }
                if item.imageCount > 0 {
                    Label("\(item.imageCount)", systemImage: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !item.title.isEmpty {
                Text(item.title).font(.subheadline.weight(.semibold))
            }
            Text(item.content.isEmpty ? "（空）" : RichContent.displayText(item.content))
                .font(.subheadline)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}

struct VersionItem: Identifiable {
    let id: String
    let title: String
    let content: String
    let date: Date
    let imageCount: Int
    let revision: MemoRevision?
}

/// 单个版本详情：全文 / 与下一版本的差异 / 恢复
struct RevisionDetailView: View {
    let memo: Memo
    let item: VersionItem
    /// 比这个版本更新的那个版本（用于对比改动）
    let newer: VersionItem?
    var onRestored: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accent) private var accent
    @State private var mode = 0
    @State private var confirmRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(Fmt.full.string(from: item.date))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)

                if newer != nil {
                    Picker("显示", selection: $mode) {
                        Text("改动").tag(0)
                        Text("全文").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                if let newer, mode == 0 {
                    Text("这个版本 → \(newer.revision == nil ? "当前版本" : Fmt.full.string(from: newer.date)) 的改动")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    DiffView(old: RichContent.displayText(item.content), new: RichContent.displayText(newer.content))
                } else {
                    Text(TagParser.attributed(RichContent.displayText(item.content), accent: accent))
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.revision == nil ? "当前版本" : "历史版本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if item.revision != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("恢复此版本") { confirmRestore = true }
                        .accessibilityIdentifier("restoreRevision")
                }
            }
        }
        .confirmationDialog("恢复到这个版本？", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("恢复") { restore() }
        } message: {
            Text("当前内容会先保存为一个历史版本，不会丢失。")
        }
    }

    private func restore() {
        guard item.content != memo.content || item.title != memo.title else { onRestored(); return }
        memo.snapshot(in: context)
        memo.title = item.title
        memo.content = item.content
        memo.updatedAt = Date()
        try? context.save()
        Haptics.success()
        onRestored()
    }
}

/// 按行对比两段文字：删除的行标红划线，新增的行标绿
struct DiffView: View {
    let old: String
    let new: String

    private enum Kind { case same, removed, added }

    private struct Line: Identifiable {
        let id: Int
        let text: String
        let kind: Kind
    }

    private var lines: [Line] {
        let a = old.components(separatedBy: "\n")
        let b = new.components(separatedBy: "\n")
        let diff = b.difference(from: a)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in diff {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        // 合并成一份：按顺序走两边
        var result: [Line] = []
        var i = 0, j = 0, n = 0
        while i < a.count || j < b.count {
            if i < a.count && removed.contains(i) {
                result.append(Line(id: n, text: a[i], kind: .removed)); i += 1
            } else if j < b.count && inserted.contains(j) {
                result.append(Line(id: n, text: b[j], kind: .added)); j += 1
            } else {
                if j < b.count { result.append(Line(id: n, text: b[j], kind: .same)) }
                i += 1; j += 1
            }
            n += 1
        }
        return result
    }

    var body: some View {
        let items = lines
        VStack(alignment: .leading, spacing: 2) {
            if old == new {
                Text("内容没有变化（可能只修改了图片）")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(symbol(line.kind))
                        .font(.system(.footnote, design: .monospaced).weight(.bold))
                        .foregroundStyle(color(line.kind))
                        .frame(width: 12)
                    Text(line.text.isEmpty ? " " : line.text)
                        .strikethrough(line.kind == .removed)
                        .foregroundStyle(line.kind == .same ? Color.primary : color(line.kind))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(line.kind == .same ? Color.clear : color(line.kind).opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .textSelection(.enabled)
    }

    private func symbol(_ k: Kind) -> String {
        switch k {
        case .same: return " "
        case .removed: return "−"
        case .added: return "+"
        }
    }

    private func color(_ k: Kind) -> Color {
        switch k {
        case .same: return .secondary
        case .removed: return .red
        case .added: return .green
        }
    }
}
