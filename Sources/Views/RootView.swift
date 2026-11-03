import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var filter: MemoFilter = .all
    @State private var path: [Route] = []
    @State private var drawerOpen = false
    /// 手指拖动的水平位移
    @State private var dragX: CGFloat = 0
    @State private var isDragging = false
    @AppStorage("didSeed") private var didSeed = false

    private let drawerWidth: CGFloat = 300
    /// 从屏幕左侧多宽的区域内开始右滑可以打开侧边栏
    private let edgeWidth: CGFloat = 40

    /// 0 = 完全关闭，1 = 完全打开
    private var progress: CGFloat {
        let base: CGFloat = drawerOpen ? drawerWidth : 0
        return min(max((base + dragX) / drawerWidth, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack(path: $path) {
                MemoListView(filter: $filter, onMenu: { setDrawer(open: true) })
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .review: ReviewView()
                        case .trash: TrashView()
                        case .settings: SettingsView()
                        }
                    }
            }

            Color.black
                .opacity(0.35 * progress)
                .ignoresSafeArea()
                .allowsHitTesting(progress > 0.01)
                .onTapGesture { setDrawer(open: false) }

            SidebarView(
                filter: filter,
                onSelectFilter: { f in
                    filter = f
                    path = []
                    setDrawer(open: false)
                },
                onRoute: { r in
                    setDrawer(open: false)
                    path = [r]
                }
            )
            .frame(width: drawerWidth)
            .frame(maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .shadow(color: .black.opacity(0.15 * progress), radius: 12, x: 4)
            .offset(x: (progress - 1) * drawerWidth)
            .accessibilityHidden(progress == 0)
        }
        .background(
            DrawerPanGesture(
                isOpen: drawerOpen,
                canOpen: path.isEmpty,
                edgeWidth: edgeWidth,
                onChanged: { tx in
                    isDragging = true
                    dragX = drawerOpen ? min(0, tx) : max(0, tx)
                },
                onEnded: { tx, vx in
                    isDragging = false
                    let projected = tx + vx * 0.2
                    if drawerOpen {
                        setDrawer(open: !(tx < -drawerWidth * 0.3 || projected < -drawerWidth * 0.6))
                    } else {
                        setDrawer(open: tx > drawerWidth * 0.35 || projected > drawerWidth * 0.8)
                    }
                }
            )
        )
        .task {
            seedIfNeeded()
            purgeTrash()
        }
    }

    // MARK: - 侧边栏

    private func setDrawer(open: Bool) {
        if open && !drawerOpen { Haptics.light() }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            drawerOpen = open
            dragX = 0
        }
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
            "用标签整理笔记：\n- 一条笔记可以有多个标签\n- 支持多级标签，比如 #拾念/入门\n- 点击卡片里的标签可以快速筛选",
            "欢迎使用「拾念」👋\n\n这是一个卡片式的速记本，用来捕捉每一个闪现的想法。\n\n- 点击右下角的 ＋ 开始记录\n- 左上角菜单里有标签、热力图和每日回顾\n- 卡片右上角 ··· 可以置顶、编辑、分享和删除\n\n#拾念/入门",
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
