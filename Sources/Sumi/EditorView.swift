import SwiftUI
import AppKit

/// Texto que se mantiene centrado en una columna, como en modo lectura.
final class CenteredTextView: NSTextView {
    var columnWidth: CGFloat = 680

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let side = max(40, (newSize.width - columnWidth) / 2)
        if textContainerInset.width != side {
            textContainerInset = NSSize(width: side, height: 56)
        }
    }
}

/// Editor del texto en Markdown, con los signos en gris suave.
struct EditorView: NSViewRepresentable {
    @Binding var text: String
    let palette: Palette
    let mono: Bool
    let outline: [OutlineItem]
    var jump: JumpRequest? = nil

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = CenteredTextView(frame: .zero)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.string = text

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.restyle()

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let previous = coordinator.parent
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        if textView.string != text {
            textView.string = text
            coordinator.highlight()
        }
        if previous.palette != palette || previous.mono != mono {
            coordinator.restyle()
        }
        if let jump, jump.id != coordinator.lastJump {
            coordinator.lastJump = jump.id
            coordinator.go(to: jump.index)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: CenteredTextView?
        var lastJump: UUID?

        init(parent: EditorView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            highlight()
        }

        var baseFont: NSFont {
            parent.mono
                ? NSFont.monospacedSystemFont(ofSize: 14.5, weight: .regular)
                : NSFont.systemFont(ofSize: 15.5)
        }

        var paragraph: NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineHeightMultiple = 1.35
            return style
        }

        func restyle() {
            guard let textView else { return }
            let p = parent.palette
            textView.insertionPointColor = p.ns(p.accent)
            textView.selectedTextAttributes = [.backgroundColor: p.ns(p.sel)]
            textView.typingAttributes = [.font: baseFont, .foregroundColor: p.ns(p.text), .paragraphStyle: paragraph]
            highlight()
        }

        func go(to index: Int) {
            guard let textView, let item = parent.outline.first(where: { $0.id == index }) else { return }
            let string = textView.string as NSString
            var location = 0
            var line = 1
            while line < item.line && location < string.length {
                location = NSMaxRange(string.lineRange(for: NSRange(location: location, length: 0)))
                line += 1
            }
            let lineRange = string.lineRange(for: NSRange(location: min(location, string.length), length: 0))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            textView.scrollRangeToVisible(lineRange)
            textView.showFindIndicator(for: lineRange)
            textView.window?.makeFirstResponder(textView)
        }

        // MARK: Colores del Markdown

        private static func regex(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        }

        private static let heading = regex(#"^(#{1,6}[ \t]+)(.*)$"#)
        private static let quote = regex(#"^(>[ \t]?)(.*)$"#)
        private static let list = regex(#"^[ \t]*(?:[-*+]|\d+[.)])[ \t]+(?:\[[ xX]\][ \t]+)?"#)
        private static let rule = regex(#"^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$"#)
        private static let bold = regex(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
        private static let inlineCode = regex(#"`[^`\n]+`"#)
        private static let link = regex(#"(!?\[)([^\]\n]*)(\]\([^)\n]*\))"#)
        private static let pipe = regex(#"\|"#)
        private static let fence = regex(#"^(```|~~~)[^\n]*\n[\s\S]*?^\1[ \t]*$"#)

        func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let p = parent.palette
            let text = p.ns(p.text), faint = p.ns(p.faint), muted = p.ns(p.muted), accent = p.ns(p.accent), code = p.ns(p.code)
            let font = baseFont
            let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            let string = storage.string
            let full = NSRange(location: 0, length: (string as NSString).length)

            storage.beginEditing()
            storage.setAttributes([.font: font, .foregroundColor: text, .paragraphStyle: paragraph], range: full)

            func each(_ re: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
                re.enumerateMatches(in: string, range: full) { match, _, _ in if let match { body(match) } }
            }

            each(Self.heading) { m in
                storage.addAttribute(.font, value: boldFont, range: m.range)
                storage.addAttribute(.foregroundColor, value: faint, range: m.range(at: 1))
            }
            each(Self.quote) { m in
                storage.addAttribute(.foregroundColor, value: muted, range: m.range(at: 2))
                storage.addAttribute(.foregroundColor, value: faint, range: m.range(at: 1))
            }
            each(Self.list) { m in storage.addAttribute(.foregroundColor, value: faint, range: m.range) }
            each(Self.rule) { m in storage.addAttribute(.foregroundColor, value: faint, range: m.range) }
            each(Self.pipe) { m in storage.addAttribute(.foregroundColor, value: faint, range: m.range) }
            each(Self.bold) { m in
                storage.addAttribute(.font, value: boldFont, range: m.range)
                let marker = m.range(at: 1).length
                storage.addAttribute(.foregroundColor, value: faint, range: NSRange(location: m.range.location, length: marker))
                storage.addAttribute(.foregroundColor, value: faint, range: NSRange(location: NSMaxRange(m.range) - marker, length: marker))
            }
            each(Self.link) { m in
                storage.addAttribute(.foregroundColor, value: faint, range: m.range(at: 1))
                storage.addAttribute(.foregroundColor, value: accent, range: m.range(at: 2))
                storage.addAttribute(.foregroundColor, value: faint, range: m.range(at: 3))
            }
            each(Self.inlineCode) { m in
                storage.addAttribute(.backgroundColor, value: code, range: m.range)
                storage.addAttribute(.foregroundColor, value: faint, range: NSRange(location: m.range.location, length: 1))
                storage.addAttribute(.foregroundColor, value: faint, range: NSRange(location: NSMaxRange(m.range) - 1, length: 1))
            }
            each(Self.fence) { m in
                storage.addAttributes([.font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                                       .foregroundColor: text, .backgroundColor: code], range: m.range)
            }
            storage.endEditing()
        }
    }
}
