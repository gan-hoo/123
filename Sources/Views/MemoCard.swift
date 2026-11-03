import SwiftUI
import SwiftData
import UIKit

struct MemoCard: View {
    @Environment(\.accent) private var accent
    let memo: Memo
    var alwaysExpanded = false
    var onEdit: () -> Void
    var onTagTap: (String) -> Void = { _ in }

    @State private var expanded = false
    @State private var preview: PreviewImage?

    private var isLong: Bool {
        memo.content.count > 280 || memo.content.split(separator: "\n", omittingEmptySubsequences: false).count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if !memo.content.isEmpty {
                Text(TagParser.attributed(memo.content, accent: accent))
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

                if isLong && !alwaysExpanded {
                    Button(expanded ? "收起" : "展开") {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(.footnote)
                }
            }

            let imgs = memo.sortedImages
            if !imgs.isEmpty {
                ImageGrid(images: imgs) { data in
                    preview = PreviewImage(data: data)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22)
        .contextMenu { menuItems }
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
        Button {
            UIPasteboard.general.string = memo.content
            Haptics.light()
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
        ShareLink(item: memo.content) {
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
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            .buttonStyle(GlassPressStyle())
            .padding()
        }
        .onTapGesture { dismiss() }
    }
}
