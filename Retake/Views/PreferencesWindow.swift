import SwiftUI
import AppKit
import AVFoundation
import Carbon

/// Comprehensive preferences window with hotkey customization, capture settings, recording behavior, and export defaults
struct PreferencesWindow: View {
    @AppStorage("audioFeedback") private var audioFeedback: Bool = true
    @AppStorage("defaultResolution") private var defaultResolution: CaptureResolution = .native
    @AppStorage("defaultFrameRate") private var defaultFrameRate: FrameRate = .fps60
    @AppStorage("systemAudioEnabled") private var systemAudioEnabled: Bool = true
    @AppStorage("microphoneEnabled") private var microphoneEnabled: Bool = false
    @AppStorage("saveLocation") private var saveLocation: String = ""
    @AppStorage("exportFormat") private var exportFormat: ExportFormat = .mp4
    @AppStorage("exportQuality") private var exportQuality: ExportQuality = .high
    @State private var selectedTab: PreferenceTab = .hotkeys
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HotkeyPreferencesView()
                .tabItem {
                    Label("Hotkeys", systemImage: "keyboard")
                }
                .tag(PreferenceTab.hotkeys)
            
            CapturePreferencesView(
                defaultResolution: $defaultResolution,
                defaultFrameRate: $defaultFrameRate,
                systemAudioEnabled: $systemAudioEnabled,
                microphoneEnabled: $microphoneEnabled,
                saveLocation: $saveLocation
            )
            .tabItem {
                Label("Capture", systemImage: "video")
            }
            .tag(PreferenceTab.capture)
            
            BehaviorPreferencesView(
                audioFeedback: $audioFeedback
            )
            .tabItem {
                Label("Behavior", systemImage: "gearshape")
            }
            .tag(PreferenceTab.behavior)
            
            ExportPreferencesView(
                exportFormat: $exportFormat,
                exportQuality: $exportQuality
            )
            .tabItem {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .tag(PreferenceTab.export)
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Preference Tabs

enum PreferenceTab {
    case hotkeys
    case capture
    case behavior
    case export
}

// MARK: - Section 1: Hotkey Customization

struct HotkeyPreferencesView: View {
    @AppStorage("hotkey.startStopRecording") private var startStopHotkey: String = "⌘⇧R"
    
    @State private var recordingAction: HotkeyAction?
    @State private var conflictMessage: String?
    
    var body: some View {
        Form {
            Section {
                Text("Customize global keyboard shortcuts for recording actions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Recording Controls") {
                HotkeyRow(
                    title: "Start/Stop Recording",
                    description: "Begin or end a screen recording",
                    shortcut: $startStopHotkey,
                    isRecording: recordingAction == .startStopRecording,
                    onRecord: { recordingAction = .startStopRecording }
                )
            }
            
            if let conflict = conflictMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(conflict)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            Section {
                Button("Reset to Defaults") {
                    resetHotkeysToDefaults()
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func resetHotkeysToDefaults() {
        startStopHotkey = "⌘⇧R"
        conflictMessage = nil
    }
}

struct HotkeyRow: View {
    let title: String
    let description: String
    @Binding var shortcut: String
    let isRecording: Bool
    let onRecord: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(isRecording ? "Recording..." : shortcut) {
                onRecord()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .frame(minWidth: 80)
        }
    }
}

// MARK: - Section 2: Default Capture Settings

struct CapturePreferencesView: View {
    @Binding var defaultResolution: CaptureResolution
    @Binding var defaultFrameRate: FrameRate
    @Binding var systemAudioEnabled: Bool
    @Binding var microphoneEnabled: Bool
    @Binding var saveLocation: String
    
    private var displayPath: String {
        if saveLocation.isEmpty {
            return RecordingEngine.defaultSaveDirectory.path(percentEncoded: false)
        }
        return saveLocation
    }
    
    var body: some View {
        Form {
            Section {
                Text("Configure default settings for new recordings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Save Location") {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(displayPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        chooseFolder()
                    }
                }
                
                if !saveLocation.isEmpty {
                    Button("Reset to Default") {
                        saveLocation = ""
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                
                Text("Recordings will be saved to this folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Video Quality") {
                Picker("Resolution", selection: $defaultResolution) {
                    ForEach(CaptureResolution.allCases, id: \.self) { resolution in
                        Text(resolution.displayName).tag(resolution)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Frame Rate", selection: $defaultFrameRate) {
                    ForEach(FrameRate.allCases, id: \.self) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Higher settings produce better quality but larger file sizes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Audio Sources") {
                Toggle("System Audio", isOn: $systemAudioEnabled)
                    .toggleStyle(.switch)
                
                Toggle("Microphone", isOn: $microphoneEnabled)
                    .toggleStyle(.switch)
                
                Text("Enable audio sources to include in recordings by default")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose where to save recordings"
        
        if panel.runModal() == .OK, let url = panel.url {
            saveLocation = url.path(percentEncoded: false)
        }
    }
}

enum CaptureResolution: String, CaseIterable, Codable {
    case p1080 = "1080p"
    case p1440 = "1440p"
    case p4k = "4K"
    case native = "Native"
    
    var displayName: String {
        switch self {
        case .p1080: return "1080p"
        case .p1440: return "1440p"
        case .p4k: return "4K (2160p)"
        case .native: return "Native"
        }
    }
    
    var dimensions: (width: Int, height: Int)? {
        switch self {
        case .p1080: return (1920, 1080)
        case .p1440: return (2560, 1440)
        case .p4k: return (3840, 2160)
        case .native: return nil
        }
    }
}

enum FrameRate: String, CaseIterable, Codable {
    case fps30 = "30"
    case fps60 = "60"
    
    var displayName: String {
        switch self {
        case .fps30: return "30 fps"
        case .fps60: return "60 fps"
        }
    }
    
    var value: Int {
        switch self {
        case .fps30: return 30
        case .fps60: return 60
        }
    }
}

// MARK: - Section 3: Recording Behavior

struct BehaviorPreferencesView: View {
    @Binding var audioFeedback: Bool
    
    var body: some View {
        Form {
            Section {
                Text("Customize how recordings behave and what features are enabled")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Feedback") {
                Toggle("Audio Feedback", isOn: $audioFeedback)
                    .toggleStyle(.switch)
                
                Text("Play sound effects for recording events (start, stop, redo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Section 4: Export Defaults

struct ExportPreferencesView: View {
    @Binding var exportFormat: ExportFormat
    @Binding var exportQuality: ExportQuality
    
    var body: some View {
        Form {
            Section {
                Text("Configure default settings for exporting and sharing recordings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("File Format") {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        HStack {
                            Text(format.displayName)
                            Text(format.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            Section("Quality Preset") {
                Picker("Quality", selection: $exportQuality) {
                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                        VStack(alignment: .leading) {
                            Text(quality.displayName)
                            Text(quality.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(quality)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum ExportFormat: String, CaseIterable, Codable {
    case mp4 = "mp4"
    case mov = "mov"
    
    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "MOV"
        }
    }
    
    var description: String {
        switch self {
        case .mp4: return "H.264, widely compatible"
        case .mov: return "ProRes, high quality"
        }
    }
    
    var fileExtension: String { rawValue }
    
    var avFileType: AVFileType {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        }
    }
    
    static var current: ExportFormat {
        let raw = UserDefaults.standard.string(forKey: "exportFormat") ?? "mp4"
        return ExportFormat(rawValue: raw) ?? .mp4
    }
}

enum ExportQuality: String, CaseIterable, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var description: String {
        switch self {
        case .high: return "Best quality, larger files"
        case .medium: return "Balanced quality and size"
        case .low: return "Smaller files, reduced quality"
        }
    }
    
    var bitrate: Int {
        switch self {
        case .high: return 20_000_000
        case .medium: return 10_000_000
        case .low: return 5_000_000
        }
    }
}



