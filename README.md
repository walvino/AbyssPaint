# AbyssPaint

A native macOS painting app built for graphics tablets (Wacom, Huion, XP-Pen)
with pressure-sensitive brushes, layers and PNG export.

- **Swift 5 + SwiftUI + AppKit + Core Graphics**
- Built with Swift Package Manager (no Xcode project to corrupt)
- Universal binary (Apple Silicon + Intel), macOS 14+
- Bundle identifier: `com.abysspaint.mac`

## Features

- Procreate-style floating interface: top bar, brush studio, layers panel, colour panel and bottom dock
- Pressure-sensitive brush engine (stamps with spacing, hardness, flow, grain)
- Brush presets with generated stroke previews: round, soft airbrush, pencil, studio ink, marker, soft eraser
- Layers with visibility, opacity, 17 blend modes, duplicate, merge down, flip, reorder, import, clear
- Undo / redo for the full layer stack (24 steps)
- Zoom, pan, pinch, two-finger rotation plus canvas rotate controls
- Eyedropper tool (or ⌥-click), stabilisation, recent colour swatches
- Symmetry drawing guide (vertical, horizontal, quadrant) and colour palettes
- Save / open `.abysspaint` projects and export PNG
- Universal binary (Apple Silicon + Intel), macOS 14+
- Bundle identifier: `com.abysspaint.mac`

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

## Install (unsigned build)

Download the latest release: **https://github.com/walvino/AbyssPaint/releases/latest**

1. Download `AbyssPaint-macOS.zip` and unzip it.
2. Drag `AbyssPaint.app` into `/Applications`.
3. Right-click `AbyssPaint.app` → **Open** (first launch only).
   If macOS still refuses: `xattr -dr com.apple.quarantine /Applications/AbyssPaint.app`

The build is universal (Apple Silicon + Intel) and ad-hoc signed, not notarised.

## CI

`.github/workflows/build-macos.yml` builds the universal `.app` on GitHub Actions
and uploads `AbyssPaint-macOS.zip` as an artifact on every push to `main`.

## Tablet support

Tablet pressure arrives through `NSEvent` (`subtype == .tabletPoint`); the brush
engine maps it to size and opacity. No extra driver configuration is required
beyond the vendor's own macOS driver.

## Shortcuts

| Action | Shortcut |
| --- | --- |
| Undo / Redo | ⌘Z / ⇧⌘Z |
| Save / Save As | ⌘S / ⇧⌘S |
| Open project | ⌘O |
| Export PNG | ⌘E |
| New canvas | ⌘N |
| Brush size | ⌘[ / ⌘] |
| Toggle eraser | ⇧⌘E |
| Brush / eraser / eyedropper | B / E / I |
| Sample colour | ⌥ + click |
| Fit canvas | ⌘0 or double-click |
| Reset canvas rotation | ⌥⌘0 |
| Rotate canvas | ⌥⌘← / ⌥⌘→ |
| Pan | Space + drag, middle mouse, two-finger scroll |
| Zoom | ⌘ + scroll, pinch |
| Rotate | Two-finger rotate |
