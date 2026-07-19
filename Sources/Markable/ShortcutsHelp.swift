import SwiftUI

struct ShortcutGroup: Identifiable {
    let id: String
    let items: [(String, String)]
    init(_ title: String, _ items: [(String, String)]) {
        self.id = title
        self.items = items
    }
}

let shortcutGroups: [ShortcutGroup] = [
    ShortcutGroup("Files", [
        ("New File", "⌘N"),
        ("New Tab", "⌘T"),
        ("Open File or Folder", "⌘O"),
        ("Open Folder", "⇧⌘O"),
        ("Save", "⌘S"),
        ("Save As…", "⇧⌘S"),
        ("Close File", "⌘W"),
        ("Reveal in Finder", "⌥⌘R"),
    ]),
    ShortcutGroup("View", [
        ("Preview Mode", "⌘1"),
        ("Split Mode", "⌘2"),
        ("Edit Mode", "⌘3"),
        ("Toggle Sidebar", "⌘\\"),
        ("Zoom In / Out / Reset", "⌘=  ⌘-  ⌘0"),
        ("Keyboard Shortcuts", "⌘/"),
    ]),
    ShortcutGroup("Navigate", [
        ("Next File", "⌥⌘↓"),
        ("Previous File", "⌥⌘↑"),
        ("Refresh Sidebar", "⌘R"),
    ]),
    ShortcutGroup("Find", [
        ("Find in Document", "⌘F"),
        ("Find Next / Previous", "⌘G  ⇧⌘G"),
        ("Use Selection for Find", "⌘E"),
        ("Close Find Bar", "esc"),
    ]),
    ShortcutGroup("Formatting (Edit mode)", [
        ("Bold", "⌘B"),
        ("Italic", "⌘I"),
        ("Inline Code", "⇧⌘C"),
        ("Strikethrough", "⇧⌘X"),
        ("Insert Link", "⌘K"),
        ("Heading 1–6", "⌥⌘1 … ⌥⌘6"),
        ("Remove Heading", "⌥⌘0"),
        ("Blockquote", "⇧⌘B"),
        ("Bullet List", "⇧⌘L"),
        ("Task List", "⇧⌘T"),
    ]),
    ShortcutGroup("Export", [
        ("Print", "⌘P"),
        ("Export as PDF", "⇧⌘E"),
    ]),
]

struct ShortcutsHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), alignment: .topLeading),
                              GridItem(.flexible(), alignment: .topLeading)],
                    alignment: .leading, spacing: 20
                ) {
                    ForEach(shortcutGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.id)
                                .font(.headline)
                                .padding(.bottom, 2)
                            ForEach(group.items, id: \.0) { name, keys in
                                HStack {
                                    Text(name)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 16)
                                    Text(keys)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
                .padding()
            }
        }
        .frame(width: 620, height: 480)
    }
}
