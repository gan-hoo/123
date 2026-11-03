import SwiftUI
import SwiftData

struct MemoListView: View {
    @Environment(\.accent) private var accent
    @Binding var filter: MemoFilter
    var onMenu: () -> Void

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil },
           sort: \Memo.createdAt, order: .reverse)
    private var memos: [Memo]

    @State private var search = ""
    @State private var showComposer = false
    @State private var editing: Memo?

    private var filtered: [Memo] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return memos
            .filter { filter.matches($0) }
            .filter { q.isEmpty || $0.content.localizedCaseInsensitiveContains(q) }
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
                    HStack {
                        Text("\(items.count) 条笔记")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 4)

                    ForEach(items) { memo in
                        MemoCard(
                            memo: memo,
                            onEdit: { editing = memo },
                            onTagTap: { tag in
                                search = ""
                                withAnimation { filter = .tag(tag) }
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .background(AppBackground())
            .overlay {
                if items.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("还没有笔记",
                                               systemImage: "square.and.pencil",
                                               description: Text("点击右下角 ＋ 记录第一个想法"))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                }
            }

            Button {
                Haptics.light()
                showComposer = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .glassCircle(tint: accent)
                    .shadow(color: accent.opacity(0.35), radius: 12, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("newMemo")
            .accessibilityLabel("新建笔记")
            .padding(.trailing, 22)
            .padding(.bottom, 28)
        }
        .navigationTitle(filter.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "搜索笔记")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityIdentifier("menuButton")
                .accessibilityLabel("菜单")
            }
            if filter != .all {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全部") {
                        withAnimation { filter = .all }
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            ThemedRoot {
                ComposerView(memo: nil, presetTag: presetTag)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $editing) { memo in
            ThemedRoot {
                ComposerView(memo: memo, presetTag: nil)
            }
            .presentationDetents([.large])
        }
    }
}
