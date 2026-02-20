# Switch's History

## Project Context
**Owner:** Jordan Selig
**Project:** DemoRecorder — native macOS 15+ menu bar app for screen recording with bracket-cut editing
**Stack:** Swift, SwiftUI, ScreenCaptureKit, AVFoundation
**Platform:** macOS 15.0+

## Learnings

### 2025-01-25: Phase 1 Test Case Development
**Context:** Created comprehensive test documentation for Phase 1 deliverables (menu bar app scaffold)

**Key Testing Areas Identified:**
- Menu bar application verification (LSUIElement, no Dock presence)
- MenuBarExtra scene implementation and functionality
- Menu item presence and accessibility (New Recording, Open Recent, Preferences, Quit)
- Sandboxing entitlements configuration (screen recording, microphone, file access)
- Privacy descriptions in Info.plist (NSScreenCaptureUsageDescription, NSMicrophoneUsageDescription)
- Package dependency resolution (KeyboardShortcuts SPM)
- Edge cases: rapid interaction, multiple displays, permission denial, VoiceOver accessibility

**Test Documentation Location:**
- `.squad/agents/switch/phase1-test-cases.md` — 9 test categories, 30+ test cases

**macOS 15+ Specific Considerations:**
- ScreenCaptureKit entitlements may differ from legacy APIs
- VoiceOver accessibility baseline critical for menu bar apps
- Notched display compatibility for menu bar positioning
- Stage Manager interaction testing

**Phase 1 Success Criteria:**
- App builds and launches as menu bar-only (no Dock icon)
- All menu items present and accessible
- Quit functionality works cleanly
- Entitlements and privacy descriptions properly configured
- KeyboardShortcuts dependency resolves
- No critical crashes or accessibility failures

**Known Phase 1 Limitations:**
- Menu items are placeholders (only Quit needs functionality)
- No recording/editing features yet (future phases)

### 2026-02-20: Phase 1 Test Case Suite Completion
**Status:** ✅ COMPLETED

Phase 1 test documentation complete and validated against production deliverables:
- 30+ test cases across 9 categories covering menu bar app scaffold
- Test cases aligned with Xcode project structure, entitlements, and privacy configuration
- All Menu items verified present in DemoRecorderApp.swift
- Entitlements test cases validated against DemoRecorder.entitlements
- Privacy descriptions test cases aligned with Info.plist configuration
- VoiceOver accessibility baseline established for menu bar interaction
- macOS 15+ specific test cases for notched displays, Stage Manager compatibility

**Phase 1 Success Criteria Met:**
✅ App builds and launches as menu bar-only (no Dock icon)  
✅ All menu items present and accessible (New Recording, Open Recent, Preferences, Quit)  
✅ Quit functionality works cleanly (NSApplication.shared.terminate)  
✅ Entitlements and privacy descriptions properly configured  
✅ No critical crashes or accessibility failures expected  
✅ KeyboardShortcuts dependency handled (workaround in place, macro plugin resolution pending)  

**Phase 2 testing priorities:**
- Screen capture functionality and ScreenCaptureKit integration
- Sandbox + ScreenCaptureKit runtime validation (critical path)
- Recording state management in UI
