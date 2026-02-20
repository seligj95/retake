# Morpheus's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 - MenuBarExtra App Structure
**Created:**
- `DemoRecorder/DemoRecorderApp.swift` - Main app entry point with MenuBarExtra scene
- `DemoRecorder/Info.plist` - Bundle configuration with LSUIElement=true (menu bar only)
- `DemoRecorder/DemoRecorder.entitlements` - Sandbox entitlements for screen recording, microphone, camera, file access
- `Package.swift` - Swift Package Manager configuration

**Architecture Decisions:**
- MenuBarExtra with `.menu` style for dropdown UI
- Menu items: "New Recording" (⇧⌘R), "Open Recent", "Preferences" (⌘,), "Quit" (⌘Q)
- NSApplicationDelegate adapter for lifecycle management
- System SF Symbol "record.circle" for menu bar icon

**KeyboardShortcuts Dependency Issue:**
- Dependency has Swift 6.2 macro compatibility issues (#Preview macros failing)
- Temporarily commented out in Package.swift
- TODO: Re-enable when building with Xcode (which includes macro plugins) or when dependency updates
- Current keyboard shortcuts use SwiftUI's built-in `.keyboardShortcut()` modifier

**File Paths:**
- App source: `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/`
- Main entry: `DemoRecorderApp.swift`
- Config files: `Info.plist`, `DemoRecorder.entitlements`

**Build Status:**
- ✅ Builds successfully without KeyboardShortcuts dependency
- ✅ Creates macOS 15+ executable
- ✅ Menu bar UI structure complete

### 2025-01-25: Phase 1 Required Changes - Xcode Project Structure
**Completed Neo's 3 Required Changes:**
1. ✅ **Added Xcode project** (`DemoRecorder.xcodeproj/project.pbxproj`)
   - Created proper Xcode project structure with native build targets
   - Configured macOS 15.0+ deployment target
   - Enabled sandbox, hardened runtime, code signing
   - Integrated existing Info.plist and entitlements files
   - Two targets: DemoRecorder (app) and DemoRecorderTests (unit tests)

2. ✅ **Added Assets.xcassets** catalog
   - Created `DemoRecorder/Assets.xcassets/` with proper structure
   - `AppIcon.appiconset/` - App icon placeholder (standard macOS sizes)
   - `AccentColor.colorset/` - Accent color configuration
   - Menu bar icon uses SF Symbol `record.circle` (referenced in DemoRecorderApp.swift)

3. ✅ **Added DemoRecorderTests target**
   - Created `DemoRecorderTests/DemoRecorderTests.swift` with basic XCTest structure
   - Configured as unit test bundle targeting DemoRecorder.app
   - Placeholder test included for framework validation

**Architecture Notes:**
- Replaced standalone `Package.swift` approach with proper `.xcodeproj` (required for sandboxing & code signing)
- `Package.swift` remains for reference but build now uses Xcode project system
- Privacy descriptions (NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription) configured in pbxproj
- LSUIElement=YES enforced through Info.plist keys in build settings

**File Paths Added:**
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder.xcodeproj/project.pbxproj`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorder/Assets.xcassets/`
- `/Users/jordanselig/workspace/demo-recorder/DemoRecorderTests/DemoRecorderTests.swift`

**Phase 1 Status:** ✅ Complete - All 3 required changes implemented, ready for Neo's approval

### 2026-02-20: Phase 1 Architecture Review Finalized
**Status:** ✅ APPROVED & COMPLETED

Neo approved Phase 1 with all 3 required changes successfully implemented:
1. ✅ Xcode project created with native targets (DemoRecorder app + DemoRecorderTests)
   - Manual pbxproj generation using Python UUID generation
   - Format version 77 (modern Xcode format)
   - Hardened runtime + sandbox enabled
   - Swift 6.0 language version, macOS 15.0+ deployment target

2. ✅ Assets.xcassets catalog added
   - AppIcon.appiconset with macOS standard sizes (16-512 @1x/@2x)
   - AccentColor.colorset for UI theming
   - Menu bar icon uses SF Symbol `record.circle` (referenced in DemoRecorderApp.swift)

3. ✅ DemoRecorderTests target created
   - Unit test bundle configuration
   - TEST_HOST points to DemoRecorder.app
   - Placeholder XCTestCase for framework validation

Phase 1 scaffold production-ready. Xcode build system now primary (Package.swift retained for future modular library targets).

**Known issues addressed:**
- KeyboardShortcuts Swift 6.2 macro compatibility: using SwiftUI's .keyboardShortcut() modifier as workaround
- Can re-enable dependency when building in full Xcode app (includes macro plugins)

**Phase 2 prep:** Sandbox + ScreenCaptureKit validation spike scheduled for day 1 (identified as highest technical risk).
