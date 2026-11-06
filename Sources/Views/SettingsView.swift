import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.accent) private var accent
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil })
    private var memos: [Memo]

    @Query private var everyMemo: [Memo]
    @Query(sort: \Notebook.order) private var allNotebooks: [Notebook]

    @AppStorage(CloudSync.prefKey) private var iCloudSync = true
    @AppStorage(Theme.colorKey) private var colorRaw = ThemeColor.mint.rawValue
    @AppStorage(Theme.appearanceKey) private var appearanceRaw = Appearance.system.rawValue
    @ObservedObject private var sync = SyncMonitor.shared

    @State private var exportURL: URL?
    @State private var backupDoc: BackupDocument?
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var message: String?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            appearanceSection
            syncSection
            backupSection

            Section("数据") {
                LabeledContent("笔记数量", value: "\(memos.count)")
                LabeledContent("标签数量", value: "\(TagParser.allTags(from: memos).count)")
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("导出为 Markdown", systemImage: "doc.text")
                    }
                } else {
                    Label("正在准备导出…", systemImage: "hourglass")
                        .foregroundStyle(.secondary)
                }
            }

            Section("使用技巧") {
                tip("number", "输入 #标签 给笔记分类，用 / 创建多级标签")
                tip("hand.tap", "点击卡片中的标签可快速筛选")
                tip("sparkles", "每日回顾会随机推送旧笔记，帮你温故知新")
                tip("hand.point.up.left", "长按卡片可快速置顶、编辑、删除")
            }

            Section("关于") {
                NavigationLink {
                    ChangelogView()
                } label: {
                    LabeledContent("版本", value: version)
                }
                Text("Jin Notes：捕捉每一个闪现的念头。一个卡片式速记本。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .roundBackButton()
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: memos.count) {
            exportURL = Exporter.writeMarkdown(memos)
        }
        .alert("提示", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        Section("外观") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("主题色")
                    Spacer()
                    Text((ThemeColor(rawValue: colorRaw) ?? .mint).name)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 14) {
                    ForEach(ThemeColor.allCases) { theme in
                        Button {
                            Haptics.light()
                            withAnimation(.easeInOut(duration: 0.2)) { colorRaw = theme.rawValue }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 38, height: 38)
                                if colorRaw == theme.rawValue {
                                    Circle()
                                        .strokeBorder(theme.color, lineWidth: 2.5)
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.name)
                    }
                }
            }
            .padding(.vertical, 6)

            Picker("显示模式", selection: $appearanceRaw) {
                ForEach(Appearance.allCases) { a in
                    Text(a.name).tag(a.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - iCloud

    private var syncSection: some View {
        Section {
            Toggle(isOn: $iCloudSync) {
                Label("iCloud 同步", systemImage: "icloud")
            }
            HStack(spacing: 8) {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
                Text(status.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if CloudSync.isActive && sync.inProgress {
                    ProgressView()
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text(syncFooter)
        }
    }

    private struct SyncStatus {
        let icon: String
        let color: Color
        let text: String
    }

    private var status: SyncStatus {
        if iCloudSync != CloudSync.enabledAtLaunch {
            return SyncStatus(icon: "arrow.clockwise.circle", color: .orange, text: "重启 App 后生效")
        }
        if !iCloudSync {
            return SyncStatus(icon: "iphone", color: .secondary, text: "已关闭，数据仅保存在本机")
        }
        if !CloudSync.hasCloudKitEntitlement || !CloudSync.isActive {
            return SyncStatus(icon: "exclamationmark.icloud", color: .orange, text: "当前安装包不支持 iCloud 同步")
        }
        if !CloudSync.isSignedInToICloud {
            return SyncStatus(icon: "person.crop.circle.badge.exclamationmark", color: .orange, text: "未登录 iCloud，登录后会自动同步")
        }
        if sync.inProgress {
            return SyncStatus(icon: "arrow.triangle.2.circlepath.icloud", color: accent, text: "正在同步…")
        }
        if let err = sync.lastError {
            return SyncStatus(icon: "xmark.icloud", color: .red, text: "同步出错：\(err)")
        }
        if let d = sync.lastSync {
            return SyncStatus(icon: "checkmark.icloud", color: accent,
                              text: "已同步 · \(d.formatted(date: .omitted, time: .shortened))")
        }
        return SyncStatus(icon: "checkmark.icloud", color: accent, text: "已开启")
    }

    private var syncFooter: String {
        if CloudSync.isActive || iCloudSync == false {
            return "开启后，笔记和图片会通过你的 iCloud 私有数据库自动同步到登录同一 Apple ID 的所有设备。"
        }
        return "自动同步需要用付费 Apple 开发者账号签名（带 iCloud 权限）的安装包。免费侧载时，可以用下方「备份到 iCloud 云盘」手动同步。"
    }

    // MARK: - 备份

    private var backupSection: some View {
        Section {
            Button {
                do {
                    backupDoc = try Backup.makeDocument(everyMemo, notebooks: allNotebooks)
                    showExporter = true
                } catch {
                    message = "备份失败：\(error.localizedDescription)"
                }
            } label: {
                Label("备份到 iCloud 云盘 / 文件", systemImage: "externaldrive.badge.icloud")
            }
            .fileExporter(isPresented: $showExporter,
                          document: backupDoc,
                          contentType: .json,
                          defaultFilename: Backup.defaultFilename) { result in
                switch result {
                case .success:
                    message = "已备份 \(everyMemo.count) 条笔记"
                case .failure(let error):
                    message = "备份失败：\(error.localizedDescription)"
                }
            }

            Button {
                showImporter = true
            } label: {
                Label("从备份恢复", systemImage: "arrow.down.doc")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let n = try Backup.restore(from: url, into: context)
                        message = n > 0 ? "已导入 \(n) 条笔记" : "没有需要导入的新笔记"
                    } catch {
                        message = "恢复失败：\(error.localizedDescription)"
                    }
                case .failure(let error):
                    message = "恢复失败：\(error.localizedDescription)"
                }
            }
        } header: {
            Text("备份与恢复")
        } footer: {
            Text("备份文件包含全部笔记和图片。保存时选择「iCloud 云盘」，即可在其他设备上恢复；恢复时会自动跳过已有的笔记。")
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: icon).foregroundStyle(accent)
        }
    }
}
