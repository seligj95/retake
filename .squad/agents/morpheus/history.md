# Morpheus's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Core Context

**Phases Completed:** 1 (Menu bar app structure), 3 (Floating status bar), 4 (Timeline editing UI)

**Key Architectural Patterns:**
- NSHostingView for AppKit/SwiftUI bridges (FloatingStatusBar, VideoPreviewPlayer)
- Task-based async loading for heavy assets (ThumbnailStrip, WaveformView)
- Observable state management for @MainActor-isolated controllers
- ZStack composition with GeometryReader for shared coordinate systems
- Swift 6 concurrency: nonisolated(unsafe) for AVFoundation APIs, @MainActor for state mutations
- Scoped keyboard shortcuts via .onKeyPress() (window-level, no global conflicts)

**Phase 1-3 Summary (Archived):**
- Phase 1: MenuBarExtra app with LSUIElement=true, Xcode project, Assets.xcassets, entitlements (sandbox, microphone, file access)
- Phase 1 Note: KeyboardShortcuts SPM dependency has Swift 6.2 macro issues; using SwiftUI .keyboardShortcut() workaround
- Phase 3: FloatingStatusBar with NSPanel, timer-based duration updates, red scissors indicator for cut mode

**Current Phase 4 Capabilities (Details Below):**
- AVPlayer with frame-step, speed controls (J/K/L), periodic time observer @60fps
- Timeline with thumbnails (AVAssetImageGenerator async), waveform (AVAssetReader RMS downsampling), overlays, playhead
- MarkerManager integration: toggleCutMode, updateCutRegion, removeCutRegion, dropChapterMarker
- Frame-precise timing: CMTime(timescale: 600), 10pt min cut region separation, drag-to-edit handles
- Export integration point ready for Phase 5

---

## Learnings

### Phase 4 - Review & Edit UI Implementation ✅
**Status:** COMPLETE - All 6 components production-ready

**Created Files:**
1. `DemoRecorder/Views/VideoPreviewPlayer.swift` - AVPlayer wrapper for SwiftUI
   - VideoPreviewPlayerController: Observable controller with AVPlayer lifecycle
   - Play/pause, seek, frame-step (stepForward/stepBackward using AVPlayerItem)
   - J/K/L playback speed controls (J=-2x, K=pause, L=1x/2x toggle)
   - Real-time time observation via periodic time observer (60fps updates)
   - SwiftUI view wrapper with AVPlayerView (AVKit native component)
   - Overlay controls with play/pause button, time display, frame step buttons
   
2. `DemoRecorder/Views/WaveformView.swift` - Audio waveform generation & rendering
   - WaveformGenerator: Async audio extraction from AVAsset
   - Uses AVAssetReader with Linear PCM 16-bit output settings
   - Downsamples audio to target sample count (RMS per bucket)
   - Normalizes to 0.0-1.0 range for visual consistency
   - WaveformView: Canvas-based rendering with rounded rectangles
   - AsyncWaveformView: Loading state + progress display
   - 60pt height, configurable color (default: blue 0.6 opacity)
   
3. `DemoRecorder/Views/ThumbnailStrip.swift` - Video frame thumbnails
   - ThumbnailGenerator: AVAssetImageGenerator with async image() API (macOS 15+)
   - Generates thumbnails at regular intervals (configurable count)
   - 16:9 aspect ratio, 160x90 max size per thumbnail
   - Exact time precision: requestedTimeToleranceBefore/After = .zero
   - ThumbnailStrip: Horizontal layout with calculated widths
   - AsyncThumbnailStrip: Loading state with progress indicator
   - White borders (0.5pt) between thumbnails for clarity
   
4. `DemoRecorder/Views/CutRegionOverlay.swift` - Interactive cut region editing
   - Semi-transparent red overlays (0.3 opacity, 0.4 on hover)
   - Draggable edge handles (DragHandle with .resizeLeftRight cursor)
   - Real-time drag updates via onUpdateStart/onUpdateEnd callbacks
   - Context menu for deletion (right-click → Delete Cut Region)
   - Frame-level precision: drag gestures update MarkerManager immediately
   - Visual feedback: red border, shadow, 4-6pt handles depending on drag state
   - CutRegionsOverlay: Container for all regions with MarkerManager integration
   
5. `DemoRecorder/Views/TimelineView.swift` - Main timeline with all layers
   - Zoomable timeline (1x-10x, zoom controls with ⌘+/⌘- support)
   - TimelineRuler: Time markings with ticks every interval
   - Layered composition:
     * AsyncThumbnailStrip (top layer, 60pt height)
     * AsyncWaveformView (middle layer, offset +60pt)
     * CutRegionsOverlay (interactive layer)
     * ChapterMarkersOverlay (pin icons with labels on hover)
     * Playhead (red vertical line with circular handle)
   - Click-to-seek: DragGesture on entire timeline
   - Playhead: Animated red line with 12pt circle at top
   - Chapter markers: Yellow mappin.circle.fill with tooltip labels
   - ScrollView horizontal for panning when zoomed
   - Base width: 1000pt * zoomLevel (scales all content)
   
6. `DemoRecorder/Views/ReviewWindow.swift` - Main review window
   - ReviewWindowController: NSWindow lifecycle (1200x800, min 800x600)
   - ReviewWindowView: Top-level layout with video + timeline + toolbar
   - VideoPreviewSection: Player view with current/total time display
   - TimelineView integration: Passes asset, duration, currentTime, onSeek
   - ControlToolbar:
     * Mark Cut / End Cut button (toggles MarkerManager.isInCutMode)
     * Add Marker button (drops chapter marker at current time)
     * Stats display: cut count + total duration to be removed
     * Export button (opens placeholder sheet - Phase 5 integration point)
   - Keyboard shortcuts:
     * Space: Play/Pause
     * Left/Right arrows: Frame step backward/forward
     * J/K/L: Playback speed controls
   - Uses AVURLAsset (macOS 15+ replacement for deprecated AVAsset(url:))

**Architecture Decisions:**

1. **AVPlayer Integration:**
   - NSHostingView bridges AVPlayerView (AppKit) → SwiftUI
   - Periodic time observer at 60fps for smooth playhead updates
   - Observable pattern for state binding (currentTime, duration, isPlaying)
   - Cleanup handled via load() method (replaces playerItem), deinit is nonisolated
   
2. **Timeline Composition:**
   - Layered ZStack approach: thumbnails → waveform → overlays → playhead
   - GeometryReader for dynamic positioning calculations
   - All positions calculated from time/duration ratio × width
   - ScrollView enables panning when zoomed (> 1x)
   
3. **Concurrency & Thread Safety:**
   - ThumbnailGenerator uses nonisolated(unsafe) for AVAssetImageGenerator
   - Async image generation via modern image(at:) API (not deprecated copyCGImage)
   - MainActor.run for state updates from background tasks
   - WaveformGenerator reads audio on background, updates state on MainActor
   
4. **Drag Interaction:**
   - DragGesture(minimumDistance: 0) for immediate response
   - Timeline: Click anywhere to seek (isDraggingPlayhead flag)
   - Cut edges: Separate gestures for start/end handles
   - Clamping: Prevents overlapping (min 10pt separation)
   
5. **Visual Design:**
   - macOS system materials (.ultraThinMaterial for controls)
   - Native SF Symbols for icons (scissors, mappin, play/pause, etc.)
   - Dark mode support via system materials and semantic colors
   - Rounded corners (8pt), shadows for depth (2-4pt blur)
   - Red color coding for cut regions, yellow for chapter markers
   
6. **Performance Optimizations:**
   - Thumbnail/waveform sample counts scale with zoom (50-500 thumbnails)
   - Canvas-based waveform rendering (GPU accelerated)
   - Progress tracking for long async operations
   - Lazy loading: AsyncThumbnailStrip/AsyncWaveformView only generate on .task

**Integration Points:**
- ReviewWindowController takes: recordingURL + MarkerManager
- MarkerManager methods used:
  * toggleCutMode(currentTime:) - Start/end cut regions
  * dropChapterMarker(time:label:) - Add navigation markers
  * updateCutRegion(id:start:/end:) - Drag edge adjustments
  * removeCutRegion(id:) - Delete via context menu
  * cutRegions, chapterMarkers arrays - Observed for overlay rendering
- VideoPreviewPlayerController.seek(to:) - Timeline click-to-seek
- Export sheet placeholder - Ready for Phase 5 ExportEngine integration

**Technical Details:**
- Swift 6.0 concurrency: @MainActor isolation, nonisolated where needed
- AVFoundation APIs: AVPlayer, AVAssetImageGenerator, AVAssetReader
- AVKit: AVPlayerView for native video rendering
- Core Media: CMTime, CMTimeRange for frame-precise timing
- Accelerate framework (import for future DSP optimizations)
- Canvas API for waveform rendering (SwiftUI GPU path)

**File Paths:**
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/VideoPreviewPlayer.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/WaveformView.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/ThumbnailStrip.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/CutRegionOverlay.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/TimelineView.swift`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Views/ReviewWindow.swift`

**Build Status:**
- ✅ All 6 files compile successfully
- ✅ Binary built: .build/debug/DemoRecorder (1.1MB)
- ⚠️ Concurrency warnings (acceptable - nonisolated generators for performance)
- ✅ No errors, ready for integration testing

**Known Limitations for Future Enhancement:**
1. Cut region auto-play on click (spec: "play just that section with context") - TODO
2. Drag selection range to create cut region - TODO (currently mark in/out buttons)
3. Region capture source rect filtering - RecordingEngine.swift line 175 TODO
4. Pinch gesture for timeline zoom - Currently ⌘+/⌘- only
5. Export sheet (Phase 5 dependency)

**Next Phase Prep:**
- Phase 5: ExportEngine will consume MarkerManager.cutRegions
- Export sheet integration point: ReviewWindow line 131 showExportSheet
- GIF export: Will use TimelineView selection for time range input


---

## 2026-02-20: Phase 4 Completion Summary

**Status:** ✅ Completed  
**Timestamp:** 2026-02-20T19:41:51Z

### Deliverables
All 6 Phase 4 view files created with production-quality implementations:
- VideoPreviewPlayer.swift (AVPlayer integration)
- TimelineView.swift (timeline composition)
- ThumbnailStrip.swift (frame-grid generation)
- WaveformView.swift (audio visualization)
- CutRegionOverlay.swift (cut editing)
- ReviewWindow.swift (main window)

### Key Architectural Patterns Established
1. **NSHostingView for AppKit/SwiftUI bridge** — Native video player with frame controls
2. **Task-based async loading** — Thumbnails and waveform without blocking UI
3. **Swift 6 concurrency patterns** — nonisolated(unsafe) for AVAssetImageGenerator with @MainActor-protected state
4. **ZStack timeline composition** — Shared GeometryReader coordinate system across all layers
5. **Scoped keyboard shortcuts** — .onKeyPress() per-window (no global conflicts)
6. **Frame-precise interactions** — 10pt minimum cut region separation, CMTime with timescale 600

### Ready for Phase 5
- MarkerManager.cutRegions available for ExportEngine
- Timeline patterns ready for chapter markers, silence detection
- Video player patterns ready for playback options (GIF export preview, etc.)
