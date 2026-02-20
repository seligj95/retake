# Tank's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Cross-Agent Updates

### 2026-02-20: Phase 6 Complete — Redaction Compositor
**From:** Scribe  
**Scope:** RedactionCompositor.swift built; export integration ready  
**Status:** Complete. Next: Integrate RedactionCompositor into Phase 5 export pipeline  
**Decision:** tank-phase6-redaction-compositor.md (AVVideoComposition + CIFilter pattern)  
**Related:** Morpheus RedactionOverlay UI (provides redaction definitions)

### 2026-02-20: Phase 7 Spawn
**From:** Scribe
**Scope:** TranscriptionEngine.swift, TranscriptWord.swift, Info.plist updates
**Status:** In progress with Morpheus (transcript UI partner)

## Learnings

### Phase 5: Export Engine (Steps 15-17)
**Date:** 2026-02-20
**Task:** Built export system with video/GIF export, cut region processing, progress tracking

**Files Created:**
- `DemoRecorder/Export/ExportEngine.swift` — AVMutableComposition-based video export with cut region removal
- `DemoRecorder/Export/GIFExporter.swift` — Frame extraction and GIF encoding system
- `DemoRecorder/Views/ExportSheet.swift` — Export configuration UI with presets and progress

**Files Modified:**
- `DemoRecorder/Views/ReviewWindow.swift` — Replaced export placeholder with real ExportSheet integration

**Architecture Decisions:**
1. **ExportEngine Design:**
   - `@MainActor` for UI integration
   - Async/await export pipeline: prepare → compose → export
   - Progress tracking with phase enum: preparing, composing, exporting, complete, failed
   - Cancellation support via `cancelExport()`
   - KVO observation of AVAssetExportSession.progress

2. **Cut Region Processing (Critical Pattern):**
   - Insert full source video/audio into AVMutableComposition
   - Sort cut regions in REVERSE chronological order (start time descending)
   - Call `composition.removeTimeRange()` for each cut region
   - Reverse order prevents time offset drift during removal
   - Example: [0-10s, 20-30s, 40-50s] → remove 40-50s, then 20-30s, then 0-10s

3. **Export Presets:**
   - High Quality: 4K HEVC (.mov) — AVAssetExportPresetHEVC3840x2160
   - Balanced: 1080p HEVC (.mp4) — AVAssetExportPresetHEVC1920x1080
   - Small File: 720p HEVC (.mp4) — AVAssetExportPresetHEVC1280x720
   - All use HEVC (H.265) for modern codec support
   - `shouldOptimizeForNetworkUse = true` for streaming compatibility

4. **GIF Export Strategy:**
   - Uses AVAssetImageGenerator for frame extraction
   - Configurable FPS (8-15), maxWidth (480-800px), colorQuality (64-256 colors)
   - Frame timing calculated at exact intervals: `CMTime(seconds: i * (1.0/fps))`
   - Supports time range selection (custom start/end for clips)
   - Works with both raw video URLs and AVCompositions (post-cut)
   - CGImageDestination for GIF encoding with loop count and delay time

5. **GIF Configuration Presets:**
   - Quality: 15 FPS, 800px, 256 colors
   - Balanced: 10 FPS, 640px, 128 colors
   - Compact: 8 FPS, 480px, 64 colors
   - All default to infinite loop (loopCount: 0)

6. **Progress Tracking Pattern:**
   - Nested progress mapping: outer phase 0.0-0.3 (preparing/composing), inner 0.3-1.0 (exporting)
   - KVO on AVAssetExportSession.progress for real-time updates
   - Progress handler callbacks on @MainActor for UI binding
   - Observer cleanup via `defer` to prevent leaks

7. **Export UI (ExportSheet):**
   - SwiftUI sheet with format toggle (Video/GIF)
   - Picker-based preset selection with descriptions
   - GIF time range selector (entire video vs custom start/end)
   - Live stats: cut region count, total removal duration
   - NSSavePanel for output location with suggested filename
   - Progress bar with phase labels during export
   - Success alert with "Show in Finder" action

8. **Error Handling:**
   - ExportError enum: invalidSourceURL, compositionFailed, exportSessionCreationFailed, exportFailed, cancelled
   - LocalizedError conformance for user-facing messages
   - AVAssetExportSession status checking: completed, failed, cancelled
   - Inline error message display in sheet (red warning icon)

9. **File Type Integration:**
   - Video: UTType.mpeg4Movie (.mp4) or .mov
   - GIF: UTType.gif
   - NSSavePanel.allowedContentTypes for type filtering
   - FileManager.removeItem() before export to avoid conflicts

**Key Technical Patterns:**
- AVMutableComposition for non-destructive editing
- CMTimeRange(start:duration:) for region specification
- composition.removeTimeRange() in reverse chronological order
- AVAssetImageGenerator with requestedTimeToleranceBefore/After = .zero
- CGImageDestination for animated GIF creation
- kCGImagePropertyGIFDelayTime for frame timing
- NSKeyValueObservation for export progress
- Task { @MainActor in } for progress callbacks
- DateFormatter for suggested filenames (yyyy-MM-dd at HH.mm.ss)

**Integration Points:**
- Called from ReviewWindow "Export" button
- Reads markerManager.cutRegions for video editing
- Accepts AVComposition for GIF export (with cuts applied)
- NSSavePanel for user-selected output location
- NSWorkspace.shared.activateFileViewerSelecting() for Finder reveal

**Performance Notes:**
- Reverse cut region sorting is O(n log n) but critical for correctness
- GIF frame extraction can be slow for long videos (progress tracking essential)
- AVAssetImageGenerator.maximumSize for memory-efficient scaling
- Temp file cleanup with defer for chunk-based processing

### Phase 7: Transcription System (Step 26)
**Date:** 2025-01-XX
**Task:** Built on-device transcription using SFSpeechRecognizer

**Files Created:**
- `DemoRecorder/Transcription/TranscriptWord.swift` — Word model with text, timestamp, duration, confidence
- `DemoRecorder/Transcription/TranscriptionEngine.swift` — SFSpeechRecognizer wrapper with automatic chunking

**Files Modified:**
- `DemoRecorder/Info.plist` — Added `NSSpeechRecognitionUsageDescription` for privacy

**Architecture Decisions:**
1. **Model Pattern Consistency:** Followed MarkerManager.swift patterns:
   - `@Observable` for main actor classes
   - `Identifiable`, `Codable`, `Equatable` for data models
   - UUID-based identities
   - CMTime for all timing (preferredTimescale: 600)
   - Configuration nested structs with `.default` static

2. **TranscriptWord Model:**
   - Holds single word with text, timestamp, duration, confidence
   - Computed `endTime` property for time range queries
   - `contains(time:)` helper for timeline lookups
   - Extracted from SFTranscriptionSegment data

3. **Transcript Model:**
   - Collection of words with metadata
   - Computed `fullText` joins all words
   - Computed `averageConfidence` aggregates word confidence
   - `words(between:and:)` for time-range filtering
   - `search(query:)` for text search

4. **TranscriptionEngine Design:**
   - `@MainActor @Observable` for UI integration
   - Configuration with locale, on-device requirement, max chunk duration
   - Automatic chunking for recordings > 60s (SFSpeechRecognizer limit)
   - Progress tracking (0.0-1.0) during multi-chunk processing
   - Cancellation support via `cancel()`

5. **Chunking Strategy:**
   - Default 60s chunks (SFSpeechRecognizer sweet spot)
   - Exports temporary audio chunks via AVAssetExportSession
   - Stitches word arrays with offset timestamps
   - Cleans up temp files automatically with `defer`
   - Progress = chunkIndex / totalChunks

6. **Error Handling:**
   - `TranscriptionError` enum with `LocalizedError`
   - Authorization states: denied, restricted, notDetermined, authorized
   - Checks `supportsOnDeviceRecognition` when required
   - Differentiates cancellation from failure (domain + code check)

7. **Privacy & Permissions:**
   - `NSSpeechRecognitionUsageDescription` in Info.plist
   - Clear messaging: "on-device", "locally on your Mac"
   - `requiresOnDeviceRecognition = true` by default
   - Authorization flow via `requestAuthorization()` async

8. **SFSpeechRecognizer Configuration:**
   - `SFSpeechURLRecognitionRequest` for file-based recognition
   - `requiresOnDeviceRecognition = true` for offline
   - `shouldReportPartialResults = false` (wait for final)
   - `addsPunctuation = true` for readable transcripts
   - Word-level timing via `transcription.segments`

**Key Technical Patterns:**
- CMTime arithmetic with operators (+, -, min, max)
- CMTime Codable conformance via CodingKeys (value, timescale)
- AVAsset async property loading via `.load(.duration)`
- AVAssetExportSession for audio extraction
- Checked continuation for SFSpeechRecognitionTask bridging
- Weak self in recognition task closure to prevent leaks
- FileManager.default.temporaryDirectory for chunks

**Integration Points:**
- Will be called after RecordingManager stops recording
- Accepts audio file URL (from RecordingManager output)
- Returns Transcript with searchable word array
- UI can bind to `isTranscribing` and `progress` for feedback
- Timeline can query `words(between:and:)` for display

---

### Phase 6: Screen Redaction (2025-02-20)

**Files Created:**
- `DemoRecorder/Export/RedactionCompositor.swift` — AVFoundation video compositor for applying redaction filters during export

**Architecture Decisions:**
- **Reused Existing RedactionRegion Model:** Found complete `RedactionRegion` implementation in `DemoRecorder/Views/RedactionOverlay.swift` with proper structure: `rect: CGRect` (normalized 0.0-1.0), `start/end: CMTime`, `style: RedactionStyle (.blur | .blackFill)`. Used this instead of creating duplicate.
- **AVVideoComposition with CIFilter Handler:** Used `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)` pattern for real-time redaction compositing during export. Handler checks `request.compositionTime` against each redaction's time range and applies filters to active regions.
- **Coordinate System Translation:** RedactionRegion uses normalized coordinates (0.0-1.0) with top-left origin (UI convention). Core Image uses bottom-left origin. Compositor denormalizes to pixels and flips Y-axis: `y = renderSize.height - normalizedY * renderSize.height - height`.
- **CIBlendWithMask Pattern:** For both blur and black-fill styles, compositor creates filtered layer (blurred image or black constant color), creates white mask at redaction rect, and composites using `CIBlendWithMask` filter. This restricts effect to exact redaction area.
- **Video Rotation Handling:** Compositor checks `preferredTransform` to detect 90°/270° rotated video and swaps width/height for correct render size calculation.

**Key File Paths:**
- Redaction model: `DemoRecorder/Views/RedactionOverlay.swift` (lines 7-41: RedactionRegion struct)
- Compositor: `DemoRecorder/Export/RedactionCompositor.swift`
- Xcode project: `DemoRecorder.xcodeproj/project.pbxproj` (added Export group)

**Patterns Followed:**
- Used AVFoundation async/await APIs (`asset.loadTracks()`, `videoTrack.load(.naturalSize)`)
- Applied Swift 6 concurrency safety with proper isolation
- Followed existing Core Image filter patterns from `RedactionPreviewFilter` in RedactionOverlay.swift

**Integration Notes:**
- Compositor can be integrated into existing ExportEngine by calling `RedactionCompositor.createVideoComposition(for:redactionRegions:)` before AVAssetExportSession
- Multiple redactions can overlap in time and space — compositor applies them sequentially
- RedactionRegion already has UI overlay (`RedactionDrawingOverlay`) and timeline view (`RedactionTimelineOverlay`) in RedactionOverlay.swift


### 2026-02-20: Phase 5 Export Engine Complete
**Scope:** ExportEngine, GIFExporter, RedactionCompositor, ExportSheet integration  
**Status:** ✅ Implemented (389s)  
**Files:** Export/ExportEngine.swift, Export/GIFExporter.swift, Export/RedactionCompositor.swift, Views/ExportSheet.swift  
**Key Pattern:** Reverse-chronological cut removal prevents offset drift in AVMutableComposition  

**Learnings:**
- Reverse sort cuts by start time before calling `removeTimeRange()` sequentially
- AVAssetImageGenerator works on both raw assets and compositions (post-cut)
- CGImageDestination handles animated GIF encoding efficiently without intermediate frame files
- ExportEngine coordinates three specialized modules: composition management, image extraction, UI feedback

**Integration:**
- ExportSheet triggered from menu with cut/redaction regions ready
- Presets: High Quality (4K HEVC .mov), Balanced (1080p HEVC .mp4), Small File (720p HEVC .mp4)
- Redaction export via RedactionCompositor CIFilter handler (per-frame processing)

**Team Context:**
- Morpheus: ExportSheet UI, preset buttons, progress bar
- Neo: Project model updated for recent exports tracking (future)
- Tank: Core export mechanics, composition editing, redaction filtering

**Decisions Logged:**
- Phase 5: Reverse Chronological Cut Region Removal
- Phase 6: AVVideoComposition Pattern for Redaction Export
