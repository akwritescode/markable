# Markable

A native macOS app for viewing and editing Markdown files. SwiftUI document-based app; rendering in a WKWebView with GitHub-style typography and automatic dark mode.

Rendering stack (bundled locally, works offline):

- [markdown-it](https://github.com/markdown-it/markdown-it) — CommonMark + tables, strikethrough, autolinks, plus footnote and task-list plugins
- [highlight.js](https://highlightjs.org) — syntax highlighting in fenced code blocks (GitHub light/dark themes)
- [Mermaid](https://mermaid.js.org) — ` ```mermaid ` fences render as diagrams, theme-matched to system appearance

The preview page loads once per window; keystrokes re-render via a JS call, so scroll position is preserved and there's no flicker. See `SAMPLE.md` for a feature demo.

## Workspace

Sublime-style folder browsing: **File → Open Folder…** (⇧⌘O) shows the folder tree in a left sidebar. Markdown files appear as clickable links (accent color, pointing-hand cursor, underline on hover); other files are listed dimmed for context. Click a Markdown file to open it in the right pane. Opening a single file (⌘O or Finder double-click) opens its parent folder in the sidebar automatically. Folders can also be dropped on the Dock icon.

## Modes

- **Preview** (⌘1) — rendered, read-friendly view. Default on open. Links open in your browser; pinch to zoom.
- **Split** (⌘2) — editor and live preview side by side; preview keeps its scroll position while you type.
- **Edit** (⌘3) — plain-text editor with monospaced font, undo, and smart-quote substitution disabled (so Markdown syntax stays intact).

⌘S saves; unsaved changes are flagged in the status bar and window title, and switching files or quitting with unsaved edits prompts save/discard/cancel. Word/character count in the status bar.

## Themes & appearance

12 document themes via the paintpalette toolbar button or **View → Theme**: Default, GitHub, Serif, Sepia, Solarized Light/Dark, Dracula, Nord, Tokyo Night, One Dark, One Light, and Terminal. Default/GitHub/Serif follow the system light/dark appearance; the rest are fixed. Code highlighting and Mermaid diagrams re-theme to match. **View → Custom Stylesheet** applies your own CSS on top of any theme.

Zoom with ⌘= / ⌘- / ⌘0 (scales both preview and editor; current level shown in the status bar).

## Navigation & search

- **Find in document** (⌘F) — searches the preview in Preview/Split mode and the raw text in Edit mode; Enter/chevrons cycle matches with wrap-around, Esc closes.
- **Outline** — the list toolbar button shows the heading hierarchy; click to jump (smooth-scrolls the preview, or moves the cursor in Edit mode).

## Export & print

From the File menu: **Print…** (⌘P), **Export as PDF…** (⇧⌘E), **Export as HTML…** (self-contained, diagrams included), and **Export as Word…** (.docx via textutil; basic fidelity). Exports render offscreen with your current theme, so they work from any mode.

## Auto-refresh

The workspace folder is watched via FSEvents. If the open file changes on disk (a script regenerates it, a git checkout, another editor saves), the view reloads automatically when you have no unsaved edits; if you do have unsaved edits, a banner offers **Reload From Disk** or **Keep My Version** instead of clobbering your work. New and deleted files show up in the sidebar automatically without collapsing your expanded folders.

## Build

```sh
swift build -c release
./build-app.sh   # assembles dist/Markable.app
```

## Install

Drag `dist/Markable.app` into `/Applications`. To make it the default for `.md` files: right-click any `.md` file → Get Info → Open with: Markable → Change All.

Full local setup guide: [INSTALL.md](INSTALL.md) · Sharing the app with others: [DISTRIBUTION.md](DISTRIBUTION.md)
