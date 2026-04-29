import SwiftUI
import AppKit

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String
    var onCommandReturn: () -> Void
    var onCommandComma: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = MDTextView()
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = Self.baseFont
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.onCmdReturn = onCommandReturn
        textView.onCmdComma = onCommandComma

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.setText(text)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? MDTextView else { return }
        tv.onCmdReturn = onCommandReturn
        tv.onCmdComma = onCommandComma
        if tv.string != text {
            context.coordinator.setText(text)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    static let baseFont = NSFont.systemFont(ofSize: 15)

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownTextView
        weak var textView: MDTextView?
        private var isApplyingExternal = false

        init(_ parent: MarkdownTextView) { self.parent = parent }

        func setText(_ s: String) {
            guard let tv = textView else { return }
            isApplyingExternal = true
            tv.string = s
            applyHighlighting()
            isApplyingExternal = false
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView, !isApplyingExternal else { return }
            parent.text = tv.string
            applyHighlighting()
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                return handleNewline(textView)
            }
            return false
        }

        // MARK: - List continuation

        private func handleNewline(_ tv: NSTextView) -> Bool {
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            let lineRange = ns.lineRange(for: NSRange(location: sel.location, length: 0))
            let upToCaret = ns.substring(
                with: NSRange(location: lineRange.location,
                              length: sel.location - lineRange.location)
            )

            if let m = upToCaret.range(of: #"^([ \t]*)([-*])[ \t]+"#, options: .regularExpression) {
                let prefix = String(upToCaret[m])
                let after = upToCaret[m.upperBound...]
                if after.isEmpty {
                    return clearLineMarker(tv, lineStart: lineRange.location, length: upToCaret.count)
                }
                return insert(tv, range: sel, string: "\n" + prefix)
            }

            if let m = upToCaret.range(of: #"^([ \t]*)(\d+)\.[ \t]+"#, options: .regularExpression) {
                let prefix = String(upToCaret[m])
                let after = upToCaret[m.upperBound...]
                if after.isEmpty {
                    return clearLineMarker(tv, lineStart: lineRange.location, length: upToCaret.count)
                }
                let leading = prefix.prefix { $0 == " " || $0 == "\t" }
                if let numRange = prefix.range(of: #"\d+"#, options: .regularExpression),
                   let n = Int(prefix[numRange]) {
                    return insert(tv, range: sel, string: "\n\(leading)\(n + 1). ")
                }
            }

            return false
        }

        private func insert(_ tv: NSTextView, range: NSRange, string: String) -> Bool {
            if tv.shouldChangeText(in: range, replacementString: string) {
                tv.textStorage?.replaceCharacters(in: range, with: string)
                tv.didChangeText()
            }
            return true
        }

        private func clearLineMarker(_ tv: NSTextView, lineStart: Int, length: Int) -> Bool {
            let range = NSRange(location: lineStart, length: length)
            return insert(tv, range: range, string: "\n")
        }

        // MARK: - Syntax highlighting

        func applyHighlighting() {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let full = NSRange(location: 0, length: storage.length)
            let base = MarkdownTextView.baseFont

            storage.beginEditing()
            storage.setAttributes([
                .font: base,
                .foregroundColor: NSColor.labelColor
            ], range: full)

            let nsString = storage.string as NSString

            // Headers
            enumerate(#"(?m)^(#{1,6})[ \t]+.+$"#, in: nsString) { ranges in
                let level = ranges[1].length
                let size: CGFloat = max(15, 24 - CGFloat(level - 1) * 1.6)
                let font = NSFont.systemFont(ofSize: size, weight: .semibold)
                storage.addAttribute(.font, value: font, range: ranges[0])
                storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: ranges[1])
            }

            // Bold **text**
            enumerate(#"\*\*([^*\n]+)\*\*"#, in: nsString) { ranges in
                let bold = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
                storage.addAttribute(.font, value: bold, range: ranges[0])
                self.dim(storage, NSRange(location: ranges[0].location, length: 2))
                self.dim(storage, NSRange(location: NSMaxRange(ranges[0]) - 2, length: 2))
            }

            // Italic *text* (not part of bold)
            enumerate(#"(?<!\*)\*(?!\*)([^*\n]+?)\*(?!\*)"#, in: nsString) { ranges in
                let italic = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
                storage.addAttribute(.font, value: italic, range: ranges[0])
                self.dim(storage, NSRange(location: ranges[0].location, length: 1))
                self.dim(storage, NSRange(location: NSMaxRange(ranges[0]) - 1, length: 1))
            }

            // Inline code `code`
            enumerate(#"`([^`\n]+)`"#, in: nsString) { ranges in
                let mono = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
                storage.addAttribute(.font, value: mono, range: ranges[0])
                storage.addAttribute(.foregroundColor, value: NSColor.systemPink, range: ranges[1])
                self.dim(storage, NSRange(location: ranges[0].location, length: 1))
                self.dim(storage, NSRange(location: NSMaxRange(ranges[0]) - 1, length: 1))
            }

            // Bullet markers
            enumerate(#"(?m)^([ \t]*)([-*])[ \t]"#, in: nsString) { ranges in
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: ranges[2])
            }

            // Numbered list markers
            enumerate(#"(?m)^([ \t]*)(\d+\.)[ \t]"#, in: nsString) { ranges in
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: ranges[2])
            }

            storage.endEditing()
        }

        private func dim(_ storage: NSTextStorage, _ range: NSRange) {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
        }

        private func enumerate(_ pattern: String,
                               in string: NSString,
                               body: ([NSRange]) -> Void) {
            guard let re = try? NSRegularExpression(pattern: pattern) else { return }
            re.enumerateMatches(in: string as String,
                                range: NSRange(location: 0, length: string.length)) { match, _, _ in
                guard let m = match else { return }
                var ranges: [NSRange] = []
                for i in 0..<m.numberOfRanges { ranges.append(m.range(at: i)) }
                body(ranges)
            }
        }
    }
}

final class MDTextView: NSTextView {
    var onCmdReturn: (() -> Void)?
    var onCmdComma: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            // Return / numpad enter
            if event.keyCode == 36 || event.keyCode == 76 {
                onCmdReturn?()
                return
            }
            if event.charactersIgnoringModifiers == "," {
                onCmdComma?()
                return
            }
        }
        super.keyDown(with: event)
    }
}
