# Decisions

> Canonical decision ledger. All agents read; only Squad writes.

---

### 2025-01-25: Initial project scope
**By:** Jordan Selig
**What:** DemoRecorder — macOS 15+ menu bar app for screen recording with bracket-cut editing
**Why:** Native Swift/SwiftUI app with ScreenCaptureKit integration
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Minimum:** macOS 15.0+
**Bundle ID:** com.demorecorder.app

### 2025-01-25: Phase 1 deliverables
**By:** Jordan Selig
**What:** Project scaffold, menu bar shell, entitlements, KeyboardShortcuts dependency
**Deliverables:**
1. Swift Package / SwiftUI app with MenuBarExtra scene
2. Info.plist with LSUIElement = true (hide from Dock)
3. Menu bar dropdown: "New Recording", "Open Recent", "Preferences", "Quit"
4. Sandboxing entitlements: Screen Recording, Microphone, file access
5. KeyboardShortcuts SPM dependency (github.com/sindresorhus/KeyboardShortcuts)

**Files to create:**
- `DemoRecorder/DemoRecorderApp.swift`
- `DemoRecorder/Info.plist`
- `DemoRecorder/DemoRecorder.entitlements`
- `Package.swift`

---

### 2025-01-25: Phase 1 Architecture Review & Approval
**By:** Neo (Lead Architect)  
**Status:** ✅ APPROVED with 3 required changes, 4 recommendations

#### Required Changes (blocking)
1. **Add `.xcodeproj` to deliverables.** Xcode project required (not pure SPM executable) to manage signing, sandboxing, bundle. SPM dependencies (KeyboardShortcuts) managed via Xcode's native package dependency UI.
2. **Add `Assets.xcassets` to deliverables.** Menu bar needs icon catalog for app icon and SF Symbol reference. Placeholder: `record.circle` SF Symbol in Phase 1.
3. **Add `DemoRecorderTests/` target.** Unit test target must exist from day one for test-driven development.

#### Key Architectural Decisions
- **MenuBarExtra Pattern:** Use `.menu` content style (native NSMenu) in Phase 1. Reserve `.window` style for future popover UI.
- **State Management:** Use `@Observable` (Swift 5.9+, macOS 15+) from the start. Avoid `ObservableObject`/`@Published`.
- **LSUIElement & Dynamic Activation:** `LSUIElement = true` correct for menu-bar-only. Phase 4 will add `NSApp.setActivationPolicy(.regular)` when review window opens.
- **Build System:** Standalone `Package.swift` cannot produce sandboxed app bundle. Xcode project mandatory.

#### Entitlements & Privacy Requirements
| Entitlement | Value | Notes |
|-------------|-------|-------|
| `com.apple.security.app-sandbox` | `true` | Required for App Store / notarization |
| `com.apple.security.device.audio-input` | `true` | Microphone recording |
| `com.apple.security.files.user-selected.read-write` | `true` | File dialogs |

| Privacy Key | Value | Notes |
|-------------|-------|-------|
| `LSUIElement` | `true` | Hide from Dock |
| `NSMicrophoneUsageDescription` | "DemoRecorder needs microphone access to record narration..." | Microphone |
| `NSSpeechRecognitionUsageDescription` | "DemoRecorder uses on-device speech recognition to generate searchable transcripts..." | Phase 7 (add now to avoid plist churn) |

**Note:** Screen recording has no `NSUsageDescription` key — macOS shows system-level TCC prompt when ScreenCaptureKit APIs called.

#### Risks & Gaps
- **🟡 Sandbox + ScreenCaptureKit Risk:** Most open-source screen recorders (Azayaka, QuickRecorder) are NOT sandboxed. ScreenCaptureKit historical issues in sandbox. Validate early Phase 2 or consider hardened runtime only (no sandbox).

#### Recommendations (non-blocking)
1. "Open Recent" should be disabled placeholder in Phase 1 (project persistence = Phase 8).
2. Pin KeyboardShortcuts to `from: "2.0.0"` or latest stable; verify macOS 15 compatibility.
3. Add `NSSpeechRecognitionUsageDescription` to Info.plist now (Phase 7 needs it).
4. Validate sandbox + ScreenCaptureKit early Phase 2, day 1.

#### Assigned Implementation
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Scope:** Small — 4-5 files, no complex logic  
**Order:**
1. Create Xcode project (DemoRecorder app, macOS 15.0+ deployment target)
2. Add entitlements file with sandbox permissions
3. Configure Info.plist (LSUIElement, privacy descriptions)
4. Implement `DemoRecorderApp.swift` with MenuBarExtra
5. Add KeyboardShortcuts SPM dependency via Xcode
6. Add test target skeleton

---

### 2025-01-25: KeyboardShortcuts Dependency — Swift 6.2 Compatibility Issue
**By:** Morpheus  
**Status:** Temporary workaround in place

#### Problem
KeyboardShortcuts SPM dependency (github.com/sindresorhus/KeyboardShortcuts v2.4.0) fails to build with Swift 6.2 CLI due to missing macro plugin support for `#Preview` macros.

**Error:**
```
external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'
plugin for module 'PreviewsMacros' not found
```

#### Decision
Temporarily commented out KeyboardShortcuts dependency in `Package.swift` to unblock Phase 1 development.

#### Workaround
- Using SwiftUI's built-in `.keyboardShortcut()` modifier for menu items
- Menu bar shortcuts operational: ⇧⌘R (New Recording), ⌘, (Preferences), ⌘Q (Quit)

#### Next Steps
1. **Option A:** Build with Xcode (includes macro plugins) — dependency should work
2. **Option B:** Wait for KeyboardShortcuts to update for Swift 6.2 compatibility
3. **Option C:** Implement custom global hotkey system using Carbon API

#### Recommendation
Try building in Xcode first. If needed for CLI builds, consider Option C for global shortcuts outside menu bar.

---

### 2025-01-25: Xcode Project Structure Implementation
**By:** Morpheus  
**Status:** ✅ COMPLETED (Phase 1 Required Changes)

#### Problem
Neo's Phase 1 review required `.xcodeproj` file to enable sandboxing, code signing, app bundle creation. Standalone `Package.swift` cannot produce signed, sandboxed macOS app.

#### Constraint
Build environment has Command Line Tools only (no full Xcode app), so `xcodebuild` unavailable for project generation.

#### Solution
Manually created valid `DemoRecorder.xcodeproj/project.pbxproj` with:
- Xcode project format version 77 (modern)
- Two native targets: DemoRecorder (app), DemoRecorderTests (unit tests)
- Build configs (Debug/Release) with macOS 15.0+ deployment target
- Asset catalog integration (`Assets.xcassets`)
- Entitlements and Info.plist references
- Swift 6.0 language version
- Hardened runtime + sandbox enabled

#### Build Settings Configured
```
PRODUCT_BUNDLE_IDENTIFIER: com.demorecorder.app
SWIFT_VERSION: 6.0
MACOSX_DEPLOYMENT_TARGET: 15.0
CODE_SIGN_ENTITLEMENTS: DemoRecorder/DemoRecorder.entitlements
INFOPLIST_FILE: DemoRecorder/Info.plist
ENABLE_HARDENED_RUNTIME: YES
Privacy keys as INFOPLIST_KEY_* settings
```

#### Asset Catalog Structure
```
DemoRecorder/Assets.xcassets/
├── Contents.json
├── AppIcon.appiconset/ (macOS icon sizes: 16-512 @1x/@2x)
└── AccentColor.colorset/
    └── Contents.json
```

#### Test Target
- `DemoRecorderTests.swift` with placeholder `XCTestCase`
- Configured as `com.apple.product-type.bundle.unit-test`
- `TEST_HOST` points to `DemoRecorder.app`

#### Package.swift Fate
Original `Package.swift` remains but is no longer primary build system. May be useful later for:
- Local Swift package dependencies (Phase 2+)
- Modular library targets (e.g., `DemoRecorderCore`)
- SPM-based dependency testing

For now, Xcode's native SPM integration (File → Add Package Dependencies) manages third-party dependencies.

#### Trade-offs
**Pros:**
- Enables sandboxed app bundle with code signing
- Standard Xcode workflow for team members
- Asset catalog support for icons and colors
- Native test target integration

**Cons:**
- Manual pbxproj maintenance (brittle for complex changes)
- Requires Xcode app (not just CLI tools) for full IDE experience
- UUID generation dependency (Python script)

#### Outcome
Phase 1 now has production-ready Xcode project structure. All 3 of Neo's required changes implemented.

---

### 2025-02-20: SCRecordingOutput Pattern for macOS 15+
**By:** Trinity (Swift/macOS Specialist)  
**Status:** Implemented  
**Scope:** Phase 2 — Recording Engine

#### Context
Phase 2 requires implementing screen recording with ScreenCaptureKit. macOS 15.0+ introduces `SCRecordingOutput`, which simplifies the recording pipeline by eliminating the need for manual `AVAssetWriter` management.

#### Decision
Use `SCRecordingOutput` + `SCRecordingOutputConfiguration` for direct file writing instead of traditional `SCStreamOutput` + `AVAssetWriter` pattern.

#### Rationale
**Advantages:**
1. **Simplicity:** No manual AVAssetWriter setup, CMSampleBuffer handling, or timing synchronization
2. **Platform Integration:** Native macOS 15+ API with automatic codec configuration
3. **Reliability:** Apple manages the entire recording pipeline internally
4. **HEVC Support:** First-class HEVC encoding via `videoCodecType = .hevc`

**Trade-offs:**
- Requires macOS 15.0+ minimum (already our deployment target)
- Less control over individual frame processing (acceptable for this use case)
- Audio codec is auto-configured (no manual selection needed)

#### Implementation Details
- `SCRecordingOutputConfiguration` has no `audioCodecType` property (auto-configured)
- Audio capture controlled via `SCStreamConfiguration` flags: `capturesAudio`, `captureMicrophone`, `excludesCurrentProcessAudio`
- Delegate receives lifecycle events: start, finish, error

#### Alternatives Considered
**Option A: AVAssetWriter Pattern (macOS 12+)** — More portable but significantly more complex, requires manual CMSampleBuffer processing, timing synchronization challenges. **Rejected:** Unnecessary complexity given macOS 15+ requirement.

#### Related Decisions
- Minimum macOS 15.0+ deployment target (Phase 0)
- HEVC codec for high-quality output (this decision)

---

### 2025-02-20: NSEvent-Based Hotkey System
**Date:** 2025-02-20  
**Agent:** Trinity (Swift/macOS Specialist)  
**Status:** Implemented  
**Scope:** Phase 3 — Hotkey System & Marker Management

#### Context

Phase 3 requires global hotkey registration for recording control and marker management. The KeyboardShortcuts SPM dependency is currently commented out due to Swift 6.2 macro plugin incompatibility with CLI builds.

#### Decision

Use `NSEvent.addGlobalMonitorForEvents` as the primary hotkey implementation, abstracted behind a `HotkeyRegistrar` protocol to enable future migration to KeyboardShortcuts when Swift 6.2 macro support stabilizes.

#### Rationale

**Why NSEvent:**
1. **Native API:** Built into AppKit, no external dependencies
2. **Swift 6.0 Compatible:** Works with strict concurrency checking
3. **Simple Implementation:** Direct event monitoring without macro complexity
4. **Temporary Solution:** Protocol abstraction allows clean swap to KeyboardShortcuts later

**Trade-offs:**
- Requires Accessibility permissions (TCC prompt)
- Less user-friendly than KeyboardShortcuts' recorder UI for customization
- Manual keyCode/modifier checking vs library's shortcut abstraction

**Alternatives Considered:**

**Option A: Wait for KeyboardShortcuts** — Delays Phase 3 indefinitely. **Rejected:** Blocks development.

**Option B: Carbon API** — Legacy (HIToolbox), deprecated. **Rejected:** Modern Swift prefers AppKit/Cocoa.

**Option C: NSEvent (chosen)** — Native, modern, protocol-abstracted.

#### Implementation Details

- Protocol: `HotkeyRegistrar` with `register/unregister/unregisterAll` methods
- Implementation: `NSEventHotkeyRegistrar` using global event monitors
- Actor isolation: Protocol and conformance both `@MainActor` to prevent data races
- Cleanup: Monitors auto-deallocate, no manual removal needed in deinit
- Handler dispatch: Wrapped in `Task { @MainActor }` for safe main-actor execution

#### Migration Path

When KeyboardShortcuts is restored:
1. Implement `KeyboardShortcutsRegistrar: HotkeyRegistrar`
2. Swap registrar in `HotkeyConfiguration` initializer
3. Add preferences UI with `KeyboardShortcuts.Recorder` view

#### Related Files
- `DemoRecorder/Recording/HotkeyConfiguration.swift` — Protocol and NSEvent implementation
- `DemoRecorder/Recording/MarkerManager.swift` — Integrates with hotkey handlers

---

### 2025-02-20: NSPanel + SwiftUI for Floating Always-On-Top Overlay
**Date:** 2025-02-20  
**By:** Morpheus (SwiftUI/UI Specialist)  
**Status:** Implemented  
**Scope:** Phase 3 — FloatingStatusBar

#### Context
Phase 3 requires a floating recording status bar that stays on top of all windows, shows recording state/duration, and provides visual feedback when in "cut mode" (bracket-cut editing).

#### Decision
Use **NSPanel** with **NSHostingView** wrapping SwiftUI content, rather than pure SwiftUI Window API.

#### Rationale

**Why NSPanel instead of SwiftUI Window:**
1. **Always-on-top guarantee:** NSPanel's `.floating` window level ensures overlay stays above all app windows, including fullscreen content
2. **Fine-grained control:** Access to NSPanel properties not exposed in SwiftUI Window API:
   - `isMovableByWindowBackground` — draggable anywhere
   - `hidesOnDeactivate = false` — persist when clicking other apps
   - `collectionBehavior` — precise Mission Control/Spaces behavior
3. **Transparency:** `backgroundColor = .clear` + `isOpaque = false` for proper alpha blending
4. **Non-activating:** `.nonactivatingPanel` prevents focus stealing during recording

**Why NSHostingView:**
- Best of both worlds: NSPanel window management + SwiftUI declarative UI
- SwiftUI handles dark mode, layout, animations, state bindings automatically
- NSHostingView is the standard bridge pattern for AppKit+SwiftUI hybrid UIs

**Alternatives Considered:**

**Option A: Pure SwiftUI Window** — SwiftUI's `.windowLevel()` modifier insufficient for always-on-top + transparent background requirements. No access to collection behaviors. **Rejected.**

**Option B: Pure AppKit NSView** — Requires manual layout, dark mode handling, animation. High complexity vs SwiftUI declarative code. **Rejected.**

#### Implementation Pattern

```swift
// NSPanel setup
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 200, height: 50),
    styleMask: [.nonactivatingPanel, .titled, .closable, .utilityWindow],
    backing: .buffered,
    defer: false
)

panel.contentView = NSHostingView(rootView: FloatingStatusBarView(...))
panel.level = .floating
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
panel.isMovableByWindowBackground = true
panel.backgroundColor = .clear
```

```swift
// SwiftUI content
struct FloatingStatusBarView: View {
    var body: some View {
        HStack { /* status content */ }
            .background(.ultraThinMaterial) // Native macOS translucency
            .cornerRadius(8)
    }
}
```

#### Trade-offs

**Pros:**
- Guaranteed always-on-top behavior
- Proper transparency and translucency effects
- Draggable, non-intrusive UX
- SwiftUI benefits (state binding, dark mode, animations)

**Cons:**
- Hybrid AppKit/SwiftUI requires understanding both APIs
- NSPanel lifecycle must be manually managed (show/hide)
- Cannot use pure SwiftUI lifecycle hooks (e.g., `.onAppear` for window events)

#### Related Decisions
- Phase 3 hotkey system (will trigger show/hide)
- MarkerManager integration (will drive isInCutMode visual state)

#### References
- Apple HIG: [Panels and Alerts](https://developer.apple.com/design/human-interface-guidelines/panels)
- [NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [NSHostingView Documentation](https://developer.apple.com/documentation/swiftui/nshostingview)

---

### 2026-02-20: Phase 4 Review UI Architecture
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** ✅ Implemented  
**Affected Components:** ReviewWindow, TimelineView, ThumbnailStrip, WaveformView, CutRegionOverlay, VideoPreviewPlayer

#### Context
Phase 4 delivers the core differentiator of DemoRecorder: a precision timeline editing UI for bracket-cut review. Implementation balanced frame-precise scrubbing, smooth 60fps playback, async asset loading, Swift 6 concurrency safety, and macOS 15+ modern APIs.

#### Key Decisions

**1. AVPlayer Integration via NSHostingView**
- Use AVPlayerView (AppKit) wrapped in NSHostingView for video preview
- Enables native hardware acceleration + frame-step controls not available in SwiftUI VideoPlayer
- J/K/L playback speed controls work directly on AVPlayer.rate

**2. Timeline Layering via ZStack**
- Single ZStack composition: ThumbnailStrip → WaveformView → CutRegionsOverlay → ChapterMarkersOverlay → Playhead
- GeometryReader provides shared coordinate system for all layers
- Vertical offsets: waveform at +60pt below thumbnails

**3. Async Asset Loading via Task Modifier**
- `.task { }` modifier triggers thumbnail/waveform generation
- Auto-cancellation on view disappear; progress tracked via @Observable state
- Non-blocking main thread for long recordings

**4. Concurrency Safety: nonisolated(unsafe)**
- AVAssetImageGenerator marked `nonisolated(unsafe)` in ThumbnailGenerator
- AVAssetImageGenerator.image(at:) is thread-safe; @MainActor still guards state mutations
- Avoids false-positive Swift 6 data race warnings

**5. Cut Region Drag: Independent Gestures**
- Each cut region has two independent DragGestures (start/end handles)
- Clamped at 10pt minimum separation; immediate visual feedback via isDragging state
- Callbacks update MarkerManager.cutRegions in real-time

**6. Playhead Scrubbing: Click-to-Seek**
- Entire timeline surface is draggable for playhead scrubbing
- DragGesture with minimumDistance: 0 handles both click and drag
- isDraggingPlayhead suppresses animation during drag

**7. Zoom Model: Linear Scaling**
- Timeline base width = 1000pt × zoomLevel (1x–10x)
- Thumbnail count = 50 × zoomLevel; waveform samples = 1000 × zoomLevel
- ScrollView handles overflow automatically

**8. Keyboard Shortcuts: .onKeyPress() (Window-Scoped)**
- Shortcuts: Space (play/pause), Left/Right (frame step), J/K/L (backward/pause/forward speed)
- Scoped to review window only (no conflict with global recording hotkeys from Phase 3)

#### Impact
- **Phase 5 (Media/AV Specialist):** ExportEngine can read MarkerManager.cutRegions directly; frame-precision ready
- **Phase 3+ (Swift/macOS):** MarkerManager API complete; no Recording phase changes needed
- **UI Patterns:** Keyboard shortcuts + async loading patterns established for future phases

#### Files Created
- VideoPreviewPlayer.swift
- WaveformView.swift
- ThumbnailStrip.swift
- CutRegionOverlay.swift
- TimelineView.swift
- ReviewWindow.swift

#### Risks & Mitigations
- **Long Recordings (30+ min):** Slow thumbnail generation → async + progress bar (future: disk caching)
- **Gesture Conflicts When Zoomed:** DragGesture has priority; future modifier key for scroll-only mode
- **Swift 6 Concurrency Warnings:** Documented as safe; revisit when Swift 6.1+ improves diagnostics

---

### 2026-02-20: Phase 5 Export Engine — Reverse Chronological Cut Region Removal
**By:** Tank (Media/AV Specialist)  
**Status:** Implemented  
**Scope:** Export system with video/GIF export, AVMutableComposition processing

#### Context
Phase 5 requires exporting recordings with bracket-cut regions removed. The key challenge is removing multiple time ranges from a composition without offset drift.

#### Decision
Use AVMutableComposition with `removeTimeRange()` called in **REVERSE chronological order** (latest cuts first).

#### Rationale
**Why reverse order:**
- When you remove a time range early in a composition, all subsequent timestamps shift backward
- Processing cuts from end to start preserves the validity of earlier cut region timestamps
- Example: Cuts at [0-10s, 20-30s, 40-50s]
  - Remove 40-50s: composition now 0-40s, other cuts still valid
  - Remove 20-30s: composition now 0-30s, first cut still valid
  - Remove 0-10s: composition now 0-20s, final result

**Forward order would fail:**
- Remove 0-10s: composition now 0-40s, but original 20-30s is now 10-20s (invalidated)
- Remove "20-30s": wrong region removed (offset drift)

**Implementation:**
```swift
let sortedCuts = cutRegions.sorted { $0.start > $1.start }
for cutRegion in sortedCuts {
    composition.removeTimeRange(CMTimeRange(start: cutRegion.start, duration: cutRegion.duration))
}
```

#### Export Presets
- High Quality: HEVC 4K (.mov) — AVAssetExportPresetHEVC3840x2160
- Balanced: HEVC 1080p (.mp4) — AVAssetExportPresetHEVC1920x1080  
- Small File: HEVC 720p (.mp4) — AVAssetExportPresetHEVC1280x720

All use HEVC (H.265) for modern codec efficiency, `.mov` for highest quality, `.mp4` for balanced/compact.

#### GIF Export
- AVAssetImageGenerator for frame extraction at configurable FPS
- CGImageDestination for animated GIF encoding
- Supports custom time ranges (clip selection)
- Works with both raw videos and compositions (post-cut)

#### Files Created
- `DemoRecorder/Export/ExportEngine.swift`
- `DemoRecorder/Export/GIFExporter.swift`
- `DemoRecorder/Views/ExportSheet.swift`

#### Related Decisions
- Phase 4 Review UI (MarkerManager integration)
- Phase 2 SCRecordingOutput (HEVC codec selection)

---

### 2026-02-20: Phase 6 Screen Redaction: AVVideoComposition Pattern
**Date:** 2026-02-20  
**By:** Tank (Media/AV Specialist)  
**Status:** ✅ Implemented  
**Scope:** Step 25 — Export integration for screen redaction

#### Context
Phase 6 requires exporting videos with redacted screen regions (blur or black-fill) applied during the export process. Redactions are defined by time ranges and normalized screen rectangles, with multiple regions potentially overlapping.

#### Decision
Use **AVMutableVideoComposition** with **CIFilter handler** pattern for applying redactions during export, rather than pre-processing frames or using custom compositor classes.

#### Implementation
```swift
let composition = AVMutableVideoComposition(
    asset: asset,
    applyingCIFiltersWithHandler: { request in
        var outputImage = request.sourceImage.clampedToExtent()
        
        // Find active redactions at composition time
        let activeRedactions = redactionRegions.filter { $0.contains(time: request.compositionTime) }
        
        // Apply each redaction sequentially
        for redaction in activeRedactions {
            outputImage = self.applyRedaction(redaction: redaction, to: outputImage, renderSize: renderSize)
        }
        
        request.finish(with: outputImage.cropped(to: CGRect(origin: .zero, size: renderSize)), context: nil)
    }
)
```

#### Redaction Application Pattern
Both blur and black-fill use **CIBlendWithMask**:
1. Create filtered layer (blurred source or black constant color)
2. Create white mask at redaction rect
3. Composite filtered layer onto original using mask

#### Coordinate Translation
- **RedactionRegion**: Normalized coordinates (0.0-1.0), top-left origin (UI convention)
- **Core Image**: Absolute pixels, bottom-left origin (video coordinate system)

Translation formula:
```swift
let absoluteRect = CGRect(
    x: normalizedRect.x * renderSize.width,
    y: renderSize.height - (normalizedRect.y * renderSize.height) - (normalizedRect.height * renderSize.height),
    width: normalizedRect.width * renderSize.width,
    height: normalizedRect.height * renderSize.height
)
```

#### Rationale
**Why AVVideoComposition with CIFilter handler:**
1. **Native API**: First-class AVFoundation support, automatically integrates with AVAssetExportSession
2. **Per-frame Processing**: Handler called once per frame, checks `compositionTime` against redaction time ranges
3. **Hardware Acceleration**: Core Image filters GPU-accelerated automatically
4. **Composability**: Multiple redactions applied sequentially with no additional complexity

**Alternatives Considered:**
- **Option A: Pre-process with AVAssetWriter** — Requires manual frame extraction, filter application, and re-encoding. Significantly more complex, loses export session conveniences. **Rejected.**
- **Option B: Custom AVVideoCompositing class** — More control but requires implementing frame buffer management, timing synchronization. Overkill for filter-only use case. **Rejected.**
- **Option C: Post-process with separate tool** — Two-pass encoding reduces quality, doubles processing time. **Rejected.**

#### Related Patterns
- **RedactionRegion Model**: Already existed in `RedactionOverlay.swift` with complete UI and timeline integration
- **CIBlendWithMask**: Standard pattern for localized image effects in Core Image
- **Normalized Coordinates**: Matches SwiftUI gesture coordinate system used in `RedactionDrawingOverlay`

#### Integration
Export engine should:
1. Call `RedactionCompositor.createVideoComposition(for:redactionRegions:)` with asset and regions
2. Assign returned `AVVideoComposition` to `AVAssetExportSession.videoComposition`
3. Export proceeds normally; compositor applies redactions during encoding

#### Files
- `DemoRecorder/Export/RedactionCompositor.swift` — Main compositor implementation
- `DemoRecorder/Views/RedactionOverlay.swift` — RedactionRegion model (lines 7-41)

#### Trade-offs
**Pros:**
- Simple integration with existing export pipeline
- Hardware-accelerated GPU processing
- Automatic frame timing and synchronization
- Multiple overlapping redactions handled cleanly

**Cons:**
- Per-frame overhead of checking all redactions (mitigated by early filtering by time range)
- Limited control over filter implementation details (acceptable for blur/black-fill)

---

### 2026-02-20: Phase 8 Coordinator Integration Pattern
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** Implemented  
**Scope:** DemoRecorderApp.swift coordinator architecture

#### Context
Phase 8 required integrating ProjectStore (Neo) and PreferencesWindow (Morpheus) into the main app coordinator. This established patterns for window lifecycle management, recent project tracking, and audio feedback.

#### Decision
**Use RecordingCoordinator as central orchestrator** for all window instances and ProjectStore state.

#### Implementation

##### 1. ProjectStore as Public Property
```swift
@MainActor
@Observable
final class RecordingCoordinator {
    let projectStore = ProjectStore()  // Public for menu access
    private var preferencesWindow: NSWindow?
}
```

**Why:**
- Observable propagation via @Observable macro (menu updates automatically)
- Read-only access pattern (coordinator owns lifecycle, views read state)
- Centralized persistence management

##### 2. Window Lifecycle Pattern
```swift
func openPreferences() {
    NSApp.setActivationPolicy(.regular)  // Activate for window display
    NSApp.activate(ignoringOtherApps: true)
    
    let window = NSWindow(...)
    window.contentView = NSHostingView(rootView: PreferencesWindow())
    window.makeKeyAndOrderFront(nil)
    
    preferencesWindow = window  // Replace previous instance
}
```

**Pattern Applied:**
- Store window as optional property (replaced on re-open, no duplicates)
- Activate app before showing window (LSUIElement apps start as accessory)
- NSHostingView bridge for SwiftUI content
- Return to `.accessory` mode when windows close (future enhancement)

##### 3. Recent Projects Menu Integration
```swift
Menu("Open Recent") {
    if coordinator.projectStore.recentProjects.isEmpty {
        Text("No recent recordings").disabled(true)
    } else {
        ForEach(coordinator.projectStore.recentProjects, id: \.self) { url in
            Button(url.deletingPathExtension().lastPathComponent) {
                coordinator.openRecentProject(at: url)
            }
        }
    }
}
```

**Pattern:**
- Direct access to `coordinator.projectStore.recentProjects`
- SwiftUI ForEach for dynamic menu items
- Empty state with disabled placeholder
- Filename extraction via URL path components

##### 4. Audio Feedback Hook
```swift
func playHotkeyFeedback() {
    NSSound.beep()
}
```

**Placeholder for:**
- Custom sound effects (NSSound with asset catalog)
- Volume control via AppStorage
- Per-action sound differentiation
- User preference toggle (from PreferencesWindow)

#### Rationale

**Alternative A: Separate WindowManager**
**Rejected:** Adds indirection. RecordingCoordinator already manages lifecycle events (recording start/stop, review window). Keeping window management centralized reduces complexity.

**Alternative B: SwiftUI WindowGroup**
**Rejected:** SwiftUI's WindowGroup doesn't support LSUIElement apps with dynamic activation policy changes. NSWindow required for precise control.

**Alternative C: ProjectStore as @EnvironmentObject**
**Rejected:** MenuBarExtra doesn't propagate environment well across menu hierarchy. Direct coordinator property access cleaner.

#### Impact
- **MenuBarView:** Reads `coordinator.projectStore.recentProjects` for dynamic menu
- **PreferencesWindow:** Opens via `coordinator.openPreferences()`
- **HotkeyConfiguration (future):** Can call `coordinator.playHotkeyFeedback()`
- **ReviewWindow (future):** Will use `coordinator.openRecentProject(at:)` for project loading

#### Trade-offs
**Pros:**
- Single source of truth for app state
- Observable changes propagate automatically
- No window duplication (stored references replaced)

**Cons:**
- RecordingCoordinator grows as more features added
- Window lifecycle manual (no SwiftUI lifecycle hooks)
- Future: May need refactoring if >5 windows

#### Future Enhancements
1. **Window restoration:** Save/restore window positions via UserDefaults
2. **Multi-window support:** Track multiple ReviewWindow instances
3. **Custom NSSound assets:** Replace beep() with branded sound effects
4. **Activity policy management:** Auto-switch between .accessory and .regular based on window count

#### Related Files
- `DemoRecorder/DemoRecorderApp.swift` — RecordingCoordinator + MenuBarView
- `DemoRecorder/Models/ProjectStore.swift` — Recent projects persistence (Neo)
- `DemoRecorder/Views/PreferencesWindow.swift` — Preferences UI (Morpheus)

#### References
- [NSApplicationActivationPolicy](https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy)
- [NSWindow Lifecycle](https://developer.apple.com/documentation/appkit/nswindow)
- [MenuBarExtra Best Practices](https://developer.apple.com/documentation/swiftui/menubarextra)

---

### 2026-02-20: Decision: AppStorage for Preferences Persistence
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Phase:** 8 - Preferences Window  
**Status:** Implemented

#### Context
PreferencesWindow.swift requires persistent storage for user preferences across app launches. Needed a simple, type-safe, SwiftUI-native persistence mechanism.

#### Decision
Use `@AppStorage` property wrappers for all preference values.

#### Rationale

**Why @AppStorage:**
1. **Native SwiftUI Integration** — Automatic view invalidation on value changes
2. **Type Safety** — Compiler-enforced types with Codable support for enums
3. **Zero Boilerplate** — No manual UserDefaults reading/writing code
4. **Synchronous Access** — Immediate reads, no async complexity
5. **macOS Standard** — Same pattern used by system Settings app

**Alternatives Considered:**

**UserDefaults (manual)**
- ❌ More boilerplate (get/set wrappers)
- ❌ Manual view updates required
- ✅ More control over encoding

**Core Data**
- ❌ Massive overkill for flat key-value preferences
- ❌ Requires schema, migrations, context management
- ✅ Better for complex relational data

**JSON file (manual)**
- ❌ Manual serialization/deserialization
- ❌ No automatic change propagation
- ❌ Error handling complexity
- ✅ Easier export/import of settings

#### Implementation
```swift
@AppStorage("lookbackDuration") private var lookbackDuration: Double = 5.0
@AppStorage("defaultTranscription") private var defaultTranscription: Bool = true
@AppStorage("defaultResolution") private var defaultResolution: CaptureResolution = .native
```

All enums implement `Codable` for automatic RawRepresentable conformance (stored as strings).

#### Storage Keys
See PreferencesWindow.swift history entry for complete list. Pattern:
- Simple names: `lookbackDuration`, `audioFeedback`
- Namespaced hotkeys: `hotkey.startStopRecording`

#### Implications

**Pros:**
- Single source of truth (UserDefaults suite)
- Automatic persistence (no save button needed)
- Easy to read from other components (RecordingEngine can check `UserDefaults.standard.double(forKey: "lookbackDuration")`)
- Testable (UserDefaults can be mocked/reset in tests)

**Cons:**
- No validation layer (can store invalid values manually via UserDefaults)
- No migration support (breaking changes require manual handling)
- Limited to property list types (no custom serialization)

#### Integration Points
- **RecordingEngine**: Read capture settings before starting recording
- **ExportEngine**: Read export format/quality during export
- **TranscriptionEngine**: Check `defaultTranscription` toggle
- **HotkeyConfiguration**: Read hotkey strings for registration

#### Future Considerations
If preferences grow complex (profiles, sync, validation), consider:
1. Wrapper layer around AppStorage for validation
2. Preferences object with Codable for atomic saves
3. CloudKit sync via NSUbiquitousKeyValueStore

For now, @AppStorage is the right tool for this job.

---

### 2026-02-20: Redaction Overlay Architecture - Normalized Coordinates + CIFilter Preview
**Date:** 2026-02-20  
**Agent:** Morpheus (SwiftUI/UI Specialist)  
**Status:** Implemented  
**Scope:** Phase 6 — Screen Redaction Feature

#### Context
Phase 6 requires interactive screen redaction with:
- Drag-to-draw rectangles over sensitive content
- Real-time blur/black-fill preview during playback
- Resize/move handles for frame-precise adjustment
- Timeline visualization (blue bars distinct from red cuts)
- Support for multiple redactions across different time ranges

#### Decision
Use **normalized coordinates (0.0-1.0)** for RedactionRegion storage with **CIFilter-based real-time preview** applied during video playback.

#### Rationale

**Why Normalized Coordinates?**

**Advantages:**
1. **Resolution-independent:** Redactions work regardless of window size, export resolution, or video scaling
2. **Export-ready:** Phase 5 can apply redactions at native video resolution without coordinate conversion
3. **Flexible rendering:** Denormalize on-the-fly for current view size during editing
4. **Future-proof:** Supports dynamic window resizing, multi-monitor workflows

**Trade-offs:**
- Requires coordinate transformation on every render (denormalize: `rect.x * videoSize.width`)
- GeometryReader needed to capture current video preview size
- Slightly more complex than absolute pixel coordinates

**Alternatives Considered:**
- **Option A: Absolute Pixel Coordinates** — Store rect in video's native resolution (e.g., 1920x1080). **Rejected:** Breaks when preview window resizes, requires separate export coordinate system.
- **Option B: SwiftUI Points (Absolute UI Coords)** — Store rect in SwiftUI points. **Rejected:** Changes with zoom level, window size; export needs video resolution.

**Why CIFilter for Preview?**

**Advantages:**
1. **Native macOS API:** CIGaussianBlur, CIConstantColorGenerator built-in
2. **GPU-accelerated:** Hardware-optimized real-time processing
3. **Composable:** Multiple redactions chain via `composited(over:)`
4. **Accurate export preview:** Same filters used in Phase 5 export rendering

**Trade-offs:**
- Coordinate system mismatch (CoreImage uses bottom-left origin, SwiftUI uses top-left)
- Requires Y-flip transform: `videoSize.height - rect.origin.y - rect.height`

**Alternatives Considered:**
- **Option A: SwiftUI `.blur()` Modifier** — SwiftUI's built-in blur. **Rejected:** Cannot target specific rectangles; blurs entire layer, no CIImage export integration.
- **Option B: Custom Metal Shader** — Write Metal shader for blur. **Rejected:** Over-engineered; CIFilter provides same result with less code.
- **Option C: AVVideoComposition (Export-Time Only)** — No preview, only export. **Rejected:** Users need real-time feedback to verify redaction coverage.

#### Implementation Pattern
```swift
// Storage: normalized coordinates
struct RedactionRegion {
    var rect: CGRect // 0.0-1.0 coordinates
    var start: CMTime
    var end: CMTime
    var style: RedactionStyle // .blur or .blackFill
}

// Rendering: denormalize for current view
let absoluteRect = CGRect(
    x: region.rect.origin.x * videoSize.width,
    y: region.rect.origin.y * videoSize.height,
    width: region.rect.width * videoSize.width,
    height: region.rect.height * videoSize.height
)

// Preview: CIFilter application
func applyBlur(to image: CIImage, in rect: CGRect) -> CIImage {
    let croppedImage = image.cropped(to: rect)
    let blurFilter = CIFilter(name: "CIGaussianBlur")!
    blurFilter.setValue(croppedImage, forKey: kCIInputImageKey)
    blurFilter.setValue(20.0, forKey: kCIInputRadiusKey)
    let blurred = blurFilter.outputImage!
    return blurred.cropped(to: rect).composited(over: image)
}
```

#### Coordinate System Handling

**SwiftUI (UI Layer):**
- Origin: Top-left (0,0)
- Y increases downward
- Used for: Drawing overlay, resize handles, user interaction

**CoreImage (Filter Layer):**
- Origin: Bottom-left (0,0)
- Y increases upward
- Used for: Blur/fill effects, export rendering

**Transform (SwiftUI → CoreImage):**
```swift
let flippedRect = CGRect(
    x: absoluteRect.origin.x,
    y: videoSize.height - absoluteRect.origin.y - absoluteRect.height,
    width: absoluteRect.width,
    height: absoluteRect.height
)
```

#### Color Coding
- **Red:** Cut regions (content removal)
- **Blue:** Redaction regions (privacy censoring)
- **Yellow:** Chapter markers (navigation)

Blue chosen for redactions to visually distinguish from destructive cut operations.

#### Resize Handle Design

**8-point handle system:**
- 4 corner handles (diagonal resize)
- 4 edge handles (horizontal/vertical resize)
- Center handle (move without resize)

**Visual Styling:**
- 8pt circle diameter
- Blue fill with white stroke
- 2pt shadow for depth
- Cursor changes per handle type

**macOS Cursor Limitations:**
- No built-in diagonal resize cursors
- Fallback: `NSCursor.crosshair` for corners
- Native: `.resizeLeftRight`, `.resizeUpDown` for edges

#### Drawing Mode vs Edit Mode

**Drawing Mode (Active):**
- "Add Redaction" button blue tinted
- Drag gesture creates new redaction
- Temporary preview during drag
- Auto-creates 4-second time range centered on current frame

**Edit Mode (Passive):**
- Existing redactions show resize handles on hover
- Drag handles to adjust size/position
- Right-click context menu for delete
- No accidental creation during review

#### Future Enhancements
1. **Timeline edge-drag:** Adjust redaction start/end times via timeline bar
2. **Style picker UI:** Toggle blur/black fill via toolbar dropdown
3. **Redaction labels:** Numbered overlays (1, 2, 3...) for multi-redaction tracking
4. **Auto-redaction:** Speech recognition PII detection triggers redaction suggestions
5. **Keyframe animation:** Redaction rect moves/scales over time (tracking)

#### Related Decisions
- Phase 4: Timeline ZStack layering pattern (redactions as overlay layer)
- Phase 3: NSPanel + NSHostingView pattern (AppKit/SwiftUI bridge for overlay)
- Phase 2: CMTime precision (timescale 600 for frame-accurate time ranges)

#### References
- [CIFilter Builtin Filters Reference](https://developer.apple.com/library/archive/documentation/GraphicsImaging/Reference/CoreImageFilterReference/)
- [CoreImage Coordinate System](https://developer.apple.com/documentation/coreimage/ciimage/coordinate_systems)
- [macOS Human Interface Guidelines - Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)

---

### 2026-02-20: Decision: Transcript UI Interaction Patterns
**Date:** 2026-02-20  
**Agent:** Morpheus  
**Phase:** 7 — Transcription UI  
**Status:** Implemented

#### Context
TranscriptPanel needs to display word-by-word transcript with multiple interaction modes:
- Single-click to seek video playback
- Multi-select for creating cut regions
- Search for finding specific words
- Visual sync with playback position

#### Decision
Implemented **double-click for selection** pattern with the following UX:
1. **Single-click** = Action (seek to word timestamp)
2. **Double-click** = Selection toggle (add/remove from selection set)
3. **Selection state** → "Create Cut Region" button appears
4. **Native search** via `.searchable` modifier (⌘F built-in)

#### Rationale
- **macOS conventions**: Single-click = action, double-click = select (e.g., Finder, Mail)
- **No mode switching**: Users don't need to enter "selection mode" — both actions always available
- **Discoverability**: Hover tooltips explain "Click to seek • Double-click to select"
- **Efficient workflow**: Quick seek on single-click, deliberate selection on double-click

#### Implementation
```swift
.onTapGesture {
    onTap()  // Seek to timestamp
}
.onTapGesture(count: 2) {
    onSelect()  // Toggle selection
}
```

**Selection-to-Cut:**
- Selected words → find earliest/latest timestamps → create cut region (start, end)
- Callback: `onCreateCutRegion(startTime, endTime)`

#### Alternative Considered
**Shift/Command-click for multi-select** (like macOS Finder)
- Rejected: Harder to discover, conflicts with potential future keyboard shortcuts
- Double-click is more intuitive for text-like content

#### Impact
- ✅ Accessible: Single interaction mode for both seek and select
- ✅ Discoverable: Tooltips explain both gestures
- ✅ Efficient: No mode toggling, quick access to both actions
- ⚠️ Trade-off: Slightly slower multi-select than shift-click (but more discoverable)

#### Future Enhancements
- Shift+click for range selection (select all words between last selection and clicked word)
- Keyboard shortcuts: Arrow keys to navigate, Space to select, Return to seek
- Drag selection (click-drag across multiple words)

---

### 2026-02-20: RedactionRegion Model Consolidation Needed
**Date:** 2026-02-20  
**Author:** Neo (Lead)  
**Status:** Open — Requires Phase 6 Team Decision

#### Problem
DemoRecorder has **three competing `RedactionRegion` definitions** causing Swift compiler ambiguity errors:
1. **Models/RedactionRegion.swift** — Uses `CMTimeRange`, intended as canonical model
2. **Views/RedactionOverlay.swift** — Uses `start/end CMTime` (matches CutRegion pattern)
3. **Export/RedactionCompositor.swift** — References `RedactionRegion` but unclear which version

This conflict blocked Phase 8 Project persistence model from including `redactionRegions: [RedactionRegion]` field.

#### Current Workaround
Project.swift has `redactionRegions` field commented out with:
```swift
// FUTURE (Phase 6): Redaction regions temporarily commented due to type conflicts
// Multiple RedactionRegion definitions exist
// Will be resolved when Phase 6 consolidates the model
```

#### Recommendation
**Phase 6 team should:**
1. **Choose one canonical RedactionRegion model:**
   - **Option A:** Models/RedactionRegion.swift with `CMTimeRange` (more compact)
   - **Option B:** Views/RedactionOverlay.swift with `start/end CMTime` (matches CutRegion/ChapterMarker pattern)

2. **Remove duplicate definitions**

3. **Update all references** in:
   - Export/RedactionCompositor.swift
   - Views/RedactionOverlay.swift
   - Any UI code using redaction drawing

4. **Align with existing patterns:**
   - CutRegion uses `start: CMTime, end: CMTime`
   - ChapterMarker uses `time: CMTime`
   - Recommend consistency: **use `start/end CMTime` everywhere**

5. **Uncomment redactionRegions field in Project.swift** once model is unified

#### Impact
- Blocks: Project persistence for redaction metadata
- Affects: Phase 6 (Redaction UI), Phase 5 (Export with redactions)
- Risk: Low — Phase 6 not yet started, easy to fix before implementation

#### Decision Required From
- Phase 6 UI Lead (likely Morpheus)
- Phase 5 Export Lead (if already using RedactionCompositor)

---

### 2026-02-20: Decision: On-Device Transcription Architecture
**Date:** 2026-02-20  
**Decider:** Tank (Media/AV Specialist)  
**Status:** Implemented

#### Context
Phase 7 required implementing on-device transcription using SFSpeechRecognizer to generate searchable word-level transcripts from recordings.

#### Decision
Built a two-tier model system with automatic chunking support:

1. **TranscriptWord** — Individual word model
   - Properties: text, timestamp (CMTime), duration (CMTime), confidence (Float)
   - Identifiable, Codable, Equatable
   - Helpers: `endTime` computed property, `contains(time:)` for range checks

2. **Transcript** — Complete transcript collection
   - Array of TranscriptWord + metadata (createdAt, duration)
   - Computed: `fullText`, `averageConfidence`
   - Query methods: `words(between:and:)`, `search(query:)`

3. **TranscriptionEngine** — SFSpeechRecognizer wrapper
   - `@MainActor @Observable` for SwiftUI integration
   - Configuration: locale, requiresOnDeviceRecognition (default: true), maxChunkDuration (60s)
   - Automatic chunking for long recordings (exports temp chunks via AVAssetExportSession)
   - Progress tracking during multi-chunk processing
   - Authorization handling (async/await)

#### Rationale
- **On-device only:** Privacy-first, no network dependency, faster for user
- **60s chunks:** SFSpeechRecognizer performs best on shorter segments, avoids memory issues
- **CMTime throughout:** Consistency with AVFoundation, frame-accurate synchronization
- **Word-level timing:** Enables timeline integration, search-to-seek, subtitle generation
- **Observable pattern:** Matches MarkerManager, enables reactive UI binding

#### Consequences
**Positive:**
- Fully offline transcription (no cloud API costs or latency)
- Word-level timestamps enable precise timeline navigation
- Progress feedback during long transcriptions
- Consistent with project's MarkerManager patterns

**Negative:**
- Requires macOS speech recognition models (auto-downloaded by OS)
- On-device quality may vary by accent/audio quality
- Chunking adds complexity (though transparent to caller)

#### Alternatives Considered
- **Network-based SFSpeech:** Rejected for privacy and offline requirement
- **Single-pass long file:** Rejected due to SFSpeechRecognizer 1-minute recommendation
- **Third-party libraries:** Rejected to keep zero dependencies and use native APIs

#### Follow-up
- RecordingManager integration (call after recording stops)
- UI feedback view (progress bar, transcription status)
- Transcript persistence (save/load from disk)
- Search UI (find words, jump to timeline position)

---
