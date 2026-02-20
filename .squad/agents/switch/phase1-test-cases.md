# Phase 1 Test Cases — DemoRecorder

**Version:** 1.0  
**Date:** 2025-01-25  
**Target:** macOS 15.0+  
**Scope:** Menu bar app scaffold, entitlements, dependencies

---

## Test Categories

### 1. Menu Bar Application Verification

#### TC-MB-001: LSUIElement Configuration
**Objective:** Verify app does not appear in Dock  
**Prerequisites:** App built and launched  
**Steps:**
1. Build the DemoRecorder app
2. Launch the application
3. Observe the macOS Dock
4. Check System Settings > General > Login Items & Extensions

**Expected:**
- App does NOT appear in Dock
- App does NOT appear in Cmd+Tab switcher
- Info.plist contains `<key>LSUIElement</key><true/>`
- App icon visible in menu bar (top-right system tray)

**Edge Cases:**
- Verify behavior persists after app restart
- Test with Dock magnification enabled
- Test with multiple displays

---

#### TC-MB-002: Menu Bar Icon Presence
**Objective:** Verify menu bar icon appears and is clickable  
**Prerequisites:** App launched  
**Steps:**
1. Launch DemoRecorder
2. Locate app icon in menu bar (system tray)
3. Click the menu bar icon

**Expected:**
- Icon visible in menu bar on all displays
- Icon shows visual feedback on hover (if applicable)
- Clicking icon reveals dropdown menu
- Menu appears below icon, properly positioned

**Edge Cases:**
- Test with menu bar set to auto-hide
- Test with dense menu bar (many icons)
- Test on notched MacBook displays
- Test with Stage Manager enabled

---

### 2. MenuBarExtra Scene Functionality

#### TC-MBE-001: MenuBarExtra Scene Implementation
**Objective:** Verify MenuBarExtra scene is properly configured  
**Prerequisites:** Source code access  
**Steps:**
1. Open `DemoRecorderApp.swift`
2. Verify `MenuBarExtra` scene exists in app body
3. Build and run application

**Expected:**
- SwiftUI `MenuBarExtra` scene present in `@main` App struct
- Scene has proper identifier/label
- No compilation errors
- App launches successfully with menu bar presence

---

#### TC-MBE-002: Menu Dropdown Display
**Objective:** Verify menu dropdown appears on interaction  
**Prerequisites:** App running  
**Steps:**
1. Click menu bar icon
2. Observe dropdown menu appearance
3. Click outside menu to dismiss
4. Click icon again to reopen

**Expected:**
- Menu appears immediately on click
- Menu positioned correctly below icon
- Menu dismisses when clicking outside
- Menu can be reopened after dismissal
- No visual glitches or rendering issues

**Edge Cases:**
- Test rapid open/close cycles
- Test with VoiceOver enabled
- Test keyboard navigation (if supported)

---

### 3. Menu Items Verification

#### TC-MI-001: Menu Item Presence
**Objective:** Verify all required menu items exist  
**Prerequisites:** App running, menu open  
**Steps:**
1. Click menu bar icon to open menu
2. Visually inspect menu items
3. Document menu item order

**Expected Items (in order):**
1. "New Recording"
2. "Open Recent"
3. "Preferences"
4. "Quit"

**Expected:**
- All four menu items present
- Items appear in specified order
- No duplicate items
- Proper spacing/separators (if designed)

---

#### TC-MI-002: Menu Item Accessibility
**Objective:** Verify menu items are interactive  
**Prerequisites:** App running  
**Steps:**
1. Open menu dropdown
2. Hover over each menu item
3. Attempt to click each item
4. Observe visual feedback

**Expected:**
- All items show hover state
- All items are clickable (not disabled)
- Clicking item triggers expected action (even if placeholder)
- No console errors on interaction

**Edge Cases:**
- Test keyboard navigation (arrow keys)
- Test with Reduce Motion enabled
- Test with increased text size accessibility setting

---

#### TC-MI-003: Quit Functionality
**Objective:** Verify "Quit" menu item terminates app  
**Prerequisites:** App running  
**Steps:**
1. Open menu dropdown
2. Click "Quit"
3. Observe app behavior
4. Check Activity Monitor

**Expected:**
- App terminates cleanly
- Menu bar icon disappears
- No zombie processes remain
- No crash reports generated

**Edge Cases:**
- Test quit with pending operations (future)
- Verify cleanup of temporary resources

---

### 4. Sandboxing Entitlements

#### TC-ENT-001: Entitlements File Existence
**Objective:** Verify entitlements file is present and configured  
**Prerequisites:** Source code access  
**Steps:**
1. Locate `DemoRecorder.entitlements` file
2. Verify file is referenced in Xcode project/Package.swift
3. Inspect file contents

**Expected:**
- `DemoRecorder.entitlements` exists
- File properly formatted (XML plist)
- File referenced in build configuration
- Contains required sandboxing keys

---

#### TC-ENT-002: App Sandbox Enabled
**Objective:** Verify app sandboxing is enabled  
**Prerequisites:** Entitlements file exists  
**Steps:**
1. Open `DemoRecorder.entitlements`
2. Search for `com.apple.security.app-sandbox` key

**Expected:**
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```

---

#### TC-ENT-003: Screen Recording Entitlement
**Objective:** Verify screen recording entitlement present  
**Prerequisites:** Entitlements file exists  
**Steps:**
1. Open `DemoRecorder.entitlements`
2. Search for screen recording capability

**Expected:**
```xml
<key>com.apple.security.device.camera</key>
<true/>
```
Or ScreenCaptureKit-specific entitlement if required by macOS 15

**Note:** Verify against macOS 15.0 ScreenCaptureKit requirements

---

#### TC-ENT-004: Microphone Access Entitlement
**Objective:** Verify microphone access entitlement present  
**Prerequisites:** Entitlements file exists  
**Steps:**
1. Open `DemoRecorder.entitlements`
2. Search for audio capture capability

**Expected:**
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

---

#### TC-ENT-005: File Access Entitlements
**Objective:** Verify file system access entitlements  
**Prerequisites:** Entitlements file exists  
**Steps:**
1. Open `DemoRecorder.entitlements`
2. Check for file access permissions

**Expected (at minimum):**
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

**Consider also:**
- `com.apple.security.files.downloads.read-write` for saving recordings
- Temporary file access if needed

---

### 5. Privacy Descriptions

#### TC-PRIV-001: Screen Recording Privacy Description
**Objective:** Verify NSScreenCaptureUsageDescription in Info.plist  
**Prerequisites:** Info.plist exists  
**Steps:**
1. Open `DemoRecorder/Info.plist`
2. Search for `NSScreenCaptureUsageDescription`

**Expected:**
- Key present: `NSScreenCaptureUsageDescription`
- Value: User-friendly description explaining why screen access needed
- Example: "DemoRecorder needs screen access to capture your recordings."

**Validation:**
- Description is clear and non-technical
- Describes specific app benefit

---

#### TC-PRIV-002: Microphone Privacy Description
**Objective:** Verify NSMicrophoneUsageDescription in Info.plist  
**Prerequisites:** Info.plist exists  
**Steps:**
1. Open `DemoRecorder/Info.plist`
2. Search for `NSMicrophoneUsageDescription`

**Expected:**
- Key present: `NSMicrophoneUsageDescription`
- Value: User-friendly description for microphone access
- Example: "DemoRecorder needs microphone access to record audio with your screen recordings."

**Validation:**
- Description explains optional vs required nature (if applicable)
- Clear user benefit stated

---

### 6. Package Dependencies

#### TC-DEP-001: Package.swift Existence
**Objective:** Verify Swift Package Manager configuration  
**Prerequisites:** Source code access  
**Steps:**
1. Locate `Package.swift` in project root
2. Verify file is valid Swift package manifest

**Expected:**
- `Package.swift` exists at project root
- File contains valid Swift package declaration
- Platform minimum set to macOS 15.0+

---

#### TC-DEP-002: KeyboardShortcuts Dependency
**Objective:** Verify KeyboardShortcuts SPM dependency configured  
**Prerequisites:** Package.swift exists  
**Steps:**
1. Open `Package.swift`
2. Search for KeyboardShortcuts dependency
3. Run `swift package resolve`

**Expected:**
```swift
.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
```
(or latest compatible version)

**Dependency linked to target:**
```swift
.target(
    name: "DemoRecorder",
    dependencies: ["KeyboardShortcuts"]
)
```

**Expected:**
- Dependency resolves without errors
- No version conflicts
- Package fetched successfully

---

#### TC-DEP-003: Dependency Resolution
**Objective:** Verify all dependencies resolve and build  
**Prerequisites:** Package.swift configured  
**Steps:**
1. Clean build folder
2. Run `swift package resolve`
3. Build project

**Expected:**
- All dependencies download successfully
- No version conflicts
- Build succeeds
- No deprecation warnings for macOS 15

**Edge Cases:**
- Test with no internet (after initial cache)
- Test dependency resolution time
- Verify reproducible builds

---

### 7. Build and Launch Tests

#### TC-BUILD-001: Clean Build Success
**Objective:** Verify project builds without errors  
**Prerequisites:** All source files present  
**Steps:**
1. Clean build folder (Cmd+Shift+K or `swift package clean`)
2. Build project (Cmd+B or `swift build`)
3. Check build output

**Expected:**
- Build completes successfully
- No compilation errors
- No critical warnings
- Build time reasonable (<30s for clean build)

---

#### TC-BUILD-002: App Launch Success
**Objective:** Verify app launches and runs  
**Prerequisites:** Successful build  
**Steps:**
1. Launch built application
2. Wait for app initialization
3. Check menu bar for icon
4. Check Console.app for errors

**Expected:**
- App launches without crash
- Menu bar icon appears within 2 seconds
- No errors in system console
- App responsive to interaction

**Edge Cases:**
- Test launch with low memory conditions
- Test launch with screen locked
- Test launch on login (future)

---

#### TC-BUILD-003: macOS Version Compatibility
**Objective:** Verify app refuses to launch on unsupported macOS  
**Prerequisites:** Access to macOS <15.0 (if possible)  
**Steps:**
1. Attempt to launch on macOS 14.x or earlier
2. Observe system behavior

**Expected:**
- System prevents launch with clear error message
- Error indicates minimum macOS version required
- No crash or undefined behavior

**Note:** May require virtual machine or separate test device

---

### 8. Edge Cases and Error Conditions

#### TC-EDGE-001: Rapid Menu Interaction
**Objective:** Test menu stability under rapid interaction  
**Prerequisites:** App running  
**Steps:**
1. Rapidly click menu bar icon 20+ times
2. Rapidly open/close menu
3. Hover over menu items rapidly

**Expected:**
- No crashes or hangs
- Menu responds correctly
- No visual glitches
- No memory leaks (check Activity Monitor)

---

#### TC-EDGE-002: Multiple Display Handling
**Objective:** Verify menu bar behavior with multiple displays  
**Prerequisites:** Multiple displays connected  
**Steps:**
1. Launch app with multiple displays
2. Check menu bar on each display
3. Interact with menu on different displays
4. Disconnect/reconnect display while app running

**Expected:**
- Icon visible on primary display menu bar
- Menu appears on correct display when clicked
- App handles display changes gracefully
- No crashes on display reconfiguration

---

#### TC-EDGE-003: Permission Prompts
**Objective:** Verify app handles permission denial gracefully  
**Prerequisites:** Fresh system or reset permissions  
**Steps:**
1. Launch app for first time
2. When screen recording permission prompt appears, deny
3. When microphone permission prompt appears, deny
4. Observe app behavior

**Expected:**
- App continues running despite permission denial
- Clear error message or guidance provided (future functionality)
- No crash or undefined behavior
- Permissions can be granted later in System Settings

**Note:** This tests graceful degradation; full functionality requires permissions

---

#### TC-EDGE-004: Low Memory Conditions
**Objective:** Test app behavior under memory pressure  
**Prerequisites:** Memory pressure testing tools  
**Steps:**
1. Launch app
2. Simulate memory pressure (using Xcode Instruments or similar)
3. Interact with menu
4. Monitor memory usage

**Expected:**
- App remains responsive
- No memory leaks detected
- Graceful handling of memory warnings
- App doesn't consume excessive memory (baseline <50MB)

---

#### TC-EDGE-005: VoiceOver Accessibility
**Objective:** Verify menu bar app works with VoiceOver  
**Prerequisites:** VoiceOver enabled  
**Steps:**
1. Enable VoiceOver (Cmd+F5)
2. Navigate to menu bar
3. Locate DemoRecorder icon
4. Open menu and navigate items

**Expected:**
- VoiceOver announces menu bar icon
- Menu items are readable by VoiceOver
- Keyboard navigation works
- Actions can be triggered via VoiceOver

---

### 9. Code Quality Checks

#### TC-CODE-001: SwiftLint Compliance
**Objective:** Verify code follows Swift style guidelines  
**Prerequisites:** SwiftLint installed (if configured)  
**Steps:**
1. Run SwiftLint on source files
2. Review warnings and errors

**Expected:**
- No critical SwiftLint errors
- Warnings addressed or documented
- Code follows Swift API design guidelines

---

#### TC-CODE-002: Info.plist Validation
**Objective:** Verify Info.plist is well-formed  
**Prerequisites:** Info.plist exists  
**Steps:**
1. Open Info.plist in Xcode or text editor
2. Verify XML structure
3. Check for required keys

**Expected:**
- Valid XML plist format
- `CFBundleIdentifier`: com.demorecorder.app
- `LSUIElement`: true
- `NSScreenCaptureUsageDescription`: present
- `NSMicrophoneUsageDescription`: present
- Minimum macOS version specified (15.0)

---

## Test Execution Checklist

### Pre-Delivery Validation
- [ ] All menu bar tests pass (TC-MB-001 to TC-MB-002)
- [ ] All MenuBarExtra tests pass (TC-MBE-001 to TC-MBE-002)
- [ ] All menu item tests pass (TC-MI-001 to TC-MI-003)
- [ ] All entitlement tests pass (TC-ENT-001 to TC-ENT-005)
- [ ] All privacy description tests pass (TC-PRIV-001 to TC-PRIV-002)
- [ ] All dependency tests pass (TC-DEP-001 to TC-DEP-003)
- [ ] All build tests pass (TC-BUILD-001 to TC-BUILD-003)
- [ ] Critical edge cases tested (TC-EDGE-001, TC-EDGE-003, TC-EDGE-005)
- [ ] Code quality checks pass (TC-CODE-001 to TC-CODE-002)

### Known Limitations (Phase 1)
- Menu items are placeholders (no functional implementation yet)
- "New Recording" will not start recording
- "Open Recent" will not show recent files
- "Preferences" will not open settings
- Only "Quit" needs to be functional

### Testing Notes
- Test on clean macOS 15.0+ installation when possible
- Reset permissions before testing permission flows
- Use Xcode Instruments for memory/performance validation
- Document any deviations from expected behavior
- Take screenshots of permission prompts for documentation

---

## Success Criteria

Phase 1 is considered complete when:

1. ✅ App builds without errors on macOS 15.0+
2. ✅ App launches as menu bar only (no Dock icon)
3. ✅ Menu bar icon appears and is clickable
4. ✅ All four menu items present and accessible
5. ✅ "Quit" menu item terminates app cleanly
6. ✅ Entitlements file contains all required permissions
7. ✅ Privacy descriptions present in Info.plist
8. ✅ KeyboardShortcuts dependency resolves and builds
9. ✅ No crashes or critical errors during basic interaction
10. ✅ VoiceOver can navigate menu (accessibility baseline)

---

## Future Test Considerations (Post-Phase 1)

- Recording functionality tests
- File save/export validation
- Bracket-cut editing workflow
- Keyboard shortcut registration and triggering
- Recent files menu population
- Preferences persistence
- Notification handling
- App updates and versioning
- Performance under continuous recording
- Multi-hour recording stability
- Storage space handling
