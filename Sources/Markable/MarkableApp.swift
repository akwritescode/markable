import SwiftUI
import AppKit

/// Files handed to `AppDelegate.application(_:open:)` while every open window
/// already has a document loaded. Drained by the next new window's
/// `onAppear` (see ContentView), in the order they were queued.
enum PendingOpens {
    @MainActor static var queue: [URL] = []
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var current: AppDelegate?

    /// Set by whichever window's ContentView appears first; opens another
    /// window of the same kind. Used so Finder "Open With"/dock-drop opens a
    /// new window instead of silently replacing an existing one's contents.
    var openNewWindow: (() -> Void)?

    override init() {
        super.init()
        Self.current = self
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let idle = WorkspaceModel.all.first(where: { $0.selectedFile == nil && $0.rootURL == nil }) {
                idle.openURL(url)
            } else {
                PendingOpens.queue.append(url)
                openNewWindow?()
            }
        }
    }

    /// Opens a new window and, once it exists, attaches it to `source`'s tab
    /// group — `openWindow` alone just opens a plain separate window, it
    /// doesn't tab it to the current one. Window creation isn't synchronous,
    /// so we poll briefly for the window that wasn't there before.
    func openNewTab(from source: NSWindow?) {
        let before = Set(NSApp.windows.map(ObjectIdentifier.init))
        openNewWindow?()
        attachNewWindow(source: source, before: before, attemptsLeft: 40)
    }

    private func attachNewWindow(source: NSWindow?, before: Set<ObjectIdentifier>, attemptsLeft: Int) {
        guard attemptsLeft > 0 else { return }
        if let newWindow = NSApp.windows.first(where: { !before.contains(ObjectIdentifier($0)) }) {
            source?.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.attachNewWindow(source: source, before: before, attemptsLeft: attemptsLeft - 1)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for model in WorkspaceModel.all where model.isDirty {
            guard let file = model.selectedFile else { continue }
            let alert = NSAlert()
            alert.messageText = "“\(file.lastPathComponent)” has unsaved changes."
            alert.addButton(withTitle: "Save and Quit")
            alert.addButton(withTitle: "Discard and Quit")
            alert.addButton(withTitle: "Cancel")
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                model.save()
            case .alertSecondButtonReturn:
                break
            default:
                return .terminateCancel
            }
        }
        return .terminateNow
    }
}

private struct WorkspaceModelFocusedKey: FocusedValueKey {
    typealias Value = WorkspaceModel
}

private struct FindStateFocusedKey: FocusedValueKey {
    typealias Value = FindState
}

extension FocusedValues {
    var workspaceModel: WorkspaceModel? {
        get { self[WorkspaceModelFocusedKey.self] }
        set { self[WorkspaceModelFocusedKey.self] = newValue }
    }

    var findState: FindState? {
        get { self[FindStateFocusedKey.self] }
        set { self[FindStateFocusedKey.self] = newValue }
    }
}

@main
struct MarkableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// Whichever window is currently key/main; commands act on that window's
    /// document, not on some single app-wide document.
    @FocusedValue(\.workspaceModel) private var focusedModel
    @FocusedValue(\.findState) private var focusedFind

    @AppStorage("theme") private var themeRaw = Theme.system.rawValue
    @AppStorage("previewZoom") private var zoom = 1.0
    @AppStorage("customCSSPath") private var customCSSPath = ""

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 640, minHeight: 400)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File…") { focusedModel?.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("New Tab") { AppDelegate.current?.openNewTab(from: NSApp.keyWindow) }
                    .keyboardShortcut("t", modifiers: .command)
                Divider()
                Button("Open…") { focusedModel?.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder…") { focusedModel?.openFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                // Disabled when no file is open, so ⌘W falls through to the
                // system Close (window) item.
                Button("Close File") { focusedModel?.requestClose() }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { focusedModel?.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Save As…") { focusedModel?.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(focusedModel?.selectedFile == nil)
                Divider()
                Button("Reveal in Finder") { focusedModel?.revealInFinder() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(focusedModel?.selectedFile == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print…") { Exporter.shared.printDocument(for: focusedModel) }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
                Divider()
                Button("Export as PDF…") { Exporter.shared.exportPDF(for: focusedModel) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Export as HTML…") { Exporter.shared.exportHTML(for: focusedModel) }
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Export as Word…") { Exporter.shared.exportWord(for: focusedModel) }
                    .disabled(focusedModel?.selectedFile == nil)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { focusedFind?.show() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Find Next") { focusedFind?.findAgain(forward: true) }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Find Previous") { focusedFind?.findAgain(forward: false) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(focusedModel?.selectedFile == nil)
                Button("Use Selection for Find") { focusedFind?.useSelectionForFind() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(focusedModel?.selectedFile == nil)
            }
            CommandMenu("Format") {
                Button("Bold") { EditorActions.toggleWrap("**", in: focusedFind?.textView) }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { EditorActions.toggleWrap("*", in: focusedFind?.textView) }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Inline Code") { EditorActions.toggleWrap("`", in: focusedFind?.textView) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Strikethrough") { EditorActions.toggleWrap("~~", in: focusedFind?.textView) }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Insert Link") { EditorActions.insertLink(in: focusedFind?.textView) }
                    .keyboardShortcut("k", modifiers: .command)
                Divider()
                Menu("Heading") {
                    ForEach(1...6, id: \.self) { level in
                        Button("Heading \(level)") {
                            EditorActions.setHeading(level, in: focusedFind?.textView)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(level)")), modifiers: [.command, .option])
                    }
                    Button("Remove Heading") { EditorActions.setHeading(0, in: focusedFind?.textView) }
                        .keyboardShortcut("0", modifiers: [.command, .option])
                }
                Divider()
                Button("Blockquote") { EditorActions.toggleBlockquote(in: focusedFind?.textView) }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Bullet List") { EditorActions.toggleBulletList(in: focusedFind?.textView) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Task List") { EditorActions.toggleTaskList(in: focusedFind?.textView) }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                Button("Next File") { focusedModel?.selectAdjacentFile(offset: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(focusedModel?.rootURL == nil)
                Button("Previous File") { focusedModel?.selectAdjacentFile(offset: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(focusedModel?.rootURL == nil)
                Divider()
                Button("Refresh Sidebar") { focusedModel?.treeVersion += 1 }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(focusedModel?.rootURL == nil)
            }
            CommandGroup(after: .toolbar) {
                Menu("Theme") {
                    Picker("Theme", selection: $themeRaw) {
                        ForEach(Theme.allCases) { t in
                            Text(t.displayName).tag(t.rawValue)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Menu("Custom Stylesheet") {
                    Button("Choose CSS File…") { chooseCustomCSS() }
                    Button("Clear") { customCSSPath = "" }
                        .disabled(customCSSPath.isEmpty)
                }
                Divider()
                Button("Zoom In") { zoom = min(3.0, zoom + 0.1) }
                    .keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { zoom = max(0.5, zoom - 0.1) }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { zoom = 1.0 }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button("Toggle Sidebar") {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)
                Divider()
            }
            // Replace the default (nonfunctional) "Markable Help" item.
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") { focusedFind?.showingShortcuts = true }
                    .keyboardShortcut("/", modifiers: .command)
            }
        }
    }

    private func chooseCustomCSS() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.init(filenameExtension: "css") ?? .plainText]
        panel.message = "Choose a CSS file to apply to the preview"
        if panel.runModal() == .OK, let url = panel.url {
            customCSSPath = url.path
        }
    }
}
