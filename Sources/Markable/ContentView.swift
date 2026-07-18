import SwiftUI

enum ViewMode: String, CaseIterable, Identifiable {
    case preview = "Preview"
    case split = "Split"
    case edit = "Edit"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .preview: return "doc.richtext"
        case .split: return "rectangle.split.2x1"
        case .edit: return "pencil"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: WorkspaceModel
    @ObservedObject private var find = FindState.shared
    @State private var mode: ViewMode = .preview

    @AppStorage("theme") private var themeRaw = Theme.system.rawValue
    @AppStorage("previewZoom") private var zoom = 1.0
    @AppStorage("customCSSPath") private var customCSSPath = ""
    @State private var customCSSText = ""

    private var theme: Theme { Theme.current(from: themeRaw) }

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 240)
        } detail: {
            detail
        }
        .navigationTitle(title)
        .navigationSubtitle(model.isDirty ? "Edited" : "")
        .onAppear {
            find.targetsPreview = mode != .edit
            loadCustomCSS()
        }
        .onChange(of: mode) { newMode in
            find.targetsPreview = newMode != .edit
        }
        .onChange(of: customCSSPath) { _ in loadCustomCSS() }
        .sheet(isPresented: $find.showingShortcuts) {
            ShortcutsHelpView()
        }
        .alert("Unsaved Changes", isPresented: pendingAlertShown) {
            Button("Save") { model.resolvePendingSelection(saveFirst: true) }
            Button("Discard Changes", role: .destructive) {
                model.resolvePendingSelection(saveFirst: false)
            }
            Button("Cancel", role: .cancel) { model.pendingSelection = nil }
        } message: {
            Text("“\(model.selectedFile?.lastPathComponent ?? "")” has unsaved changes.")
        }
        .alert("Unsaved Changes", isPresented: $model.pendingClose) {
            Button("Save") { model.resolvePendingClose(saveFirst: true) }
            Button("Discard Changes", role: .destructive) {
                model.resolvePendingClose(saveFirst: false)
            }
            Button("Cancel", role: .cancel) { model.pendingClose = false }
        } message: {
            Text("Save changes to “\(model.selectedFile?.lastPathComponent ?? "")” before closing?")
        }
    }

    private func loadCustomCSS() {
        customCSSText = customCSSPath.isEmpty
            ? ""
            : ((try? String(contentsOfFile: customCSSPath, encoding: .utf8)) ?? "")
    }

    private var title: String {
        model.selectedFile?.lastPathComponent
            ?? model.rootURL?.lastPathComponent
            ?? "Markable"
    }

    private var pendingAlertShown: Binding<Bool> {
        Binding(
            get: { model.pendingSelection != nil },
            set: { if !$0 { model.pendingSelection = nil } }
        )
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { model.text },
            set: {
                guard $0 != model.text else { return }
                model.text = $0
                model.isDirty = true
            }
        )
    }

    @ViewBuilder
    private var detail: some View {
        if let file = model.selectedFile {
            editorArea(for: file)
                .background(shortcutButtons)
                .safeAreaInset(edge: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        if find.isVisible { findBar }
                        if model.externalChangeAvailable { externalChangeBanner }
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $mode) {
                            ForEach(ViewMode.allCases) { m in
                                Label(m.rawValue, systemImage: m.icon)
                                    .help("\(m.rawValue) mode")
                                    .tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    ToolbarItem {
                        outlineMenu
                    }
                    ToolbarItem {
                        themeMenu
                    }
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 40))
                    .foregroundStyle(.quaternary)
                Text("Select a Markdown file")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Open a folder with ⇧⌘O, then click a file in the sidebar.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func editorArea(for file: URL) -> some View {
        let directory = file.deletingLastPathComponent()
        switch mode {
        case .preview:
            MarkdownWebView(
                markdown: model.text, baseURL: directory, fileID: file,
                theme: theme, customCSS: customCSSText, zoom: zoom
            )
        case .edit:
            MarkdownEditor(text: textBinding, fileID: file, zoom: zoom)
        case .split:
            HSplitView {
                MarkdownEditor(text: textBinding, fileID: file, zoom: zoom)
                    .frame(minWidth: 240)
                MarkdownWebView(
                    markdown: model.text, baseURL: directory, fileID: file,
                    theme: theme, customCSS: customCSSText, zoom: zoom
                )
                .frame(minWidth: 240)
            }
        }
    }

    // MARK: - Outline

    private var outlineMenu: some View {
        Menu {
            let outline = parseOutline(model.text)
            if outline.isEmpty {
                Text("No headings")
            } else {
                ForEach(outline) { item in
                    Button {
                        jump(to: item)
                    } label: {
                        Text(String(repeating: "    ", count: item.level - 1) + item.title)
                    }
                }
            }
        } label: {
            Label("Outline", systemImage: "list.bullet.indent")
        }
        .help("Jump to heading")
    }

    private func jump(to item: OutlineItem) {
        if mode == .edit {
            if let textView = FindState.shared.textView {
                let range = NSRange(location: item.utf16Offset, length: 0)
                textView.setSelectedRange(range)
                textView.scrollRangeToVisible(range)
            }
        } else {
            FindState.shared.webView?.evaluateJavaScript("jumpToHeading(\(item.id))")
        }
    }

    // MARK: - Theme picker

    private var themeMenu: some View {
        Menu {
            Picker("Theme", selection: $themeRaw) {
                ForEach(Theme.allCases) { t in
                    Text(t.displayName).tag(t.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Label("Theme", systemImage: "paintpalette")
        }
        .help("Document theme")
    }

    // MARK: - Find bar

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            FindTextField()
            Button {
                find.findNext(forward: false)
            } label: {
                Image(systemName: "chevron.up")
            }
            Button {
                find.findNext(forward: true)
            } label: {
                Image(systemName: "chevron.down")
            }
            Spacer()
            Button("Done") { find.close() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Banners & status

    private var externalChangeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("This file changed on disk, and you have unsaved edits.")
                .font(.callout)
            Spacer()
            Button("Reload From Disk") { model.reloadFromDisk() }
            Button("Keep My Version") { model.externalChangeAvailable = false }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    // Hidden buttons so ⌘1/⌘2/⌘3 switch modes.
    private var shortcutButtons: some View {
        Group {
            Button("") { mode = .preview }.keyboardShortcut("1", modifiers: .command)
            Button("") { mode = .split }.keyboardShortcut("2", modifiers: .command)
            Button("") { mode = .edit }.keyboardShortcut("3", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(wordCountText)
            Divider().frame(height: 12)
            Text("\(model.text.count) characters")
            Divider().frame(height: 12)
            Text(readingTimeText)
            if zoom != 1.0 {
                Divider().frame(height: 12)
                Text("\(Int((zoom * 100).rounded()))%")
            }
            if model.isDirty {
                Divider().frame(height: 12)
                Text("Unsaved changes — ⌘S")
                    .foregroundStyle(.orange)
            }
            Spacer()
            Text("⌘1 Preview · ⌘2 Split · ⌘3 Edit")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var wordCount: Int {
        model.text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    private var wordCountText: String {
        "\(wordCount) word\(wordCount == 1 ? "" : "s")"
    }

    private var readingTimeText: String {
        let minutes = max(1, Int((Double(wordCount) / 200.0).rounded(.up)))
        return "~\(minutes) min read"
    }
}

/// Separate view so focus grabs reliably when the bar appears.
private struct FindTextField: View {
    @ObservedObject private var find = FindState.shared
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Find in document", text: $find.query)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 280)
            .focused($focused)
            .onSubmit { find.findNext(forward: true) }
            .onExitCommand { find.close() }
            .onAppear { focused = true }
    }
}
