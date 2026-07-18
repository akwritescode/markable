import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            WorkspaceModel.shared.openURL(url)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = WorkspaceModel.shared
        guard model.isDirty, let file = model.selectedFile else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = "“\(file.lastPathComponent)” has unsaved changes."
        alert.addButton(withTitle: "Save and Quit")
        alert.addButton(withTitle: "Discard and Quit")
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            model.save()
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}

@main
struct MarkableApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = WorkspaceModel.shared

    @AppStorage("theme") private var themeRaw = Theme.system.rawValue
    @AppStorage("previewZoom") private var zoom = 1.0
    @AppStorage("customCSSPath") private var customCSSPath = ""

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 640, minHeight: 400)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New File…") { model.newFile() }
                    .keyboardShortcut("n", modifiers: .command)
                Divider()
                Button("Open…") { model.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Open Folder…") { model.openFolderPanel() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Divider()
                // Disabled when no file is open, so ⌘W falls through to the
                // system Close (window) item.
                Button("Close File") { model.requestClose() }
                    .keyboardShortcut("w", modifiers: .command)
                    .disabled(model.selectedFile == nil)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { model.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(model.selectedFile == nil)
                Button("Save As…") { model.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(model.selectedFile == nil)
                Divider()
                Button("Reveal in Finder") { model.revealInFinder() }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                    .disabled(model.selectedFile == nil)
            }
            CommandGroup(replacing: .printItem) {
                Button("Print…") { Exporter.shared.printDocument() }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(model.selectedFile == nil)
                Divider()
                Button("Export as PDF…") { Exporter.shared.exportPDF() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(model.selectedFile == nil)
                Button("Export as HTML…") { Exporter.shared.exportHTML() }
                    .disabled(model.selectedFile == nil)
                Button("Export as Word…") { Exporter.shared.exportWord() }
                    .disabled(model.selectedFile == nil)
            }
            CommandGroup(after: .pasteboard) {
                Divider()
                Button("Find…") { FindState.shared.show() }
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(model.selectedFile == nil)
                Button("Find Next") { FindState.shared.findAgain(forward: true) }
                    .keyboardShortcut("g", modifiers: .command)
                    .disabled(model.selectedFile == nil)
                Button("Find Previous") { FindState.shared.findAgain(forward: false) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .disabled(model.selectedFile == nil)
                Button("Use Selection for Find") { FindState.shared.useSelectionForFind() }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(model.selectedFile == nil)
            }
            CommandMenu("Format") {
                Button("Bold") { EditorActions.toggleWrap("**") }
                    .keyboardShortcut("b", modifiers: .command)
                Button("Italic") { EditorActions.toggleWrap("*") }
                    .keyboardShortcut("i", modifiers: .command)
                Button("Inline Code") { EditorActions.toggleWrap("`") }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                Button("Strikethrough") { EditorActions.toggleWrap("~~") }
                    .keyboardShortcut("x", modifiers: [.command, .shift])
                Button("Insert Link") { EditorActions.insertLink() }
                    .keyboardShortcut("k", modifiers: .command)
                Divider()
                Menu("Heading") {
                    ForEach(1...6, id: \.self) { level in
                        Button("Heading \(level)") { EditorActions.setHeading(level) }
                            .keyboardShortcut(KeyEquivalent(Character("\(level)")), modifiers: [.command, .option])
                    }
                    Button("Remove Heading") { EditorActions.setHeading(0) }
                        .keyboardShortcut("0", modifiers: [.command, .option])
                }
                Divider()
                Button("Blockquote") { EditorActions.toggleBlockquote() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Bullet List") { EditorActions.toggleBulletList() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Task List") { EditorActions.toggleTaskList() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
            CommandMenu("Navigate") {
                Button("Next File") { model.selectAdjacentFile(offset: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                    .disabled(model.rootURL == nil)
                Button("Previous File") { model.selectAdjacentFile(offset: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                    .disabled(model.rootURL == nil)
                Divider()
                Button("Refresh Sidebar") { model.treeVersion += 1 }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.rootURL == nil)
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
                Button("Keyboard Shortcuts") { FindState.shared.showingShortcuts = true }
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
