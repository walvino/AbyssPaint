# AbyssPaint

A professional painting application for macOS, built with Swift, SwiftUI, Metal, and Core Data.

## Features

- **Metal-based rendering engine** with tile-based compositing for 8K+ canvases
- **Pressure-sensitive brush engine** with 100+ parameters per brush
- **Wacom/Huion/XP-Pen tablet support** via IOKit HID
- **25 blend modes** with full layer stack (masks, clipping, groups)
- **PSD import/export** with layer style preservation
- **ColorSync-integrated color management** (sRGB, P3, CMYK)
- **Animation Assist** with onion skinning and timeline
- **Crash-safe autosave** with stroke-level recovery

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Apple Silicon (M1/M2/M3) or Intel Mac with Metal support
- Graphics tablet (Wacom, Huion, XP-Pen, or compatible)

## Building

1. Open `AbyssPaint.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run (⌘R)

## Project Structure

```
AbyssPaint/
├── AbyssPaint.xcodeproj/       # Xcode project
├── AbyssPaint/                 # Main app target
│   ├── Models/                 # Core Data models & Swift types
│   │   ├── Models.swift        # NSManagedObject subclasses
│   │   └── Stroke.swift        # Stroke, brush params, GPU structs
│   ├── Views/                  # SwiftUI views
│   │   ├── ContentView.swift   # Main window layout
│   │   ├── CanvasView.swift    # MTKView wrapper
│   │   ├── LayerPanel.swift    # Layer list & controls
│   │   ├── BrushLibraryPanel.swift
│   │   ├── ColorPickerPanel.swift
│   │   ├── ReferenceWindow.swift
│   │   ├── AnimationTimeline.swift
│   │   ├── NewCanvasSheet.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/             # (Future: MVVM separation)
│   ├── RenderEngine/           # Metal rendering
│   │   └── RenderEngine.swift  # Tile-based compositor
│   ├── BrushEngine/            # Brush stroke generation
│   │   └── BrushEngine.swift   # CPU/GPU stamp generation
│   ├── CanvasEngine/           # High-level canvas logic
│   │   └── CanvasEngine.swift  # Drawing, layers, tools
│   ├── TabletInput/            # Tablet driver abstraction
│   │   └── TabletInput.swift   # IOKit HID + NSEvent fallback
│   ├── FileIO/                 # Import/export
│   │   └── FileIO.swift        # .abysspaint, PSD, PNG, etc.
│   ├── AdjustmentEngine/       # Non-destructive filters
│   │   └── AdjustmentEngine.swift
│   ├── AnimationEngine/        # Timeline & onion skin
│   │   └── AnimationEngine.swift
│   ├── Preferences/            # User settings
│   │   └── Preferences.swift
│   ├── Utilities/              # Helpers
│   ├── Resources/
│   │   ├── Assets.xcassets/    # App icon, colors
│   │   ├── Brushes/            # Built-in brush definitions
│   │   └── Shaders/            # Metal shaders
│   │       └── Shaders.metal   # All GPU code
│   ├── AbyssPaint.xcdatamodeld # Core Data model
│   ├── PersistenceController.swift
│   ├── AppDelegate.swift
│   └── main.swift
└── replica/                    # Replica skill spec (planning docs)
    ├── recon.md
    ├── architecture.md
    ├── design/
    │   ├── tokens.json
│   │   └── components.md
    ├── features.csv
    ├── fixes.md
    ├── brand.md
    └── brand.json
```

## Key Technologies

| Layer | Technology |
|-------|------------|
| UI | SwiftUI + AppKit (MTKView) |
| Rendering | Metal 3 (tile-based, compute shaders) |
| Persistence | Core Data + SQLite |
| Tablet Input | IOKit HID (Wacom TabletDriverKit ready) |
| Color | ColorSync + Core Image |
| Animation | Core Animation + custom timeline |

## Brush Engine

The brush engine uses a **stamp-based approach** optimized for Metal:

1. **CPU path** (default): Generates stamp positions/parameters in Swift
2. **GPU path** (optional): Compute shader generates stamps in parallel
3. **Rendering**: Instanced drawing of quad stamps with per-instance attributes

Each brush has 100+ parameters organized into categories:
- Stroke (spacing, streamline, jitter, taper)
- Shape (source, rotation, scatter, grain)
- Rendering (mode, flow, wetness, dilution)
- Color Dynamics (pressure/tilt color, jitter)
- Dynamics (speed, rotation, flip)
- Tablet Mapping (pressure, tilt, azimuth → size/opacity/flow)

## License

MIT License - See LICENSE file for details.

## Credits

Built using the [Replica skill](https://github.com/Jakeschincariol/replica-skill) methodology.
Original Procreate by Savage Interactive.