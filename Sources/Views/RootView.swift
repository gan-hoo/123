import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var filter: MemoFilter = .all
    @State private var path: [Route] = []
    @State private var showDrawer = false
    @AppStorage("didSeed") private var didSeed = false

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $path) {
                MemoListView(filter: $filter, onMenu: openDrawer)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .review: ReviewView()
                        case .trash: TrashView()
                        case .settings: SettingsView()
                        }
                    }
            }
            .zIndex(0)

            if showDrawer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closeDrawer)
                    .transition(.opacity)
                    .zIndex(1)

                SidebarView(
                    filter: filter,
                    onSelectFilter: { f in
                        filter = f
                        path = []
                        closeDrawer()
                    },
                    onRoute: { r in
                        closeDrawer()
                        path = [r]
                    }
                )
                .frame(width: 300)
                .frame(maxHeight: .infinity)
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .gesture(
                    DragGesture().onEnded { v in
                        if v.translation.width < -60 { closeDrawer() }
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
        .task {
            seedIfNeeded()
            purgeTrash()
        }
    }

    private func openDrawer() {
        withAnimation(.easeOut(duration: 0.25)) { showDrawer = true }
    }

    private func closeDrawer() {
        withAnimation(.easeOut(duration: 0.25)) { showDrawer = false }
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true
        // 开启 iCloud 同步时不写入示例笔记，避免多台设备重复
        guard !CloudSync.isActive else { return }
        let count = (try? context.fetchCount(FetchDescriptor<Memo>())) ?? 0
        guard count == 0 else { return }
        let now = Date()
        let samples = [
            "不要追求完美，先记下来。灵感转瞬即逝，记录本身就是思考。 #想法",
            "用标签整理笔记：\n- 一条笔记可以有多个标签\n- 支持多级标签，比如 #闪念/入门\n- 点击卡片里的标签可以快速筛选",
            "欢迎使用「闪念」👋\n\n这是一个卡片式的速记本，用来捕捉每一个闪现的想法。\n\n- 点击右下角的 ＋ 开始记录\n- 左上角菜单里有标签、热力图和每日回顾\n- 卡片右上角 ··· 可以置顶、编辑、分享和删除\n\n#闪念/入门",
        ]
        for (i, text) in samples.enumerated() {
            context.insert(Memo(content: text, createdAt: now.addingTimeInterval(Double(i - samples.count) * 60)))
        }
        try? context.save()
    }

    /// 清理回收站中超过 30 天的笔记
    private func purgeTrash() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let descriptor = FetchDescriptor<Memo>(predicate: #Predicate<Memo> { $0.trashedAt != nil })
        guard let trashed = try? context.fetch(descriptor) else { return }
        for memo in trashed {
            if let t = memo.trashedAt, t < cutoff {
                context.delete(memo)
            }
        }
        try? context.save()
    }
}
