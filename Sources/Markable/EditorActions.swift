import AppKit

/// Markdown formatting operations on the active editor text view.
/// No-ops when no editor is on screen (Preview mode).
@MainActor
enum EditorActions {
    private static var textView: NSTextView? { FindState.shared.textView }

    // MARK: - Inline wrapping (bold, italic, code, strikethrough)

    static func toggleWrap(_ marker: String) {
        guard let tv = textView else { return }
        let contents = tv.string as NSString
        let range = tv.selectedRange()
        let selected = contents.substring(with: range)
        let markerLength = (marker as NSString).length

        // Selection includes the markers: strip them.
        if selected.hasPrefix(marker), selected.hasSuffix(marker),
           (selected as NSString).length >= markerLength * 2 {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(tv, range: range, with: inner,
                    select: NSRange(location: range.location, length: (inner as NSString).length))
            return
        }

        // Markers directly surround the selection: strip them.
        if range.location >= markerLength,
           range.upperBound + markerLength <= contents.length {
            let before = NSRange(location: range.location - markerLength, length: markerLength)
            let after = NSRange(location: range.upperBound, length: markerLength)
            if contents.substring(with: before) == marker, contents.substring(with: after) == marker {
                let full = NSRange(location: before.location, length: markerLength * 2 + range.length)
                replace(tv, range: full, with: selected,
                        select: NSRange(location: before.location, length: range.length))
                return
            }
        }

        // Wrap; cursor/selection lands on the inner text.
        replace(tv, range: range, with: marker + selected + marker,
                select: NSRange(location: range.location + markerLength, length: range.length))
    }

    // MARK: - Links

    static func insertLink() {
        guard let tv = textView else { return }
        let contents = tv.string as NSString
        let range = tv.selectedRange()
        let selected = contents.substring(with: range)
        let label = selected.isEmpty ? "text" : selected
        let replacement = "[\(label)](url)"
        // Select the "url" placeholder so the user can type over it.
        let urlLocation = range.location + 1 + (label as NSString).length + 2
        replace(tv, range: range, with: replacement,
                select: NSRange(location: urlLocation, length: 3))
    }

    // MARK: - Line-level operations (headings, quotes, lists)

    /// level 0 removes the heading marker.
    static func setHeading(_ level: Int) {
        transformSelectedLines { line in
            guard !line.isEmpty else { return line }
            var stripped = line
            let hashes = line.prefix(while: { $0 == "#" })
            if hashes.count >= 1 && hashes.count <= 6 {
                stripped = String(line.dropFirst(hashes.count))
                if stripped.first == " " { stripped.removeFirst() }
            }
            return level == 0 ? stripped : String(repeating: "#", count: level) + " " + stripped
        }
    }

    static func toggleBlockquote() { toggleLinePrefix("> ") }
    static func toggleBulletList() { toggleLinePrefix("- ") }
    static func toggleTaskList() { toggleLinePrefix("- [ ] ") }

    private static func toggleLinePrefix(_ prefix: String) {
        transformSelectedLines(togglingAll: true, prefix: prefix)
    }

    // MARK: - Plumbing

    private static func transformSelectedLines(_ transform: (String) -> String) {
        guard let tv = textView else { return }
        let contents = tv.string as NSString
        let lineRange = contents.lineRange(for: tv.selectedRange())
        var block = contents.substring(with: lineRange)
        let hadTrailingNewline = block.hasSuffix("\n")
        if hadTrailingNewline { block.removeLast() }

        let newBlock = block
            .components(separatedBy: "\n")
            .map(transform)
            .joined(separator: "\n") + (hadTrailingNewline ? "\n" : "")

        replace(tv, range: lineRange, with: newBlock,
                select: NSRange(location: lineRange.location, length: (newBlock as NSString).length))
    }

    private static func transformSelectedLines(togglingAll: Bool, prefix: String) {
        guard let tv = textView else { return }
        let contents = tv.string as NSString
        let lineRange = contents.lineRange(for: tv.selectedRange())
        let block = contents.substring(with: lineRange)
        let nonEmpty = block.components(separatedBy: "\n").filter { !$0.isEmpty }
        let allPrefixed = !nonEmpty.isEmpty && nonEmpty.allSatisfy { $0.hasPrefix(prefix) }

        transformSelectedLines { line in
            guard !line.isEmpty else { return line }
            if allPrefixed {
                return String(line.dropFirst(prefix.count))
            }
            return line.hasPrefix(prefix) ? line : prefix + line
        }
    }

    private static func replace(_ tv: NSTextView, range: NSRange, with string: String, select: NSRange) {
        guard tv.shouldChangeText(in: range, replacementString: string) else { return }
        tv.textStorage?.replaceCharacters(in: range, with: string)
        tv.didChangeText()
        tv.setSelectedRange(select)
        tv.scrollRangeToVisible(select)
    }
}
