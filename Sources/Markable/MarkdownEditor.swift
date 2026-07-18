import SwiftUI
import AppKit

/// Plain-text NSTextView wrapper. Smart quotes/dashes are disabled because
/// they corrupt Markdown syntax; TextEditor offers no way to turn them off.
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var fileID: URL?
    var zoom: Double = 1.0

    private var fontSize: CGFloat { 13.5 * zoom }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.autoresizingMask = [.width]
        textView.defaultParagraphStyle = {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            return style
        }()
        textView.typingAttributes = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .paragraphStyle: textView.defaultParagraphStyle!,
            .foregroundColor: NSColor.textColor,
        ]
        textView.string = text

        FindState.shared.textView = textView
        scrollView.hasVerticalScroller = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        FindState.shared.textView = textView
        if textView.font?.pointSize != fontSize {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            textView.font = font
            textView.typingAttributes[.font] = font
        }
        if context.coordinator.fileID != fileID {
            // Switched to a different file: replace content wholesale and drop
            // the undo stack so undo can't leak the previous file's text.
            context.coordinator.fileID = fileID
            textView.string = text
            textView.undoManager?.removeAllActions()
            textView.scroll(.zero)
        } else if textView.string != text {
            let selection = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selection.filter {
                $0.rangeValue.upperBound <= (text as NSString).length
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(text: $text)
        coordinator.fileID = fileID
        return coordinator
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var fileID: URL?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.string
        }
    }
}
