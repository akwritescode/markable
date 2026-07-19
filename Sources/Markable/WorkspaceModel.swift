import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var markdown: UTType {
        UTType(importedAs: "net.daringfireball.markdown")
    }
}

@MainActor
final class WorkspaceModel: ObservableObject {
    /// One instance per open window, registered by ContentView so the app
    /// delegate can find an idle window to reuse (or prompt-on-quit across
    /// all of them) without a single app-wide shared instance.
    private static var registry: [ObjectIdentifier: WorkspaceModel] = [:]
    static var all: [WorkspaceModel] { Array(registry.values) }

    static func register(_ model: WorkspaceModel) {
        registry[ObjectIdentifier(model)] = model
    }

    static func unregister(_ model: WorkspaceModel) {
        registry[ObjectIdentifier(model)] = nil
    }

    nonisolated static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    @Published var rootURL: URL? {
        didSet { startWatching() }
    }
    @Published var selectedFile: URL?
    @Published var text: String = ""
    @Published var isDirty = false
    /// Set when the user clicks another file while the current one has unsaved
    /// changes; drives the save/discard/cancel dialog.
    @Published var pendingSelection: URL?
    /// Set when the user closes a file (⌘W) that has unsaved changes.
    @Published var pendingClose = false
    /// Bumped to force a sidebar re-scan of the folder tree.
    @Published var treeVersion = 0
    /// The open file changed on disk while it had unsaved local edits;
    /// drives the reload/keep banner.
    @Published var externalChangeAvailable = false

    private var watcher: FolderWatcher?

    nonisolated static func isMarkdown(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    // MARK: - Opening

    func openFolder(_ url: URL) {
        rootURL = url
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    /// Open a single file directly (Finder double-click, ⌘O): the sidebar
    /// shows its parent folder, Sublime-style.
    func openFile(_ url: URL) {
        rootURL = url.deletingLastPathComponent()
        open(url)
    }

    /// Sidebar click: guard against losing unsaved edits.
    func requestOpen(_ url: URL) {
        guard url != selectedFile else { return }
        if isDirty {
            pendingSelection = url
        } else {
            open(url)
        }
    }

    func open(_ url: URL) {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return }
        text = contents
        selectedFile = url
        isDirty = false
        externalChangeAvailable = false
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    func resolvePendingSelection(saveFirst: Bool) {
        guard let pending = pendingSelection else { return }
        pendingSelection = nil
        if saveFirst { save() } else { isDirty = false }
        open(pending)
    }

    // MARK: - Closing

    /// ⌘W: close the current file, prompting if it has unsaved changes.
    func requestClose() {
        guard selectedFile != nil else { return }
        if isDirty {
            pendingClose = true
        } else {
            closeFile()
        }
    }

    func resolvePendingClose(saveFirst: Bool) {
        pendingClose = false
        if saveFirst { save() }
        closeFile()
    }

    private func closeFile() {
        selectedFile = nil
        text = ""
        isDirty = false
        externalChangeAvailable = false
    }

    // MARK: - Saving

    func save() {
        guard let url = selectedFile else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDirty = false
            externalChangeAvailable = false
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - Navigation & file commands

    /// All markdown files under the root, in sidebar (tree) order.
    private func markdownFiles(under url: URL) -> [URL] {
        var result: [URL] = []
        for item in FileItem.children(of: url) {
            if item.isDirectory {
                result += markdownFiles(under: item.url)
            } else if item.isMarkdown {
                result.append(item.url)
            }
        }
        return result
    }

    func selectAdjacentFile(offset: Int) {
        guard let root = rootURL else { return }
        let files = markdownFiles(under: root)
        guard !files.isEmpty else { return }
        guard let current = selectedFile, let index = files.firstIndex(of: current) else {
            requestOpen(files[0])
            return
        }
        let next = files[(index + offset + files.count) % files.count]
        requestOpen(next)
    }

    func newFile() {
        let panel = NSSavePanel()
        panel.directoryURL = rootURL
        panel.nameFieldStringValue = "Untitled.md"
        panel.allowedContentTypes = [.markdown, .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.deletingPathExtension().lastPathComponent
        do {
            try "# \(name)\n\n".write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        treeVersion += 1
        if let root = rootURL, url.path.hasPrefix(root.path + "/") {
            open(url)
        } else {
            openFile(url)
        }
    }

    func saveAs() {
        guard selectedFile != nil else { return }
        let panel = NSSavePanel()
        panel.directoryURL = selectedFile?.deletingLastPathComponent()
        panel.nameFieldStringValue = selectedFile?.lastPathComponent ?? "Untitled.md"
        panel.allowedContentTypes = [.markdown, .plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
            return
        }
        isDirty = false
        if let root = rootURL, url.path.hasPrefix(root.path + "/") {
            selectedFile = url
            treeVersion += 1
        } else {
            openFile(url)
        }
    }

    func revealInFinder() {
        guard let url = selectedFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - File watching

    private func startWatching() {
        watcher = nil
        guard let root = rootURL else { return }
        watcher = FolderWatcher(url: root) { [weak self] _ in
            self?.handleFileSystemEvents()
        }
    }

    private func handleFileSystemEvents() {
        // Any change under the root: rescan the sidebar tree.
        treeVersion += 1

        // Re-read the open file and compare rather than matching event paths —
        // atomic saves (write-temp-then-rename) make path matching unreliable.
        guard let url = selectedFile,
              let disk = try? String(contentsOf: url, encoding: .utf8)
        else { return }

        if disk == text {
            externalChangeAvailable = false
        } else if isDirty {
            externalChangeAvailable = true
        } else {
            text = disk
        }
    }

    func reloadFromDisk() {
        guard let url = selectedFile,
              let disk = try? String(contentsOf: url, encoding: .utf8)
        else { return }
        text = disk
        isDirty = false
        externalChangeAvailable = false
    }

    // MARK: - Panels

    func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a Markdown file or a folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openURL(url)
    }

    func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to browse"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFolder(url)
    }

    func openURL(_ url: URL) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            openFolder(url)
        } else {
            openFile(url)
        }
    }
}
