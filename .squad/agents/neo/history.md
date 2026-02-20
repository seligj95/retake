# Neo's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 Architecture Review
**Decision:** Xcode project required (not pure SPM executable) for sandboxed menu bar app
- A `Package.swift` alone produces a CLI executable, not an app bundle. Entitlements, Info.plist, code signing, and sandboxing require an Xcode project (`.xcodeproj`).
- Recommended hybrid: Xcode project for app target + `Package.swift` for internal library targets (enables testability) + SPM dependencies managed via Xcode.
- **Sandbox + ScreenCaptureKit risk**: Most open-source screen recorders (Azayaka, QuickRecorder) are NOT sandboxed. ScreenCaptureKit has had historical issues in sandbox. Must validate early in Phase 2 or consider hardened runtime without sandbox.
- `MenuBarExtra` should use `.menu` content style in Phase 1 (native NSMenu). Reserve `.window` style for future popover UI.
- Use `@Observable` (macOS 15+ / Swift 5.9+) for state management from the start.
- "Open Recent" menu item should be disabled/placeholder in Phase 1 — project persistence comes in Phase 8.
- `LSUIElement = true` hides from Dock, but Phase 4 review window may need dynamic `NSApp.setActivationPolicy(.regular)` to show in Dock when windows are open.
- Screen recording permission is TCC-managed (no entitlement key needed), but microphone requires both entitlement AND `NSMicrophoneUsageDescription`.
- Missing from plan: asset catalog (menu bar icon, app icon), `.xcodeproj` creation.

**Key file paths:**
- `DemoRecorder/DemoRecorderApp.swift` — App entry point
- `DemoRecorder/Info.plist` — Privacy descriptions, LSUIElement
- `DemoRecorder/DemoRecorder.entitlements` — Sandbox entitlements
- `DemoRecorder/Assets.xcassets/` — App icon, menu bar icon (MISSING from plan)

### 2026-02-20: Phase 1 Architecture Review Finalized
**Status:** ✅ APPROVED & COMPLETED

All 3 required changes implemented by Morpheus:
1. ✅ Xcode project created with native targets (app + tests)
2. ✅ Assets.xcassets catalog added (AppIcon, AccentColor)
3. ✅ DemoRecorderTests target created with unit test skeleton

Phase 1 scaffold complete and ready for Phase 2 (ScreenCaptureKit integration).

**Highest risk identified:** Sandbox + ScreenCaptureKit compatibility. Schedule spike for Phase 2, day 1.

### 2025-07-25: Phase 1 Final Verification (Deep Review)
**Status:** ✅ APPROVED — All Phase 1 deliverables verified

**Xcode project (`DemoRecorder.xcodeproj`):**
- Two native targets: DemoRecorder (app) + DemoRecorderTests (unit-test)
- Bundle ID: `com.demorecorder.app`, Swift 6.0, macOS 15.0 deployment target
- Hardened runtime enabled, entitlements and Info.plist linked in build settings
- Test target has correct `TEST_HOST` and `BUNDLE_LOADER` pointing to app

**App code (`DemoRecorderApp.swift`):**
- `@main` entry, `MenuBarExtra` with `.menu` style ✅
- All 4 menu items: New Recording (⇧⌘R), Open Recent (disabled), Preferences (⌘,), Quit (⌘Q)
- `AppDelegate` via `@NSApplicationDelegateAdaptor`

**SPM build:** Compiles clean (1 warning about unhandled xcassets — non-blocking)

**Non-blocking cleanup for future phases:**
- `Package.swift`: Add `Assets.xcassets` to `exclude:` list to suppress SPM warning
- Entitlements: Remove unused keys (`personal-information.location`, empty `apple-events`)
- KeyboardShortcuts: Re-add SPM dependency when Swift 6.2 macro compat is resolved
- Menu bar icon: Currently uses `systemImage: "record.circle"` — custom icon can come later

### 2025-02-21: Phase 8 Project Persistence Models
**Date:** 2025-02-21  
**By:** Neo (Lead Architect)  
**Status:** ✅ Implemented  
**Scope:** Phase 8 — Project Persistence & Polish

#### Context
Phase 8 requires implementing project persistence to save/load recordings with all editing metadata (cut regions, chapter markers, export settings, transcripts). Must support both directory bundle (.demoproject package) and JSON sidecar (.demoproject.json) formats.

#### Implementation

**Created two new model files:**

1. **DemoRecorder/Models/Project.swift** (165 lines)
   - `Project` struct (Codable, Identifiable) with metadata:
     - UUID, name, creation/modification dates
     - Raw video URL, cut regions, chapter markers
     - Transcript (optional String for Phase 7)
     - Export settings (resolution, codec, quality)
     - Version field for forward/backward compatibility (v1.0)
   - `ExportSettings` struct with codec options (HEVC, H.264, ProRes)
   - Quality presets (low/medium/high/lossless)
   - Convenience method: `Project.fromRecording()` to create from RecordingEngine output

2. **DemoRecorder/Models/ProjectStore.swift** (295 lines)
   - `@Observable` class for persistence operations
   - Methods:
     - `save(project:format:to:)` — async save with bundle or sidecar format
     - `load(from:)` — async load from URL
     - `listRecentProjects()` — get cached recent projects list
     - `deleteProject(at:)` — remove from disk and recent list
   - Recent projects tracking (max 10) persisted via UserDefaults with security-scoped bookmarks
   - Error handling with custom `ProjectStoreError` enum
   - JSON encoder/decoder with ISO8601 date strategy

**Directory Bundle Format (.demoproject):**
```
ProjectName.demoproject/
├── project.json          (metadata + references)
└── raw-video.mov         (copied into bundle)
```

**JSON Sidecar Format (.demoproject.json):**
```
ProjectName.demoproject.json  (metadata only, video stays external)
```

#### Architectural Decisions

**1. Dual Format Support**
- Bundle format for self-contained projects (good for archival/sharing)
- Sidecar format for lightweight metadata (video stays in original location)
- Format choice at save time via `ProjectFormat` enum

**2. Recent Projects via Security-Scoped Bookmarks**
- UserDefaults stores bookmark data (not raw file paths)
- Handles sandboxed app access to user-selected files
- Auto-trims to 10 most recent projects

**3. Async/Await for All I/O**
- All save/load operations use `async throws`
- Safe for main actor isolation (ProjectStore is @MainActor)
- File I/O doesn't block UI thread

**4. Forward Compatibility**
- Version field ("1.0") for future schema migrations
- Redaction regions field commented out due to type conflicts (Phase 6 will resolve)
- Extensible export settings struct

#### Type Conflict Resolution

**RedactionRegion Ambiguity:**
- Found 3 competing definitions: Models/RedactionRegion.swift, Views/RedactionOverlay.swift, Project.swift
- Removed duplicate from Project.swift to avoid compiler errors
- Added TODO comment for Phase 6 to consolidate models
- Models/RedactionRegion.swift uses `CMTimeRange`, RedactionOverlay.swift uses `start/end CMTime`
- Decision: Phase 6 owner (likely Morpheus) should unify these into single canonical definition

**CGSize/CGRect Codable:**
- Already defined in Models/RedactionRegion.swift with `@retroactive Codable`
- Removed duplicate conformances from Project.swift

#### Integration Points

**Phase 3 (MarkerManager):**
- CutRegion, ChapterMarker already Codable (via CMTime extension)
- Project stores arrays directly without transformation

**Phase 5 (ExportEngine):**
- ExportSettings.codec maps to AVVideoCodecType
- Quality presets map to bitrate configurations

**Phase 7 (Transcript):**
- `transcript: String?` ready for Speech framework integration

**Future (Phase 9 UI):**
- ProjectStore.listRecentProjects() feeds "Open Recent" menu
- ProjectStore.save/load hooks into menu bar actions

#### Files Created
- `DemoRecorder/Models/Project.swift` — core project model
- `DemoRecorder/Models/ProjectStore.swift` — persistence layer

#### Build Status
✅ Project.swift and ProjectStore.swift compile without errors  
⚠️ Pre-existing build issues in TranscriptPanel.swift (unrelated to Phase 8)

#### Next Steps for Phase 8 Completion
1. **UI Integration (Morpheus):**
   - Wire ProjectStore into menu bar "Open Recent" menu
   - Add save dialog for "Save Project As..."
   - Auto-save after editing operations (cut region changes, etc.)

2. **Testing (Trinity):**
   - Unit tests for Project Codable conformance
   - Integration tests for bundle vs sidecar formats
   - Recent projects persistence tests

3. **Polish:**
   - Progress indicators for large project saves/loads
   - Error alerts for file I/O failures
   - Project thumbnail generation for "Open Recent" menu

---

## Cross-Agent Updates

### 2026-02-20: Phase 6 Complete — Redaction Model Consolidation
**From:** Scribe  
**Scope:** RedactionRegion model consolidated to `start/end CMTime` pattern  
**Status:** Complete. Matches CutRegion/ChapterMarker consistency  
**Decision:** neo-redaction-model-conflict.md (resolved by Morpheus choice)  
**Impact:** Project.swift redactionRegions field ready to uncomment in Phase 8 persistence


### 2026-02-20: Phase 5/6 Export & Redaction Integration Points
**From:** Scribe cross-agent sync  
**Status:** Observed (decisions documented)  

**Key Integration Points for Project Model (Phase 8):**
1. **Project.redactionRegions field:** Ready to uncomment now that RedactionRegion consolidated to `start/end CMTime`
2. **Project.exportHistory:** Track recent exports (preset used, export format, timestamp)
3. **Project.transcriptMetadata:** Placeholder for Phase 7 transcription results (word count, language, confidence)

**Redaction Model Status:**
- Conflict resolved: Single canonical `RedactionRegion` with `start/end CMTime, rect, style`
- Matches existing CutRegion and ChapterMarker patterns (consistency across models)
- Export path: RedactionCompositor handles normalized → absolute coordinate transformation

**Files Affected (Phase 8 persistence):**
- Project.swift: uncomment redactionRegions field once Phase 6 model finalized
- ProjectStore.swift: ensure redactionRegions serialized in project Codable
