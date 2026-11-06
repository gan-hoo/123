import SwiftUI
import UIKit

/// 编辑器中的图片附件，记住对应的图片 key
final class ImageAttachment: NSTextAttachment {
    var key: String = ""
}

/// 让 SwiftUI 调用编辑器的方法（在光标处插入图片）
final class EditorController {
    fileprivate weak var coordinator: TagTextEditor.Coordinator?

    /// 在光标位置插入图片；成功返回 true
    @discardableResult
    func insertImage(key: String, data: Data) -> Bool {
        guard let coordinator else { return false }
        return coordinator.insertImage(key: key, data: data)
    }
}

/// 支持 #标签 实时高亮、图文混排的文本编辑器（基于 UITextView）
/// 文本绑定中，图片以 `[[img:KEY]]` 标记表示，在编辑器里显示为图片。
struct TagTextEditor: UIViewRepresentable {
    @Binding var text: String
    var images: [String: Data] = [:]
    /// 置为 true 时弹出键盘，随后自动复位
    @Binding var focusRequest: Bool
    var accent: Color
    var controller: EditorController?
    /// false 时为只读（阅读模式）
    var editable: Bool = true
    /// 顶部下拉距离（正数）/ 往上滑动距离（负数），用于显示 / 隐藏时间
    var onPull: ((Bool) -> Void)?

    static let insets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.textContainerInset = Self.insets
        tv.textContainer.lineFragmentPadding = 0
        tv.adjustsFontForContentSizeCategory = true
        tv.keyboardDismissMode = .interactive
        tv.alwaysBounceVertical = true
        tv.autocorrectionType = .default
        tv.isEditable = editable
        let c = context.coordinator
        c.textView = tv
        c.accent = UIColor(accent)
        controller?.coordinator = c
        c.load(text, into: tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let c = context.coordinator
        c.parent = self
        controller?.coordinator = c
        if tv.isEditable != editable {
            tv.isEditable = editable
        }

        var needsStyle = false
        let newAccent = UIColor(accent)
        if c.accent != newAccent {
            c.accent = newAccent
            needsStyle = true
        }

        // 外部修改了文字（工具栏插入 #、列表、标签联想），且不在拼音输入中
        if tv.markedTextRange == nil && c.lastSynced != text
            && Coordinator.serialize(tv.attributedText) != text {
            c.load(text, into: tv)
            let end = tv.textStorage.length
            tv.selectedRange = NSRange(location: end, length: 0)
            tv.scrollRangeToVisible(tv.selectedRange)
            needsStyle = false
        }

        if needsStyle {
            c.restyle(tv)
        }

        if focusRequest {
            DispatchQueue.main.async {
                if !tv.isFirstResponder { tv.becomeFirstResponder() }
                focusRequest = false
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TagTextEditor
        var accent: UIColor = .systemGreen
        weak var textView: UITextView?
        /// 时间是否已显示（只在越过阈值时通知 SwiftUI，避免滑动时每帧刷新导致卡顿）
        private var dateShown = false
        /// 最近一次同步给 SwiftUI 的文本，用来跳过不必要的整段比较
        var lastSynced: String?

        init(_ parent: TagTextEditor) {
            self.parent = parent
        }

        private var baseAttributes: [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 4
            return [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
                .paragraphStyle: style,
            ]
        }

        // MARK: 文本 <-> 图文

        /// 编辑器内容 → 带 [[img:KEY]] 标记的文本
        static func serialize(_ attr: NSAttributedString) -> String {
            var out = ""
            let ns = attr.string as NSString
            attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length)) { value, range, _ in
                if let a = value as? ImageAttachment {
                    for _ in 0..<range.length { out += RichContent.marker(a.key) }
                } else if value == nil {
                    out += ns.substring(with: range)
                }
            }
            return out
        }

        /// 带标记的文本 → 编辑器内容
        func load(_ text: String, into tv: UITextView) {
            let result = NSMutableAttributedString()
            let ns = text as NSString
            var last = 0
            for m in RichContent.regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if m.range.location > last {
                    result.append(NSAttributedString(
                        string: ns.substring(with: NSRange(location: last, length: m.range.location - last)),
                        attributes: baseAttributes))
                }
                let key = ns.substring(with: m.range(at: 1))
                if let data = parent.images[key], let att = makeAttachment(key: key, data: data, in: tv) {
                    result.append(NSAttributedString(attachment: att))
                }
                last = m.range.location + m.range.length
            }
            if last < ns.length {
                result.append(NSAttributedString(string: ns.substring(from: last), attributes: baseAttributes))
            }
            tv.attributedText = result
            lastSynced = text
            restyle(tv)
        }

        private func maxImageWidth(_ tv: UITextView) -> CGFloat {
            let w = tv.bounds.width > 0 ? tv.bounds.width : (tv.window?.bounds.width ?? 390)
            return max(80, w - TagTextEditor.insets.left - TagTextEditor.insets.right - 2)
        }

        private func makeAttachment(key: String, data: Data, in tv: UITextView) -> ImageAttachment? {
            guard let image = UIImage(data: data), image.size.width > 0 else { return nil }
            let maxW = maxImageWidth(tv)
            let ratio = image.size.height / image.size.width
            var w = maxW
            var h = w * ratio
            if h > 420 {
                h = 420
                w = h / ratio
            }
            let size = CGSize(width: floor(w), height: floor(h))
            let rounded = UIGraphicsImageRenderer(size: size).image { _ in
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10).addClip()
                image.draw(in: CGRect(origin: .zero, size: size))
            }
            let att = ImageAttachment()
            att.key = key
            att.image = rounded
            att.bounds = CGRect(origin: .zero, size: size)
            return att
        }

        // MARK: 样式

        func restyle(_ tv: UITextView) {
            // 拼音等输入法组字过程中不能改动属性，否则会打断输入
            guard tv.markedTextRange == nil else { return }
            let storage = tv.textStorage
            let full = NSRange(location: 0, length: storage.length)
            let selected = tv.selectedRange
            let base = baseAttributes

            storage.beginEditing()
            // 只重设文字部分，保留图片附件
            storage.enumerateAttribute(.attachment, in: full) { value, range, _ in
                if value == nil {
                    storage.setAttributes(base, range: range)
                } else {
                    storage.addAttribute(.paragraphStyle, value: base[.paragraphStyle] as Any, range: range)
                }
            }
            for m in TagParser.regex.matches(in: storage.string, range: full) {
                storage.addAttributes([
                    .foregroundColor: accent,
                    .backgroundColor: accent.withAlphaComponent(0.14),
                ], range: m.range)
            }
            storage.endEditing()

            tv.selectedRange = selected
            tv.typingAttributes = base
        }

        private func sync(_ tv: UITextView) {
            let s = Coordinator.serialize(tv.attributedText)
            lastSynced = s
            if parent.text != s {
                parent.text = s
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            sync(tv)
            restyle(tv)
        }

        /// 往上滑：隐藏时间
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard dateShown, scrollView.isDragging else { return }
            let pull = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if pull < -12 {
                dateShown = false
                parent.onPull?(false)
            }
        }

        /// 松手时判断：在顶部下拉超过一定距离则显示时间
        func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                       withVelocity velocity: CGPoint,
                                       targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let pull = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
            if pull > 45 && !dateShown {
                dateShown = true
                parent.onPull?(true)
            }
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            if tv.markedTextRange == nil {
                tv.typingAttributes = baseAttributes
            }
        }

        // MARK: 插入图片

        func insertImage(key: String, data: Data) -> Bool {
            guard let tv = textView, let att = makeAttachment(key: key, data: data, in: tv) else { return false }
            let storage = tv.textStorage
            var range = tv.selectedRange
            if range.location > storage.length { range = NSRange(location: storage.length, length: 0) }
            let ns = storage.string as NSString

            let piece = NSMutableAttributedString()
            // 图片独占一行
            if range.location > 0 && ns.character(at: range.location - 1) != 10 {
                piece.append(NSAttributedString(string: "\n", attributes: baseAttributes))
            }
            piece.append(NSAttributedString(attachment: att))
            piece.append(NSAttributedString(string: "\n", attributes: baseAttributes))

            storage.replaceCharacters(in: range, with: piece)
            tv.selectedRange = NSRange(location: range.location + piece.length, length: 0)
            sync(tv)
            restyle(tv)
            tv.scrollRangeToVisible(tv.selectedRange)
            return true
        }
    }
}
