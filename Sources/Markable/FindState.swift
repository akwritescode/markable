import AppKit
import SwiftUI
import WebKit

/// Drives find-in-document for both render targets: WKWebView (preview/split)
/// and NSTextView (edit mode). Views register themselves on creation.
@MainActor
final class FindState: ObservableObject {
    @Published var isVisible = false
    @Published var query = ""
    @Published var showingShortcuts = false
    /// true when the preview should be searched (preview/split mode).
    var targetsPreview = true

    weak var webView: WKWebView?
    weak var textView: NSTextView?

    func show() {
        isVisible = true
    }

    func close() {
        isVisible = false
        query = ""
        webView?.evaluateJavaScript("window.getSelection().removeAllRanges()")
    }

    /// ⌘G/⇧⌘G: search with the current query, or open the bar if there is none.
    func findAgain(forward: Bool) {
        if query.isEmpty {
            show()
        } else {
            isVisible = true
            findNext(forward: forward)
        }
    }

    /// ⌘E: seed the query from the current selection (editor or preview).
    func useSelectionForFind() {
        if targetsPreview, let webView {
            webView.evaluateJavaScript("window.getSelection().toString()") { [weak self] value, _ in
                guard let selection = value as? String, !selection.isEmpty else { return }
                Task { @MainActor in self?.query = selection }
            }
        } else if let textView {
            let range = textView.selectedRange()
            if range.length > 0 {
                query = (textView.string as NSString).substring(with: range)
            }
        }
    }

    func findNext(forward: Bool) {
        guard !query.isEmpty else { return }
        if targetsPreview, let webView {
            let configuration = WKFindConfiguration()
            configuration.backwards = !forward
            configuration.wraps = true
            configuration.caseSensitive = false
            webView.find(query, configuration: configuration) { result in
                if !result.matchFound { NSSound.beep() }
            }
        } else if let textView {
            search(in: textView, forward: forward)
        }
    }

    private func search(in textView: NSTextView, forward: Bool) {
        let contents = textView.string as NSString
        guard contents.length > 0 else { return }

        var options: NSString.CompareOptions = [.caseInsensitive]
        if !forward { options.insert(.backwards) }

        let selection = textView.selectedRange()
        let searchRange: NSRange
        if forward {
            let start = min(selection.upperBound, contents.length)
            searchRange = NSRange(location: start, length: contents.length - start)
        } else {
            searchRange = NSRange(location: 0, length: selection.location)
        }

        var found = contents.range(of: query, options: options, range: searchRange)
        if found.location == NSNotFound {
            // Wrap around.
            found = contents.range(of: query, options: options)
        }
        guard found.location != NSNotFound else {
            NSSound.beep()
            return
        }
        textView.setSelectedRange(found)
        textView.scrollRangeToVisible(found)
        textView.showFindIndicator(for: found)
    }
}

// MARK: - Document outline

struct OutlineItem: Identifiable {
    let id: Int
    let level: Int
    let title: String
    /// UTF-16 offset of the heading line, for jumping in the editor.
    let utf16Offset: Int
}

func parseOutline(_ text: String) -> [OutlineItem] {
    var items: [OutlineItem] = []
    var offset = 0
    var inFence = false

    for line in text.components(separatedBy: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            inFence.toggle()
        } else if !inFence, line.hasPrefix("#") {
            let hashes = line.prefix(while: { $0 == "#" }).count
            let rest = line.dropFirst(hashes)
            if hashes <= 6, rest.first == " " || rest.first == "\t" {
                items.append(OutlineItem(
                    id: items.count,
                    level: hashes,
                    title: rest.trimmingCharacters(in: .whitespaces),
                    utf16Offset: offset
                ))
            }
        }
        offset += line.utf16.count + 1
    }
    return items
}
