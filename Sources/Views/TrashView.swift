import SwiftUI
import SwiftData

struct TrashView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Memo> { $0.trashedAt != nil },
           sort: \Memo.createdAt, order: .reverse)
    private var trashed: [Memo]

    @State private var confirmEmpty = false

    var body: some View {
        List {
            Section {
                ForEach(trashed) { memo in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Fmt.full.string(from: memo.createdAt))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(memo.content.isEmpty ? "[图片]" : memo.content)
                            .lineLimit(4)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            context.delete(memo)
                        } label: {
                            Label("彻底删除", systemImage: "trash")
                        }
                        Button {
                            withAnimation { memo.trashedAt = nil }
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
                        }
                        .tint(Theme.accent)
                    }
                    .contextMenu {
                        Button {
                            withAnimation { memo.trashedAt = nil }
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
                        }
                        Button(role: .destructive) {
                            context.delete(memo)
                        } label: {
                            Label("彻底删除", systemImage: "trash")
                        }
                    }
                }
            } footer: {
                if !trashed.isEmpty {
                    Text("左滑可恢复或彻底删除，回收站中的笔记会在 30 天后自动清除。")
                }
            }
        }
        .overlay {
            if trashed.isEmpty {
                ContentUnavailableView("回收站是空的", systemImage: "trash")
            }
        }
        .navigationTitle("回收站")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清空", role: .destructive) { confirmEmpty = true }
                    .disabled(trashed.isEmpty)
            }
        }
        .confirmationDialog("彻底删除回收站中的全部笔记？", isPresented: $confirmEmpty, titleVisibility: .visible) {
            Button("全部删除", role: .destructive) {
                for memo in trashed { context.delete(memo) }
                try? context.save()
            }
        }
    }
}
