import SwiftUI
import SwiftData
import UIKit

struct MemoCard: View {
    @Environment(\.accent) private var accent
    let memo: Memo
    var alwaysExpanded = false
    var onEdit: () -> Void
    /// 点击卡片：以阅读模式打开
    var onOpen: (() -> Void)?
    var onTagTap: (String) -> Void = { _ in }

    @State private var expanded = false
    @State private var preview: PreviewImage?
    @State private var showHistory = false

    private var segments: [RichContent.Segment] { RichContent.segments(memo.content) }

    private var isLong: Bool {
        let plain = memo.plainText
        let imageCount = segments.filter { if case .image = $0 { return true } else { return false } }.count
        return plain.count > 280
            || plain.split(separator: "\n", omittingEmptySubsequences: false).count > 10
            || imageCount > 1
    }

    /// 折叠时只显示前面一部分（约 280 字，最多 1 张图）
    private var visibleSegments: [RichContent.Segment] {
        let all = segments
        guard isLong, !(alwaysExpanded || expanded) else { return all }
        var out: [RichContent.Segment] = []
        var chars = 0
        var imgs = 0
        for seg in all {
            switch seg {
            case .text(let t, _):
                out.append(seg)
                chars += t.count
            case .image:
                if imgs >= 1 { return out }
                out.append(seg)
                imgs += 1
            }
            if chars > 280 { break }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !memo.title.isEmpty {
                Text(memo.title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ForEach(visibleSegments) { seg in
                switch seg {
                case .text(let t, _):
                    Text(TagParser.attributed(t, accent: accent))
                        .font(.body)
                        .lineSpacing(4)
                        .lineLimit(alwaysExpanded || expanded ? nil : 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.openURL, OpenURLAction { url in
                            if let name = TagParser.tagName(from: url) {
                                onTagTap(name)
                                return .handled
                            }
                            return .systemAction
                        })
                case .image(let key, _):
                    if let data = memo.imageData(forKey: key), let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                            .onTapGesture { preview = PreviewImage(data: data) }
                            .accessibilityIdentifier("inlineImage")
                    }
                }
            }

            if isLong && !alwaysExpanded {
                Button(expanded ? "收起" : "展开") {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                }
                .font(.footnote)
            }

            // 旧版本笔记中未放进正文的图片
            let extra = memo.unplacedImages
            if !extra.isEmpty {
                ImageGrid(images: extra) { data in
                    preview = PreviewImage(data: data)
                }
            }
        }
        .padding(14)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?() }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu { menuItems }
        .sheet(isPresented: $showHistory) {
            ThemedRoot {
                RevisionHistoryView(memo: memo)
            }
        }
        .fullScreenCover(item: $preview) { item in
            ImagePreview(data: item.data)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(Fmt.full.string(from: memo.createdAt))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if memo.revisionCount > 0 {
                Text("已编辑")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if memo.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(accent)
            }
            Spacer()
            Menu {
                menuItems
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 22)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("memoMenu")
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button {
            withAnimation { memo.isPinned.toggle() }
        } label: {
            Label(memo.isPinned ? "取消置顶" : "置顶", systemImage: memo.isPinned ? "pin.slash" : "pin")
        }
        Button(action: onEdit) {
            Label("编辑", systemImage: "square.and.pencil")
        }
        if memo.revisionCount > 0 {
            Button {
                showHistory = true
            } label: {
                Label("历史版本（\(memo.revisionCount)）", systemImage: "clock.arrow.circlepath")
            }
        }
        Button {
            UIPasteboard.general.string = memo.fullText
            Haptics.light()
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
        ShareLink(item: memo.fullText) {
            Label("分享", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button(role: .destructive) {
            withAnimation { memo.trashedAt = Date() }
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
}

struct PreviewImage: Identifiable {
    let id = UUID()
    let data: Data
}

struct ImageGrid: View {
    let images: [MemoImage]
    var onTap: (Data) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(images) { img in
                Color(.tertiarySystemFill)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let ui = UIImage(data: img.data) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(img.data) }
            }
        }
    }
}

struct ImagePreview: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            .padding()
        }
        .onTapGesture { dismiss() }
    }
}
