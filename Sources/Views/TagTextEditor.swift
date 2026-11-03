import SwiftUI
import UIKit

/// 支持 #标签 实时高亮的文本编辑器（基于 UITextView）
struct TagTextEditor: UIViewRepresentable {
    @Binding var text: String
    /// 置为 true 时弹出键盘，随后自动复位
    @Binding var focusRequest: Bool
    var accent: Color

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
        tv.text = text
        context.coordinator.accent = UIColor(accent)
        context.coordinator.restyle(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self

        let newAccent = UIColor(accent)
        var needsStyle = false
        if coordinator.accent != newAccent {
            coordinator.accent = newAccent
            needsStyle = true
        }

        // 外部修改了文字（如工具栏插入 #、列表、标签联想），且不在拼音输入中
        if tv.text != text && tv.markedTextRange == nil {
            tv.text = text
            let end = (text as NSString).length
            tv.selectedRange = NSRange(location: end, length: 0)
            tv.scrollRangeToVisible(tv.selectedRange)
            needsStyle = true
        }

        if needsStyle {
            coordinator.restyle(tv)
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

        func restyle(_ tv: UITextView) {
            // 拼音等输入法组字过程中不能改动属性，否则会打断输入
            guard tv.markedTextRange == nil else { return }
            let storage = tv.textStorage
            let full = NSRange(location: 0, length: storage.length)
            let selected = tv.selectedRange

            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: full)
            for m in TagParser.regex.matches(in: storage.string, range: full) {
                storage.addAttributes([
                    .foregroundColor: accent,
                    .backgroundColor: accent.withAlphaComponent(0.14),
                ], range: m.range)
            }
            storage.endEditing()

            tv.selectedRange = selected
            // 新输入的文字默认使用普通样式，不沿用标签颜色
            tv.typingAttributes = baseAttributes
        }

        func textViewDidChange(_ tv: UITextView) {
            if parent.text != tv.text {
                parent.text = tv.text
            }
            restyle(tv)
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            if tv.markedTextRange == nil {
                tv.typingAttributes = baseAttributes
            }
        }
    }
}
