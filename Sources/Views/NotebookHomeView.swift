import SwiftUI
import SwiftData

/// 首页：笔记本（大类）列表
struct NotebookHomeView: View {
    var onMenu: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accent) private var accent

    @Query(sort: \Notebook.order) private var notebooks: [Notebook]
    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil }) private var memos: [Memo]

    @State private var creating = false
    @State private var editing: Notebook?
    @State private var deleting: Notebook?

    private func count(_ nb: Notebook) -> Int {
        memos.filter { $0.notebookID == nb.uid }.count
    }

    var body: some View {
        List {
            Section {
                NavigationLink(value: Route.notes(ListScope(notebookID: nil))) {
                    NotebookRow(icon: "square.grid.3x3", color: .secondary,
                                name: "所有笔记", count: memos.count)
                }
                .accessibilityIdentifier("notebook-all")

                ForEach(notebooks) { nb in
                    NavigationLink(value: Route.notes(ListScope(notebookID: nb.uid))) {
                        NotebookRow(icon: nb.icon, color: nb.color, name: nb.name, count: count(nb))
                    }
                    .accessibilityIdentifier("notebook-\(nb.name)")
                    .contextMenu {
                        Button { editing = nb } label: { Label("编辑笔记本", systemImage: "pencil") }
                        Button(role: .destructive) { deleting = nb } label: { Label("删除笔记本", systemImage: "trash") }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleting = nb } label: { Label("删除", systemImage: "trash") }
                        Button { editing = nb } label: { Label("编辑", systemImage: "pencil") }
                            .tint(.gray)
                    }
                }
                .onMove(perform: move)
            } header: {
                HStack {
                    Text("笔记本")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Spacer()
                    Button {
                        creating = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .accessibilityIdentifier("addNotebook")
                    .accessibilityLabel("新建笔记本")
                }
                .padding(.bottom, 4)
            } footer: {
                if notebooks.isEmpty {
                    Text("点右上角 ＋ 新建笔记本，把笔记分门别类。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Jin Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityIdentifier("menuButton")
                .accessibilityLabel("菜单")
            }
        }
        .sheet(isPresented: $creating) {
            ThemedRoot { NotebookEditorView(notebook: nil, nextOrder: (notebooks.map(\.order).max() ?? 0) + 1) }
        }
        .sheet(item: $editing) { nb in
            ThemedRoot { NotebookEditorView(notebook: nb, nextOrder: 0) }
        }
        .confirmationDialog("删除笔记本「\(deleting?.name ?? "")」？",
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let nb = deleting { NotebookEditorView.delete(nb, in: context) }
                deleting = nil
            }
        } message: {
            Text("里面的笔记不会被删除，会回到「所有笔记」。")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var list = notebooks
        list.move(fromOffsets: source, toOffset: destination)
        for (i, nb) in list.enumerated() { nb.order = i }
        try? context.save()
    }
}

struct NotebookRow: View {
    let icon: String
    let color: Color
    let name: String
    let count: Int

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 34)
            Text(name)
                .font(.title3)
                .lineLimit(1)
            Spacer()
            Text("\(count)")
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// 新建 / 编辑笔记本
struct NotebookEditorView: View {
    let notebook: Notebook?
    var nextOrder: Int

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var icon = NotebookStyle.icons[0]
    @State private var colorName = NotebookColor.purple.rawValue
    @State private var loaded = false

    private var color: Color { (NotebookColor(rawValue: colorName) ?? .purple).color }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .font(.title)
                            .foregroundStyle(color)
                            .frame(width: 44, height: 44)
                        TextField("笔记本名称", text: $name)
                            .font(.title3)
                            .accessibilityIdentifier("notebookName")
                    }
                }
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                        ForEach(NotebookStyle.icons, id: \.self) { name in
                            Button { icon = name } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .foregroundStyle(icon == name ? color : .secondary)
                                    .frame(width: 46, height: 46)
                                    .background(icon == name ? color.opacity(0.15) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(NotebookColor.allCases) { c in
                            Button { colorName = c.rawValue } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if colorName == c.rawValue {
                                            Circle().strokeBorder(Color.primary.opacity(0.6), lineWidth: 2)
                                                .frame(width: 40, height: 40)
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle(notebook == nil ? "新建笔记本" : "编辑笔记本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveNotebook")
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let notebook {
                name = notebook.name
                icon = notebook.icon
                colorName = notebook.colorName
            }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if let notebook {
            notebook.name = n
            notebook.icon = icon
            notebook.colorName = colorName
        } else {
            context.insert(Notebook(name: n, icon: icon, colorName: colorName, order: nextOrder))
        }
        try? context.save()
        Haptics.success()
        dismiss()
    }

    /// 删除笔记本：笔记保留，回到「所有笔记」
    static func delete(_ nb: Notebook, in context: ModelContext) {
        let id = nb.uid
        if let memos = try? context.fetch(FetchDescriptor<Memo>()) {
            for m in memos where m.notebookID == id { m.notebookID = nil }
        }
        context.delete(nb)
        try? context.save()
    }
}
