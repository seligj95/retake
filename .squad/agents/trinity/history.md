# Trinity's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 — macOS Permissions & Entitlements
**Decision:** Created Info.plist and DemoRecorder.entitlements for macOS 15+ sandboxed app
**Files:**
- `DemoRecorder/Info.plist` — Bundle configuration with LSUIElement=true, privacy descriptions
- `DemoRecorder/DemoRecorder.entitlements` — App Sandbox with screen recording, microphone, camera, file access

**Privacy Keys (macOS 15+):**
- `NSScreenCaptureDescription` — Required for ScreenCaptureKit
- `NSMicrophoneUsageDescription` — Audio recording
- `NSCameraUsageDescription` — Optional camera overlay

**Entitlements:**
- `com.apple.security.app-sandbox` — Required for Mac App Store distribution
- `com.apple.security.device.audio-input` — Microphone access
- `com.apple.security.device.camera` — Camera access
- `com.apple.security.files.user-selected.read-write` — Save recordings to user-chosen locations

**Pattern:** LSUIElement=true hides app from Dock, shows only menu bar icon (background app)

### 2026-02-20: Phase 1 Entitlements & Privacy Configuration Finalized
**Status:** ✅ COMPLETED

Phase 1 entitlements and privacy configuration integrated into production Xcode project:
- Info.plist privacy descriptions validated and embedded in pbxproj build settings
- DemoRecorder.entitlements integrated with Xcode code signing configuration
- Sandbox entitlements properly referenced in build settings (CODE_SIGN_ENTITLEMENTS)
- macOS 15+ privacy keys configured: NSScreenCaptureDescription, NSMicrophoneUsageDescription, NSCameraUsageDescription

**Next phase (Phase 2):** Validate sandbox does not block ScreenCaptureKit at runtime (highest identified risk).
**Phase 7 prep:** NSSpeechRecognitionUsageDescription already added to Info.plist to avoid churn.

### 2025-02-20: Phase 2 — Recording Engine Implementation
**Status:** ✅ COMPLETED

Built complete ScreenCaptureKit recording engine with macOS 15+ SCRecordingOutput integration.

**Files Created:**
- `DemoRecorder/Recording/RecordingEngine.swift` — Core recording engine with SCK integration
- `DemoRecorder/Recording/CaptureSourcePicker.swift` — UI for selecting displays/windows
- `DemoRecorder/Recording/RegionSelector.swift` — Full-screen overlay for region selection
- `DemoRecorder/DemoRecorderApp.swift` — Updated with RecordingCoordinator integration

**Architecture Decisions:**

1. **macOS 15+ SCRecordingOutput Pattern**
   - Uses `SCRecordingOutput` + `SCRecordingOutputConfiguration` to write directly to `.mov`
   - No manual AVAssetWriter needed (major simplification vs. macOS 14)
   - Delegate pattern with `SCRecordingOutputDelegate` for lifecycle events
   - Outputs HEVC video to temp directory with UUID-based filenames

2. **Concurrency & Sendable**
   - Used `@preconcurrency import ScreenCaptureKit` to suppress Sendable warnings
   - ScreenCaptureKit APIs are not yet Sendable-compliant in macOS 15
   - All recording operations are `@MainActor` isolated via `@Observable` class

3. **State Management**
   - Custom State enum with computed properties (`.isIdle`, `.isStopped`, `.isRecording`)
   - Avoids Equatable conformance issues with associated values (`.failed(Error)`)
   - Observable pattern for SwiftUI integration

4. **Capture Modes**
   - Full-screen: `SCContentFilter(display:excludingWindows:)`
   - Single-window: `SCContentFilter(desktopIndependentWindow:)`
   - Region: Display filter + sourceRect/destinationRect (not yet implemented)

5. **Configuration**
   - Default: 1920x1080 @ 60fps, HEVC codec
   - Audio: System audio + microphone, excluding current process
   - 48kHz stereo audio, 5-frame queue depth

6. **UI Integration**
   - `RecordingCoordinator` mediates between menu bar and recording engine
   - Dynamic activation policy: `.regular` for picker window, `.accessory` during recording
   - CaptureSourcePicker enumerates displays/windows via `SCShareableContent.current`
   - RegionSelector uses borderless NSWindow at `.screenSaver` level for overlay

**Key Patterns:**
- Async/await throughout (no completion handlers)
- Swift 6.0 strict concurrency enabled
- Removed `#Preview` macros (SPM build incompatibility)
- Window management: NSWindow + NSHostingView for SwiftUI integration

**Technical Notes:**
- `SCRecordingOutputConfiguration` has no `audioCodecType` property (video-only config)
- Audio automatically captured based on `SCStreamConfiguration` flags
- Region selection UI built but not wired to engine (sourceRect NYI)

**Build Status:** ✅ Compiles cleanly with `swift build`

**Next Phase:** Phase 3 (Hotkey System & Marker Management) — global shortcuts, MarkerManager, FloatingStatusBar

### 2025-02-20: Phase 3 — Hotkey System & Marker Management
**Status:** ✅ COMPLETED

Built global hotkey registration system and marker management infrastructure for bracket-cut editing workflow.

**Files Created:**
- `DemoRecorder/Recording/HotkeyConfiguration.swift` — Global hotkey registration with protocol abstraction
- `DemoRecorder/Recording/MarkerManager.swift` — Cut region and chapter marker management

**Architecture Decisions:**

1. **Hotkey Registration Protocol Pattern**
   - Created `HotkeyRegistrar` protocol to abstract hotkey implementation
   - Enables future migration from NSEvent to KeyboardShortcuts SPM when Swift 6.2 macro support stabilizes
   - Default implementation: `NSEventHotkeyRegistrar` using `NSEvent.addGlobalMonitorForEvents`
   - Protocol isolated to `@MainActor` to prevent data races

2. **NSEvent-Based Global Hotkeys**
   - Uses `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` for global hotkey capture
   - Requires Accessibility permissions on macOS 10.15+
   - Default hotkey bindings:
     - ⌘⇧R: Start/Stop recording
     - ⌘⇧X: Toggle cut mode (bracket-cut start/end)
     - ⌘⇧M: Drop chapter marker
   - Handlers wrapped in `Task { @MainActor }` to safely dispatch to main actor

3. **Bracket-Cut Toggle Behavior**
   - First press: Enters cut mode, records start time with lookback applied
   - Second press: Exits cut mode, creates `CutRegion` from start to current time
   - Default lookback: 5 seconds (configurable)
   - Lookback rationale: User typically realizes mistake after it happens, not during

4. **Marker Models**
   - `CutRegion`: Start/end CMTime pair representing sections to remove on export
   - `ChapterMarker`: Single CMTime + label for navigation
   - Both use UUID for identity (support deletion/modification in UI)
   - CMTime extended with Codable conformance for project persistence

5. **State Management**
   - `MarkerManager` is `@MainActor` + `@Observable` for SwiftUI integration
   - Tracks `isInCutMode` and `currentCutStart` for toggle state
   - Arrays of cut regions and chapter markers
   - Methods for add/remove/update with frame-precise editing support

6. **Concurrency & Swift 6.0 Strict Mode**
   - Protocol isolated to `@MainActor` to prevent conformance isolation warnings
   - Deinit cleanup note: NSEvent monitors auto-clean on deallocation
   - All marker operations are main-actor isolated (UI-bound data)

**Integration Points:**
- `HotkeyConfiguration.register(action:handler:)` — Register hotkey handlers in RecordingEngine
- `MarkerManager.toggleCutMode(currentTime:)` — Called from hotkey handler with `RecordingEngine.recordingDuration`
- `MarkerManager.dropChapterMarker(time:label:)` — Called from chapter hotkey handler

**Technical Patterns:**
- Protocol abstraction for library migration (KeyboardShortcuts → NSEvent → future)
- CMTime arithmetic for lookback calculation (`CMTime(seconds:)`, subtraction)
- Swift 6.0 actor isolation enforcement
- Observable pattern for real-time UI updates

**Build Status:** ✅ Compiles cleanly with `swift build`

**Next Phase:** Phase 4 (Review UI) — Timeline view, video preview, waveform rendering, cut region editing

### 2026-02-20: Phase 3 Completion — Hotkey System & Marker Management
**Status:** ✅ COMPLETED
**Agent:** Trinity + Team Integration

Phase 3 hotkey and marker management system fully integrated and operational. Work continues into Phase 4 (Review UI) with timeline/preview infrastructure.

**Deliverables Verified:**
- HotkeyConfiguration.swift operational with NSEvent protocol abstraction
- MarkerManager.swift tracking cut regions and chapter markers
- Integration complete with RecordingCoordinator
- FloatingStatusBar integration ready (Morpheus completed complementary UI)
- Full build success via swift build and Xcode project
