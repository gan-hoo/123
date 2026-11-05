import SwiftUI
import SwiftData
import PhotosUI

struct ComposerView: View {
    @Environment(\.accent) private var accent
    let memo: Memo?
    var presetTag: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil })
    private var allMemos: [Memo]

    @State private var text = ""
    @State private var images: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var focusRequest = false
    @State private var confirmDiscard = false
    @State private var showHistory = false
    @State private var confirmDelete = false
    /// 进入编辑器时的原始内容，用于判断是否有未保存的修改
    @State private var originalText = ""
    @State private var originalImages: [Data] = []

    private let maxImages = 9

    private var hasChanges: Bool {
        text != originalText || images != originalImages
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f.string(from: memo?.updatedAt ?? Date())
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }

    /// 光标默认在末尾：正在输入的 `#xxx`
    private var partialTag: String? {
        guard let hashIdx = text.lastIndex(of: "#") else { return nil }
        if hashIdx != text.startIndex {
            let prev = text[text.index(before: hashIdx)]
            if !prev.isWhitespace { return nil }
        }
        let after = text[text.index(after: hashIdx)...]
        if after.contains(where: { $0.isWhitespace }) { return nil }
        return String(after)
    }

    private var suggestions: [String] {
        guard let p = partialTag else { return [] }
        let all = TagParser.allTags(from: allMemos)
        let matched = all.filter { p.isEmpty || ($0.localizedCaseInsensitiveContains(p) && $0 != p) }
        return Array(matched.prefix(12))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Text(dateLine)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            editor

            if !images.isEmpty {
                imageStrip
            }

            let tags = suggestions
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Button("#" + tag) { apply(tag) }
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(accent.opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }

            toolbarRow
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear(perform: load)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { @MainActor in
                for item in items {
                    guard images.count < maxImages else { break }
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        images.append(ImageUtil.compress(data))
                    }
                }
                pickerItems = []
            }
        }
        .confirmationDialog("放弃这次修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) { dismiss() }
            Button("保存") { save() }
        }
        .confirmationDialog("删除这条笔记？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                memo?.trashedAt = Date()
                try? context.save()
                dismiss()
            }
        } message: {
            Text("笔记会移到回收站，30 天内可以恢复。")
        }
        .sheet(isPresented: $showHistory) {
            if let memo {
                ThemedRoot {
                    RevisionHistoryView(memo: memo)
                }
            }
        }
    }

    // MARK: - 顶栏（仿系统备忘录）

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                if hasChanges && canSave {
                    confirmDiscard = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 46, height: 46)
                    .background(roundBackground(Circle()))
            }
            .accessibilityIdentifier("composerBack")
            .accessibilityLabel("返回")

            Spacer()

            HStack(spacing: 0) {
                ShareLink(item: text) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 48, height: 46)
                }
                .disabled(text.isEmpty)

                Menu {
                    Button {
                        UIPasteboard.general.string = text
                        Haptics.light()
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                    if let memo, memo.revisionCount > 0 {
                        Button {
                            showHistory = true
                        } label: {
                            Label("历史版本（\(memo.revisionCount)）", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    if memo != nil {
                        Divider()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 48, height: 46)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("composerMore")
            }
            .font(.title3)
            .foregroundStyle(.primary)
            .padding(.horizontal, 4)
            .background(roundBackground(Capsule()))

            Button(action: save) {
                Image(systemName: "checkmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(canSave ? accent : Color.gray.opacity(0.35)))
                    .shadow(color: canSave ? accent.opacity(0.35) : .clear, radius: 6, y: 2)
            }
            .disabled(!canSave)
            .accessibilityIdentifier("sendMemo")
            .accessibilityLabel("完成")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// 白底 + 细边 + 柔和阴影的圆形/胶囊按钮背景
    private func roundBackground<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color(.systemBackground))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TagTextEditor(text: $text, focusRequest: $focusRequest, accent: accent)
            if text.isEmpty {
                Text("现在的想法是…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, TagTextEditor.insets.left)
                    .padding(.top, TagTextEditor.insets.top)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var imageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let ui = UIImage(data: data) {
                                Image(uiImage: ui).resizable().scaledToFill()
                            } else {
                                Color(.tertiarySystemFill)
                            }
                        }
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Button {
                            withAnimation { _ = images.remove(at: index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.6))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// 键盘上方的悬浮工具条
    private var toolbarRow: some View {
        HStack(spacing: 0) {
            Button { insertTag() } label: {
                Image(systemName: "number")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .accessibilityIdentifier("insertTag")
            PhotosPicker(selection: $pickerItems,
                         maxSelectionCount: max(1, maxImages - images.count),
                         matching: .images) {
                Image(systemName: "photo")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .disabled(images.count >= maxImages)
            Button { insertList() } label: {
                Image(systemName: "list.bullet")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .accessibilityIdentifier("insertList")
            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .accessibilityLabel("收起键盘")
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .background(roundBackground(Capsule()))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let memo {
            text = memo.content
            images = memo.sortedImages.map(\.data)
        } else if let presetTag {
            text = "#\(presetTag) "
        }
        originalText = text
        originalImages = images
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusRequest = true
        }
    }

    private func insertTag() {
        if !text.isEmpty, let last = text.last, !last.isWhitespace {
            text += " "
        }
        text += "#"
    }

    private func insertList() {
        if !text.isEmpty && !text.hasSuffix("\n") {
            text += "\n"
        }
        text += "- "
    }

    private func apply(_ tag: String) {
        guard let p = partialTag else { return }
        text.removeLast(p.count)
        text += tag + " "
    }

    private func save() {
        guard canSave else { return }
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let target: Memo
        if let memo {
            target = memo
            let oldImages = memo.sortedImages.map(\.data)
            if memo.content != content || oldImages != images {
                memo.snapshot(in: context)
            }
            target.content = content
            target.updatedAt = Date()
            for old in target.images ?? [] {
                context.delete(old)
            }
            target.images = []
        } else {
            target = Memo(content: content)
            context.insert(target)
        }
        var newImages: [MemoImage] = []
        for (i, data) in images.enumerated() {
            let img = MemoImage(data: data, order: i)
            context.insert(img)
            newImages.append(img)
        }
        target.images = newImages
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
