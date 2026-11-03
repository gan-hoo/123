import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil })
    private var memos: [Memo]

    @State private var exportURL: URL?

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("数据") {
                LabeledContent("笔记数量", value: "\(memos.count)")
                LabeledContent("标签数量", value: "\(TagParser.allTags(from: memos).count)")
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("导出为 Markdown", systemImage: "square.and.arrow.up")
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
                LabeledContent("版本", value: version)
                Text("闪念：一个卡片式速记本，记录每一个闪现的想法。所有数据仅保存在本机。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: memos.count) {
            exportURL = Exporter.writeMarkdown(memos)
        }
    }

    private func tip(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
    }
}
