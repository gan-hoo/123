import SwiftUI
import SwiftData

/// 笔记列表：某个笔记本或「所有笔记」，可再按标签 / 日期 / 置顶筛选
struct MemoListView: View {
    let scope: ListScope

    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(EditorPresenter.self) private var editor

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil },
           sort: \Memo.createdAt, order: .reverse)
    private var memos: [Memo]
    @Query(sort: \Notebook.order) private var notebooks: [Notebook]

    @State private var filter: MemoFilter
    @State private var search = ""
    @State private var editingNotebook: Notebook?
    @State private var confirmDelete = false

    init(scope: ListScope) {
        self.scope = scope
        _filter = State(initialValue: scope.filter)
    }

    private var notebook: Notebook? {
        guard let id = scope.notebookID else { return nil }
        return notebooks.first { $0.uid == id }
    }

    private var title: String {
        if filter != .all { return filter.title }
        return notebook?.name ?? "所有笔记"
    }

    private var filtered: [Memo] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return memos
            .filter { scope.notebookID == nil || $0.notebookID == scope.notebookID }
            .filter { filter.matches($0) }
            .filter { q.isEmpty || $0.fullText.localizedCaseInsensitiveContains(q) }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.createdAt > b.createdAt
            }
    }

    private var presetTag: String? {
        if case .tag(let t) = filter { return t }
        return nil
    }

    var body: some View {
        let items = filtered
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(items) { memo in
                        MemoCard(
                            memo: memo,
                            notebooks: notebooks,
                            onEdit: { editor.open(memo: memo) },
                            onOpen: { editor.open(memo: memo, editing: false) },
                            onTagTap: { tag in
                                search = ""
                                withAnimation { filter = .tag(tag) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .background(Color(.systemGroupedBackground))
            .overlay {
                if items.isEmpty {
                    if search.isEmpty {
                        emptyState
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }

            Button {
                Haptics.light()
                editor.open(memo: nil, presetTag: presetTag, notebookID: scope.notebookID)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(accent, in: Circle())
                    .shadow(color: accent.opacity(0.4), radius: 10, y: 4)
            }
            .accessibilityIdentifier("newMemo")
            .accessibilityLabel("新建笔记")
            .padding(.trailing, 22)
            .padding(.bottom, 28)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索笔记")
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(items.isEmpty ? "无笔记" : "\(items.count) 条笔记")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if filter != scope.filter {
                        Button {
                            withAnimation { filter = scope.filter }
                        } label: {
                            Label("清除筛选", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    if let notebook {
                        Button { editingNotebook = notebook } label: {
                            Label("编辑笔记本", systemImage: "pencil")
                        }
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("删除笔记本", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityIdentifier("listMore")
            }
        }
        .sheet(item: $editingNotebook) { nb in
            ThemedRoot { NotebookEditorView(notebook: nb, nextOrder: 0) }
        }
        .confirmationDialog("删除笔记本「\(notebook?.name ?? "")」？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let notebook {
                    NotebookEditorView.delete(notebook, in: context)
                    dismiss()
                }
            }
        } message: {
            Text("里面的笔记不会被删除，会回到「所有笔记」。")
        }
    }

    /// 空状态：笔记本图标 + 无笔记
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: notebook?.icon ?? "square.and.pencil")
                .font(.system(size: 64))
                .foregroundStyle(notebook?.color ?? accent)
                .padding(.bottom, 6)
            Text("无笔记")
                .font(.title3.weight(.bold))
            Text("若要添加笔记，请轻点加号按钮。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyNotes")
    }
}
