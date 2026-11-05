import SwiftUI
import SwiftData
import PhotosUI

struct ComposerView: View {
    @Environment(\.accent) private var accent
    let memo: Memo?
    var presetTag: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismissPresentation
    @Environment(EditorPresenter.self) private var presenter: EditorPresenter?

    private func dismiss() {
        if let presenter, presenter.isOpen {
            presenter.close()
        } else {
            dismissPresentation()
        }
    }

    /// 返回：有未保存的修改时先询问
    private func attemptBack() {
        if hasChanges && canSave {
            confirmDiscard = true
        } else {
            dismiss()
        }
    }

    @Query(filter: #Predicate<Memo> { $0.trashedAt == nil })
    private var allMemos: [Memo]

    @State private var text = ""
    /// 图片 key → 图片数据；正文中用 [[img:key]] 标记位置
    @State private var images: [String: Data] = [:]
    @State private var controller = EditorController()
    /// 编辑区顶部下拉的距离，下拉时才显示时间
    @State private var pullDistance: CGFloat = 0
    /// 下拉后固定显示时间，往上滑再隐藏
    @State private var showDate = false
    @State private var title = ""
    @State private var originalTitle = ""
    @State private var keyboardVisible = false
    @FocusState private var titleFocused: Bool

    // 撤销 / 重做
    @State private var undoStack: [String] = []
    @State private var redoStack: [String] = []
    @State private var lastEditTime = Date.distantPast
    @State private var applyingHistory = false
    @State private var historyReady = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var loaded = false
    @State private var focusRequest = false
    @State private var confirmDiscard = false
    @State private var showHistory = false
    @State private var confirmDelete = false
    /// 进入编辑器时的原始内容，用于判断是否有未保存的修改
    @State private var originalText = ""

    private let maxImages = 30

    private var imageCount: Int { RichContent.referencedKeys(text).count }

    private var hasChanges: Bool {
        text != originalText || title != originalTitle
    }

    private var dateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f.string(from: memo?.updatedAt ?? Date())
    }

    /// 标题 + 正文纯文字
    private var shareText: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = RichContent.plainText(text)
        return t.isEmpty ? body : t + "\n" + body
    }

    private var canSave: Bool {
        !RichContent.plainText(text).isEmpty || imageCount > 0
            || !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        withDialogs(withHandlers(content))
    }

    /// 页面主体
    private var content: some View {
        VStack(spacing: 0) {
            topBar
            if showDate {
                dateRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            titleField
            editorWithDate
            suggestionBar
            toolbarRow
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = false }
        }
    }

    /// 编辑区 + 下拉才显示的时间
    private var editorWithDate: some View {
        editor
            .overlay(alignment: .top) { pullHint }
    }

    /// 下拉过程中渐显的时间（松手后若已拉够距离，会固定显示在顶部）
    private var pullHint: some View {
        Text(dateLine)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .opacity(showDate ? 0 : Double(min(1, max(0, (pullDistance - 8) / 32))))
            .offset(y: min(pullDistance, 60) / 2 - 6)
            .allowsHitTesting(false)
    }

    /// 固定显示的时间
    private var dateRow: some View {
        Text(dateLine)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .accessibilityIdentifier("composerDate")
    }

    /// 标题输入框 + 分隔线
    private var titleField: some View {
        VStack(spacing: 0) {
            TextField("标题", text: $title)
                .font(.title3.weight(.semibold))
                .focused($titleFocused)
                .submitLabel(.next)
                .onSubmit { focusRequest = true }
                .padding(.horizontal, TagTextEditor.insets.left)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .accessibilityIdentifier("titleField")
            Divider()
                .padding(.horizontal, TagTextEditor.insets.left)
        }
    }

    /// 编辑区滚动：下拉超过一定距离固定显示时间，往上滑隐藏
    private func handlePull(_ pull: CGFloat) {
        pullDistance = max(0, pull)
        if pull > 45 && !showDate {
            withAnimation(.easeOut(duration: 0.2)) { showDate = true }
        } else if pull < -12 && showDate {
            withAnimation(.easeOut(duration: 0.2)) { showDate = false }
        }
    }

    /// 输入 # 时的标签联想
    @ViewBuilder
    private var suggestionBar: some View {
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
    }

    private func withHandlers<V: View>(_ view: V) -> some View {
        view
            .onAppear(perform: load)
            .onChange(of: text) { old, new in
                recordHistory(old: old, new: new)
                presenter?.dirty = hasChanges && canSave
            }
            .onChange(of: presenter?.backTrigger ?? 0) { _, _ in
                attemptBack()
            }
            .onChange(of: pickerItems) { _, items in
                loadPicked(items)
            }
    }

    private func withDialogs<V: View>(_ view: V) -> some View {
        view
            .confirmationDialog("放弃这次修改？", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("保存") { save() }
            }
            .confirmationDialog("删除这条笔记？", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive) { deleteMemo() }
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

    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task { @MainActor in
            for item in items {
                guard imageCount < maxImages else { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    insertImage(ImageUtil.compress(data))
                }
            }
            pickerItems = []
        }
    }

    private func deleteMemo() {
        memo?.trashedAt = Date()
        try? context.save()
        dismiss()
    }

    // MARK: - 顶栏（仿系统备忘录）

    private var topBar: some View {
        HStack(spacing: 10) {
            backButton
            Spacer()
            if !undoStack.isEmpty || !redoStack.isEmpty {
                undoRedoCapsule
                    .transition(.scale.combined(with: .opacity))
            }
            actionsCapsule
            doneButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var backButton: some View {
        Button(action: attemptBack) {
            Image(systemName: "chevron.left")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 46, height: 46)
                .background(roundBackground(Circle()))
        }
        .accessibilityIdentifier("composerBack")
        .accessibilityLabel("返回")
    }

    private var undoRedoCapsule: some View {
        HStack(spacing: 0) {
            Button(action: undo) {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 44, height: 46)
            }
            .disabled(undoStack.isEmpty)
            .accessibilityIdentifier("undoButton")
            .accessibilityLabel("撤销")

            Button(action: redo) {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 44, height: 46)
            }
            .disabled(redoStack.isEmpty)
            .accessibilityIdentifier("redoButton")
            .accessibilityLabel("重做")
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .padding(.horizontal, 4)
        .background(roundBackground(Capsule()))
    }

    private var actionsCapsule: some View {
        HStack(spacing: 0) {
            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 48, height: 46)
            }
            .disabled(text.isEmpty)

            Menu {
                moreMenuItems
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
    }

    @ViewBuilder
    private var moreMenuItems: some View {
        Button {
            UIPasteboard.general.string = shareText
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
    }

    private var doneButton: some View {
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

    /// 白底 + 细边 + 柔和阴影的圆形/胶囊按钮背景
    private func roundBackground<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color(.systemBackground))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TagTextEditor(text: $text, images: images, focusRequest: $focusRequest,
                          accent: accent, controller: controller,
                          onPull: { handlePull($0) })
            if text.isEmpty {
                Text("开始记录…")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, TagTextEditor.insets.left)
                    .padding(.top, TagTextEditor.insets.top)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxHeight: .infinity)
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
                         maxSelectionCount: max(1, min(9, maxImages - imageCount)),
                         matching: .images) {
                Image(systemName: "photo")
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .disabled(imageCount >= maxImages)
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
            if CloudSync.isUITesting {
                Button { insertSampleImage() } label: {
                    Image(systemName: "ladybug")
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .accessibilityIdentifier("debugInsertImage")
            }
        }
        .font(.title3)
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .background(roundBackground(Capsule()))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        // 键盘收起时，工具条再往下贴近底部
        .padding(.bottom, keyboardVisible ? 8 : -12)
    }

    // MARK: - Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let memo {
            var content = memo.content
            var dict: [String: Data] = [:]
            let placed = Set(RichContent.referencedKeys(content))
            for img in memo.sortedImages {
                // 旧版本的图片没有 key 或不在正文中：补上标记，放到末尾
                let key = (img.key.isEmpty || !placed.contains(img.key)) ? UUID().uuidString : img.key
                dict[key] = img.data
                if !placed.contains(key) {
                    content += (content.isEmpty ? "" : "\n") + RichContent.marker(key) + "\n"
                }
            }
            images = dict
            text = content
            title = memo.title
        } else if let presetTag {
            text = "#\(presetTag) "
        }
        originalText = text
        originalTitle = title
        // 载入完成后才开始记录撤销历史
        DispatchQueue.main.async { historyReady = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focusRequest = true
        }
    }

    // MARK: - 撤销 / 重做

    /// 连续输入（间隔不到 1 秒）合并为一步
    private func recordHistory(old: String, new: String) {
        guard historyReady, old != new else { return }
        if applyingHistory {
            applyingHistory = false
            return
        }
        let now = Date()
        if now.timeIntervalSince(lastEditTime) > 1.0 || undoStack.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                undoStack.append(old)
            }
            if undoStack.count > 200 { undoStack.removeFirst() }
        }
        lastEditTime = now
        if !redoStack.isEmpty { redoStack.removeAll() }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(text)
        applyingHistory = true
        lastEditTime = .distantPast
        text = previous
        Haptics.light()
    }

    private func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(text)
        applyingHistory = true
        lastEditTime = .distantPast
        text = next
        Haptics.light()
    }

    /// 在光标处插入图片
    private func insertImage(_ data: Data) {
        // 插入图片单独算一步
        lastEditTime = .distantPast
        let key = UUID().uuidString
        images[key] = data
        if !controller.insertImage(key: key, data: data) {
            // 编辑器还没准备好时，放到末尾
            if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
            text += RichContent.marker(key) + "\n"
        }
    }

    /// 生成一张测试用图片（仅 UI 自动化测试使用）
    private func insertSampleImage() {
        let size = CGSize(width: 600, height: 400)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 200, y: 120, width: 200, height: 160))
        }
        if let data = img.jpegData(compressionQuality: 0.8) {
            insertImage(data)
        }
    }

    private func insertTag() {
        lastEditTime = .distantPast
        if !text.isEmpty, let last = text.last, !last.isWhitespace {
            text += " "
        }
        text += "#"
    }

    private func insertList() {
        lastEditTime = .distantPast
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
        // 只保留正文中还在的图片（删掉的图片随之丢弃）
        let keys = RichContent.referencedKeys(content)
        let newData = keys.compactMap { images[$0] }
        let target: Memo
        if let memo {
            target = memo
            let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if memo.content != content || memo.title != newTitle || memo.sortedImages.map(\.data) != newData {
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
        for (i, key) in keys.enumerated() {
            guard let data = images[key] else { continue }
            let img = MemoImage(data: data, order: i, key: key)
            context.insert(img)
            newImages.append(img)
        }
        target.images = newImages
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        Haptics.success()
        dismiss()
    }
}
