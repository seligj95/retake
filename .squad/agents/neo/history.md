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

### 2025-01-XX: Step 34 — First-Launch Onboarding Flow
**Date:** 2025-01-XX  
**By:** Neo (Lead Architect)  
**Status:** ✅ Implemented  
**Scope:** Phase 9+ — Onboarding & Polish

#### Context
DemoRecorder requires three critical macOS permissions to function:
1. Screen Recording (ScreenCaptureKit) — **mandatory**, cannot record without it
2. Microphone access (AVFoundation) — optional for audio commentary
3. Speech Recognition (Speech framework) — optional for transcript generation

macOS requires explicit user consent for each via TCC (Transparency, Consent, and Control). First launch must guide users through permission granting with clear explanations.

#### Implementation

**Created:** `DemoRecorder/Views/OnboardingWindow.swift` (540 lines)

**Multi-Step Flow:**
1. **Welcome Step** — App introduction, feature highlights
2. **Screen Recording Step** — Direct users to System Settings (no programmatic request API)
3. **Microphone Step** — In-app permission request with skip option
4. **Speech Recognition Step** — In-app permission request with skip option
5. **Completion Step** — Tips for getting started

**OnboardingCoordinator (@MainActor @Observable):**
- `Step` enum for navigation (welcome → screenRecording → microphone → speechRecognition → complete)
- Permission state tracking: `screenRecordingGranted`, `microphoneGranted`, `speechRecognitionGranted`
- `shouldShowOnboarding()` — checks UserDefaults flag + permission states
- `markCompleted()` — sets "hasCompletedOnboarding" UserDefaults flag
- Permission checking methods using `AVCaptureDevice.authorizationStatus()`, `SFSpeechRecognizer.authorizationStatus()`, `SCShareableContent` API
- Permission request methods (async for microphone/speech, System Settings redirect for screen recording)

**AppDelegate Integration:**
- Modified `applicationDidFinishLaunching()` to check `shouldShowOnboarding()` on launch
- Shows onboarding window with `.accessory` → `.regular` activation policy switch
- Window is modal-like (close button removed) until screen recording permission granted
- On dismissal, returns to `.accessory` mode (menu bar only)

#### Architectural Decisions

**1. Show Onboarding Until Screen Recording Granted**
- **Decision:** Screen recording permission is mandatory — cannot dismiss onboarding without it
- **Rationale:** App is unusable without ScreenCaptureKit access; microphone/speech are optional enhancements
- **Implementation:** Remove `.closable` from window styleMask; "Continue" button checks permission state
- **Edge Case:** If user previously completed onboarding but later revoked screen recording permission, show onboarding again on next launch

**2. First Launch Detection via UserDefaults**
- **Decision:** Use `hasCompletedOnboarding` boolean flag in UserDefaults
- **Alternatives Considered:**
  - File marker in Application Support: More complex, unnecessary for simple flag
  - Check all permission states: Would re-show onboarding every time permissions change (too aggressive)
- **Rationale:** Simple, standard pattern for first-launch detection
- **Reset Mechanism:** `OnboardingCoordinator.resetOnboarding()` for testing/debugging

**3. Screen Recording Permission via System Settings Redirect**
- **Decision:** Direct users to `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture` URL
- **Rationale:** macOS provides no programmatic API to request screen recording permission (unlike microphone/speech). ScreenCaptureKit APIs trigger system TCC prompt on first use, but cannot be requested in advance.
- **UX Flow:** 
  1. Show instructional steps (numbered 1–4)
  2. "Open System Settings" button launches Settings app
  3. User manually toggles DemoRecorder in Screen Recording privacy pane
  4. Returns to onboarding, clicks "I've Enabled Permission" to verify
  5. `refreshPermissionStates()` checks via `SCShareableContent` attempt

**4. Optional Permissions with Skip Buttons**
- **Decision:** Microphone and Speech Recognition steps have "Skip" button alongside "Enable" button
- **Rationale:** Not all users need audio recording or transcripts; forcing permissions creates friction and poor UX
- **Impact:** Users can enable later in Preferences (future Phase 9 integration)

**5. Permission State Checking Methods**

**Screen Recording:**
```swift
// Use SCShareableContent as permission probe
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
// Success = permission granted; error = not granted
```

**Microphone:**
```swift
AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
```

**Speech Recognition:**
```swift
SFSpeechRecognizer.authorizationStatus() == .authorized
```

#### UI/UX Design

**Progress Bar:**
- Linear progress indicator at top showing current step (0/4 → 4/4)
- Provides visual feedback on onboarding completion

**Step Structure:**
- Each step follows consistent pattern: icon (72pt) → title → description → action buttons
- Checkmark icon + green color when permission granted
- Clear instructional steps for Screen Recording (numbered 1–4)
- Bullet points for privacy/feature explanations

**Navigation:**
- "Back" button (except on Welcome step)
- "Continue" button (dynamic label: "I've Enabled Permission" on Screen Recording step)
- "Get Started" button on completion step
- Keyboard shortcuts: Return (continue), Escape (back)

**Color Semantics:**
- Blue: Primary actions and icons (default state)
- Green: Success states (checkmark, permission granted)
- System materials: `.ultraThinMaterial` for native macOS look

#### Integration Points

**Phase 2 (RecordingEngine):**
- RecordingEngine will naturally fail if screen recording not granted (ScreenCaptureKit throws error)
- Onboarding ensures permission granted before user attempts recording

**Phase 7 (TranscriptionEngine):**
- TranscriptionEngine.requestAuthorization() already handles speech permission
- Onboarding front-loads this permission request for better UX

**Phase 9 (Preferences):**
- Future Preferences window should link to onboarding for permission re-requests
- Can reuse individual step views (MicrophoneStep, SpeechRecognitionStep) in Preferences UI

**AppDelegate Lifecycle:**
- Onboarding window shown before any other UI (menu bar remains hidden during onboarding)
- `NSApp.setActivationPolicy(.regular)` to show window + Dock icon
- On dismissal, `NSApp.setActivationPolicy(.accessory)` to hide from Dock

#### Files Created
- `DemoRecorder/Views/OnboardingWindow.swift` — complete onboarding UI and coordinator

#### Files Modified
- `DemoRecorder/DemoRecorderApp.swift` — added onboarding trigger in AppDelegate

#### Build Status
✅ OnboardingWindow.swift compiles without errors  
✅ DemoRecorderApp.swift compiles without errors  
⚠️ Pre-existing build errors in ExportEngine.swift, GIFExporter.swift, PreferencesWindow.swift (unrelated to Step 34)

#### Privacy Descriptions in Info.plist (Verified)
All required privacy descriptions already present from Phase 1:
- `NSMicrophoneUsageDescription` ✅
- `NSSpeechRecognitionUsageDescription` ✅
- `NSScreenCaptureDescription` ✅

#### Next Steps for Onboarding Polish
1. **Testing:**
   - Test first launch flow on clean macOS install
   - Verify System Settings URL opens correct privacy pane
   - Test permission state refresh after granting in Settings
   
2. **Edge Cases:**
   - Handle user clicking "Don't Allow" on microphone/speech prompts (show explanation)
   - Handle restricted permissions (parental controls, MDM profiles)
   
3. **Future Enhancements:**
   - Preferences → "Reset Onboarding" button for debugging
   - In-app permission status indicators in Preferences
   - Deep link from Preferences to specific System Settings panes

---


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

## Phase 8 Summary (2026-02-20)

**Agents:** Neo agent-21 (ProjectStore), Neo agent-29 (Onboarding)

**Deliverables Completed:**
1. ProjectStore architecture with Observable state management
2. Project model with Codable JSON persistence
3. OnboardingCoordinator for multi-step permission flow
4. Decision document: Onboarding Permission Flow Design
5. Orchestration logs: 2 Neo agents documented

**Key Technical Decisions:**
- ProjectStore as single source of truth for project data
- Versioned .demoproject file format for forward compatibility
- Mandatory screen recording permission (onboarding enforces)
- System Settings redirect pattern for screen recording permission
- UserDefaults flag for first-launch detection
- Re-show onboarding if screen recording permission revoked

**Coordination with Morpheus:**
- PreferencesWindow (agent-22) integrated with ProjectStore
- Recent recordings wiring (agent-26) uses ProjectStore for project list
- Onboarding wiring (agent-30) completes AppDelegate integration

