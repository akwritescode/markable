# Building and Installing Markable Locally

## Requirements

- macOS 13 (Ventura) or later
- Xcode (or at least the Command Line Tools with a Swift 5.9+ toolchain)

Check your toolchain:

```sh
swift --version
```

## Build

From the repo root:

```sh
./build-app.sh
```

This runs `swift build -c release`, assembles `dist/Markable.app` (binary, `Info.plist`, app icon, and the resource bundle with the bundled JS renderer), and ad-hoc signs it. No network access is needed at runtime — all rendering libraries ship inside the app.

To build just the binary without assembling the app bundle:

```sh
swift build -c release
```

## Install

1. Drag `dist/Markable.app` into `/Applications` (or run `cp -R dist/Markable.app /Applications/`).
2. Launch it once so macOS registers the app and its Markdown document types.

### Make it the default app for .md files

Right-click any `.md` file in Finder → **Get Info** → **Open with:** Markable → **Change All…**

This applies to `.md`, `.markdown`, `.mdown`, and `.mkd` files.

## Using the app

Press **⌘/** in the app for the full keyboard shortcuts reference. Highlights:

| Shortcut | Action |
|----------|--------|
| ⌘N / ⌘O / ⇧⌘O | New file / Open / Open Folder |
| ⌘S / ⇧⌘S | Save / Save As |
| ⌘1 / ⌘2 / ⌘3 | Preview / Split / Edit mode |
| ⌘\ | Toggle sidebar |
| ⌥⌘↓ / ⌥⌘↑ | Next / previous file in the workspace |
| ⌘F, ⌘G, ⌘E | Find, find next, use selection for find |
| ⌘B ⌘I ⌘K ⇧⌘C… | Markdown formatting in Edit mode (Format menu) |
| ⌘= / ⌘- / ⌘0 | Zoom in / out / reset |
| ⌘P / ⇧⌘E | Print / Export as PDF |

In the sidebar, Markdown files are shown as clickable links; other file types are dimmed. Switching files with unsaved changes prompts to save or discard.

Open `SAMPLE.md` for a demo of syntax highlighting, Mermaid diagrams, footnotes, task lists, and tables.

## Rebuilding after code changes

```sh
./build-app.sh
```

If the app is running, quit it first (`⌘Q` or `pkill -x Markable`), then relaunch from `dist/`. If you installed to `/Applications`, copy the fresh build over the old one.

## Troubleshooting

- **App won't open after copying from another Mac** — see [DISTRIBUTION.md](DISTRIBUTION.md); the ad-hoc signature triggers Gatekeeper on machines other than the one that built it.
- **Blank preview** — the resource bundle is missing. Make sure `dist/Markable.app/Contents/Resources/Markable_Markable.bundle` exists; rebuild with `./build-app.sh` rather than copying the bare binary.
- **`.md` files don't show Markable in "Open with"** — launch the app once directly, then relaunch Finder (`killall Finder`) so LaunchServices re-scans document types.
