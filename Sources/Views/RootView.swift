import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var filter: MemoFilter = .all
    @State private var path: [Route] = []
    @State private var drawerOpen = false
    /// 手指拖动的水平位移
    @State private var dragX: CGFloat = 0
    @State private var drawerWidth: CGFloat = 320
    @AppStorage("didSeed") private var didSeed = false

    /// 左侧边缘区域：在这里开始的右滑判定更宽松
    private let edgeWidth: CGFloat = 60

    /// 0 = 完全关闭，1 = 完全打开
    private var progress: CGFloat {
        let base: CGFloat = drawerOpen ? drawerWidth : 0
        return min(max((base + dragX) / drawerWidth, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            let shift = progress * drawerWidth
            ZStack(alignment: .leading) {
                // 侧边栏：和主页一起移动，从左侧露出（类似 Claude App）
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
                .offset(x: shift - drawerWidth)
                .accessibilityHidden(progress == 0)

                // 主页：整体跟随手指向右移动
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
                .overlay {
                    Color.black
                        .opacity(0.25 * progress)
                        .ignoresSafeArea()
                        .allowsHitTesting(progress > 0.01)
                        .onTapGesture { setDrawer(open: false) }
                        .accessibilityIdentifier("drawerScrim")
                }
                .clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous))
                .shadow(color: .black.opacity(0.18 * progress), radius: 16)
                .offset(x: shift)
            }
            .onAppear { drawerWidth = min(geo.size.width * 0.82, 340) }
            .onChange(of: geo.size.width) { _, w in drawerWidth = min(w * 0.82, 340) }
        }
        .background(AppBackground())
        .background(
            DrawerPanGesture(
                isOpen: drawerOpen,
                canOpen: path.isEmpty,
                edgeWidth: edgeWidth,
                onChanged: { tx in
                    dragX = drawerOpen ? min(0, tx) : max(0, tx)
                },
                onEnded: { tx, vx in
                    if drawerOpen {
                        // 拖过 25% 或快速左滑即收起；明显往右甩则保持打开
                        let shouldClose = vx < 200 && (tx < -drawerWidth * 0.25 || vx < -250)
                        setDrawer(open: !shouldClose)
                    } else {
                        // 拉出 25% 或轻快右滑即打开；明显往回拉则取消
                        let shouldOpen = vx > -200 && (tx > drawerWidth * 0.25 || vx > 250)
                        setDrawer(open: shouldOpen)
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
        guard !didSeed || CloudSync.isUITesting else { return }
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
