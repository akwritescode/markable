# Distributing Markable

Three paths, depending on how polished you want the experience to be for recipients.

## 1. Quick and free — zip it and send

The app is only ad-hoc signed, so Gatekeeper on another Mac will refuse to open it normally ("Apple could not verify…"). Recipients get one scary dialog and have to bypass it once.

Package with `ditto` (preserves signatures and metadata — don't use Finder's compress or plain `zip -r`):

```sh
cd dist
ditto -c -k --keepParent Markable.app Markable.zip
```

Recipient steps:

1. Unzip and move `Markable.app` to `/Applications`.
2. Try to open it once (it will be blocked).
3. Go to **System Settings → Privacy & Security → "Open Anyway"**. On recent macOS the old right-click → Open trick no longer bypasses this.

Terminal alternative for the recipient:

```sh
xattr -dr com.apple.quarantine /Applications/Markable.app
```

Good for a few friends or coworkers who trust you; not for strangers.

## 2. The proper way — Developer ID + notarization

No warnings at all for recipients. Requires the [Apple Developer Program](https://developer.apple.com/programs/) ($99/year). Once enrolled:

```sh
# Sign with your Developer ID certificate instead of ad-hoc
codesign --force --deep --options runtime \
  -s "Developer ID Application: Your Name (TEAMID)" dist/Markable.app

# Submit to Apple's notary service, then staple the ticket
ditto -c -k --keepParent dist/Markable.app Markable.zip
xcrun notarytool submit Markable.zip --keychain-profile "notary" --wait
xcrun stapler staple dist/Markable.app
```

Then re-zip (or wrap in a DMG) and share. Recipients just double-click. This is the only sensible path for public distribution (website, GitHub releases to a broad audience).

One-time setup for `--keychain-profile "notary"`:

```sh
xcrun notarytool store-credentials "notary" \
  --apple-id you@example.com --team-id TEAMID \
  --password <app-specific-password>
```

## 3. Share the source

Push the repo to GitHub. Anyone with Xcode installed clones it and runs `./build-app.sh`; a self-built app has no Gatekeeper issue at all. The repo is already structured for this (`.gitignore` excludes `dist/` and build artifacts). See [INSTALL.md](INSTALL.md).

## Intel Macs: build a universal binary first

The default build is Apple Silicon only — it won't launch on an Intel Mac. Build universal before packaging:

```sh
swift build -c release --arch arm64 --arch x86_64
```

Note: the universal binary lands in `.build/apple/Products/Release/` instead of `.build/release/`, so adjust the copy path in `build-app.sh` (both the executable and `Markable_Markable.bundle`).
