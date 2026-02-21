# Contributing to Retake

Thanks for your interest in contributing! Whether it's a bug report, feature request, or a pull request, all contributions are welcome.

## Reporting Issues

If you find a bug or have a feature idea, [open an issue](https://github.com/seligj95/retake/issues). Please include:

- macOS version
- Steps to reproduce (for bugs)
- Expected vs actual behavior

## Pull Requests

Feel free to submit a PR for bug fixes, improvements, or new features:

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Build and test locally (see below)
4. Submit a PR with a clear description of the change

## Building from Source

```bash
# Requires Xcode 16+ / Swift 6.0+

# Open in Xcode
open Retake.xcodeproj

# Build and run from Xcode (⌘R)
# Or build from command line:
xcodebuild -project Retake.xcodeproj -scheme Retake -configuration Release build
```

## Project Structure

```
Retake/
├── RetakeApp.swift              # App entry point, RecordingCoordinator, MenuBarView
├── Recording/
│   ├── RecordingEngine.swift         # Core recording with segment-based redo
│   ├── CaptureSourcePicker.swift     # Display/window selection UI
│   ├── RedactionCompositor.swift     # CIFilter-based blur/black redaction
│   ├── RegionSelector.swift          # Screen region capture mode
│   └── HotkeyConfiguration.swift    # Hotkey definitions
├── Models/
│   ├── Project.swift                 # Project data model
│   ├── ProjectStore.swift            # Project persistence & recent projects
│   ├── RedactionRegion.swift         # Redaction region model
│   └── AppVersion.swift              # Version constant & comparison
├── Services/
│   └── UpdateService.swift           # GitHub release update checker
├── Views/
│   ├── FloatingStatusBar.swift       # Recording controls overlay
│   ├── OnboardingWindow.swift        # First-launch permission setup
│   ├── PreferencesWindow.swift       # Settings (format, etc.)
│   ├── RedactionEditorWindow.swift   # Interactive redaction drawing
│   ├── RedoPreviewPanel.swift        # Redo preview with scrubber
│   ├── TrimEditorWindow.swift        # Dual-handle trim editor
│   └── VideoPreviewPlayer.swift      # AVPlayer wrapper
├── Assets.xcassets/
├── Info.plist
└── Retake.entitlements
```

## Publishing a Release

1. Update the version in `Retake/Models/AppVersion.swift` and `Retake/Info.plist`
2. Build a Release archive in Xcode: Product → Archive
3. Export the `.app`, zip it as `Retake.app.zip`
4. Create a GitHub Release with tag `vX.Y.Z` (e.g., `v1.0.0`)
5. Attach `Retake.app.zip` to the release
6. Add release notes describing what changed

Users will be notified automatically on launch.
