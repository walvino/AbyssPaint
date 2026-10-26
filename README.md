# AbyssPaint

A native macOS painting app built for graphics tablets (Wacom, Huion, XP-Pen)
with pressure-sensitive brushes, layers and PNG export.

- **Swift 5 + SwiftUI + AppKit + Core Graphics**
- Built with Swift Package Manager (no Xcode project to corrupt)
- Universal binary (Apple Silicon + Intel), macOS 14+
- Bundle identifier: `com.abysspaint.mac`

## Features

- Pressure-sensitive brush engine (stamps with spacing, hardness, flow)
- Eraser, soft airbrush, pencil, ink and marker presets
- Layers with visibility and opacity
- Undo / redo per stroke
- Zoom, pan, fit-to-window
- Export to PNG

## Build locally

```bash
swift build -c release
```

## Build the .app

```bash
swift build -c release
mkdir -p dist/AbyssPaint.app/Contents/MacOS
cp .build/release/AbyssPaint dist/AbyssPaint.app/Contents/MacOS/
cp Support/Info.plist dist/AbyssPaint.app/Contents/Info.plist
printf 'APPL????' > dist/AbyssPaint.app/Contents/PkgInfo
codesign --force --deep --sign - dist/AbyssPaint.app
```

## CI

`.github/workflows/build-macos.yml` builds a universal `.app` on GitHub Actions
and uploads `AbyssPaint-macOS.zip` as an artifact.

## Install (unsigned build)

1. Download `AbyssPaint-macOS.zip` from the latest Actions run.
2. Unzip it.
3. Right-click `AbyssPaint.app` → **Open** (first launch only).
   If macOS still refuses: `xattr -dr com.apple.quarantine /path/to/AbyssPaint.app`

## Tablet support

Tablet pressure arrives through `NSEvent` (`subtype == .tabletPoint`); the brush
engine maps it to size and opacity. No extra driver configuration is required
beyond the vendor's own macOS driver.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Export PNG | ⌘E |
| New canvas | ⌘N |
| Brush size | ⌘[ / ⌘] |
| Toggle eraser | ⇧⌘E |
| Pan | Space + drag, middle mouse, two-finger scroll |
| Zoom | ⌥ + scroll, pinch |
| Fit canvas | Double-click |
