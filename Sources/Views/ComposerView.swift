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

    private let maxImages = 9

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
        NavigationStack {
            VStack(spacing: 0) {
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
                                    .glassCapsule(tint: accent.opacity(0.25))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }

                toolbarRow
            }
            .navigationTitle(memo == nil ? "新建笔记" : "编辑笔记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
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

    private var toolbarRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Button { insertTag() } label: {
                    Image(systemName: "number")
                        .frame(width: 44, height: 44)
                        .glassCircle()
                }
                .accessibilityIdentifier("insertTag")
                PhotosPicker(selection: $pickerItems,
                             maxSelectionCount: max(1, maxImages - images.count),
                             matching: .images) {
                    Image(systemName: "photo")
                        .frame(width: 44, height: 44)
                        .glassCircle()
                }
                .disabled(images.count >= maxImages)
                Button { insertList() } label: {
                    Image(systemName: "list.bullet")
                        .frame(width: 44, height: 44)
                        .glassCircle()
                }
                .accessibilityIdentifier("insertList")
            }
            .glassGroup(spacing: 10)
            Spacer()
            Button(action: save) {
                Image(systemName: "paperplane.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSave ? Color.white : Color.secondary)
                    .frame(width: 64, height: 44)
                    .glassCapsule(tint: canSave ? accent : nil)
            }
            .disabled(!canSave)
            .accessibilityIdentifier("sendMemo")
            .accessibilityLabel("发送")
        }
        .buttonStyle(GlassPressStyle())
        .font(.title3)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
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
