import SwiftUI
import AppKit

struct FileItem: Identifiable, Equatable {
    let url: URL
    let isDirectory: Bool

    var id: URL { url }
    var name: String { url.lastPathComponent }
    var isMarkdown: Bool { !isDirectory && WorkspaceModel.isMarkdown(url) }

    static func children(of url: URL) -> [FileItem] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return contents
            .map { url in
                FileItem(
                    url: url,
                    isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                )
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
    }
}

struct SidebarView: View {
    @EnvironmentObject var model: WorkspaceModel

    var body: some View {
        if let root = model.rootURL {
            List {
                Section(root.lastPathComponent) {
                    ForEach(FileItem.children(of: root)) { item in
                        FileTreeRow(item: item)
                    }
                }
            }
            .listStyle(.sidebar)
            // Reset expansion state only when the root changes; treeVersion
            // bumps rescan rows in place without collapsing the tree.
            .id(root.path)
            .toolbar {
                ToolbarItem {
                    Button {
                        model.treeVersion += 1
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh file list")
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("No folder open")
                    .foregroundStyle(.secondary)
                Button("Open Folder…") { model.openFolderPanel() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct FileTreeRow: View {
    let item: FileItem
    @EnvironmentObject var model: WorkspaceModel
    @State private var isExpanded = false
    @State private var children: [FileItem]?
    @State private var isHovering = false

    var body: some View {
        if item.isDirectory {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children ?? []) { child in
                    FileTreeRow(item: child)
                }
            } label: {
                Label(item.name, systemImage: "folder")
                    .foregroundStyle(.primary)
            }
            .onChange(of: isExpanded) { expanded in
                if expanded && children == nil {
                    children = FileItem.children(of: item.url)
                }
            }
            .onChange(of: model.treeVersion) { _ in
                if children != nil {
                    children = FileItem.children(of: item.url)
                }
            }
        } else if item.isMarkdown {
            markdownRow
        } else {
            // Non-markdown files: visible but inert and dimmed.
            Label(item.name, systemImage: "doc")
                .foregroundStyle(.tertiary)
        }
    }

    private var isSelected: Bool { model.selectedFile == item.url }

    private var markdownRow: some View {
        Button {
            model.requestOpen(item.url)
        } label: {
            Label {
                Text(item.name)
                    .underline(isHovering && !isSelected)
            } icon: {
                Image(systemName: "doc.text")
            }
            .foregroundStyle(isSelected ? Color.primary : Color.accentColor)
            .fontWeight(isSelected ? .semibold : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.18))
                : nil
        )
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
