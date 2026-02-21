import SwiftUI
import AVFoundation
import ScreenCaptureKit

/// Multi-step onboarding flow for first-launch permission requests
/// Guides users through Screen Recording, Microphone, and Speech Recognition permissions
@MainActor
@Observable
final class OnboardingCoordinator {
    /// Current onboarding step
    enum Step: Int, CaseIterable {
        case welcome = 0
        case screenRecording
        case microphone
        case complete
        
        var title: String {
            switch self {
            case .welcome: return "Welcome to Retake"
            case .screenRecording: return "Screen Recording"
            case .microphone: return "Microphone Access"
            case .complete: return "All Set!"
            }
        }
    }
    
    /// Current step in the onboarding flow
    private(set) var currentStep: Step = .welcome
    
    /// Permission states
    private(set) var screenRecordingGranted = false
    private(set) var microphoneGranted = false
    
    /// Whether onboarding can be dismissed (after all critical permissions granted)
    var canDismiss: Bool {
        screenRecordingGranted
    }
    
    /// Whether to show the onboarding window
    /// Checks UserDefaults flag and current permission states
    static func shouldShowOnboarding() async -> Bool {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Always show if never completed
        guard hasCompleted else { return true }
        
        // If completed but screen recording permission lost, show again
        // This handles users who revoked permissions after onboarding
        return await !checkScreenRecordingPermission()
    }
    
    /// Mark onboarding as completed in UserDefaults
    func markCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    /// Reset onboarding state (for testing or when permissions revoked)
    static func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Navigation
    
    func goToNextStep() {
        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else {
            return
        }
        currentStep = nextStep
    }
    
    func goToPreviousStep() {
        guard currentStep.rawValue > 0,
              let previousStep = Step(rawValue: currentStep.rawValue - 1) else {
            return
        }
        currentStep = previousStep
    }
    
    // MARK: - Permission Checking
    
    func refreshPermissionStates() async {
        screenRecordingGranted = await Self.checkScreenRecordingPermission()
        microphoneGranted = Self.checkMicrophonePermission()
    }
    
    /// Check screen recording permission state
    /// Uses ScreenCaptureKit's canRecord property on shareable content
    static func checkScreenRecordingPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            return true
        } catch {
            return false
        }
    }
    
    /// Check microphone permission state
    static func checkMicrophonePermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        return status == .authorized
    }
    
    // MARK: - Permission Requests
    
    /// Request screen recording permission
    /// Opens System Settings to Screen Recording privacy pane
    func requestScreenRecordingPermission() {
        // Screen recording permission must be granted via System Settings
        // There's no programmatic request API - we must direct users to settings
        openSystemSettingsScreenRecording()
    }
    
    /// Request microphone permission
    func requestMicrophonePermission() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            microphoneGranted = granted
        }
    }
    
    /// Open System Settings to Screen Recording privacy pane
    func openSystemSettingsScreenRecording() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Onboarding Window View

struct OnboardingWindow: View {
    @Bindable var coordinator: OnboardingCoordinator
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressView(value: Double(coordinator.currentStep.rawValue), total: Double(OnboardingCoordinator.Step.allCases.count - 1))
                .progressViewStyle(.linear)
                .padding(.horizontal, 32)
                .padding(.top, 20)
            
            // Content area
            ZStack {
                Group {
                    switch coordinator.currentStep {
                    case .welcome:
                        WelcomeStep()
                    case .screenRecording:
                        ScreenRecordingStep(coordinator: coordinator)
                    case .microphone:
                        MicrophoneStep(coordinator: coordinator)
                    case .complete:
                        CompleteStep()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(32)
            }
            .frame(height: 400)
            
            Divider()
            
            // Navigation buttons
            HStack {
                if coordinator.currentStep != .welcome {
                    Button("Back") {
                        coordinator.goToPreviousStep()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                
                Spacer()
                
                if coordinator.currentStep == .complete {
                    Button("Get Started") {
                        coordinator.markCompleted()
                        onDismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(coordinator.currentStep == .screenRecording && !coordinator.screenRecordingGranted ? "I've Enabled Permission" : "Continue") {
                        if coordinator.currentStep == .screenRecording {
                            Task {
                                await coordinator.refreshPermissionStates()
                                if coordinator.screenRecordingGranted {
                                    coordinator.goToNextStep()
                                }
                            }
                        } else {
                            coordinator.goToNextStep()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
        }
        .frame(width: 600, height: 550)
        .task {
            await coordinator.refreshPermissionStates()
        }
    }
}

// MARK: - Step Views

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)
            
            Text("Welcome to Retake")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Record your screen with live redo and post-production polish")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "arrow.uturn.backward", title: "Live Redo", description: "Punch in and re-record any section on the fly")
                FeatureRow(icon: "eye.slash", title: "Redaction", description: "Blur or black out sensitive areas before saving")
                FeatureRow(icon: "scissors", title: "Trim & Pause", description: "Pause mid-recording and trim the final video")
            }
            .padding(.top, 8)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct ScreenRecordingStep: View {
    @Bindable var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: coordinator.screenRecordingGranted ? "checkmark.circle.fill" : "display")
                .font(.system(size: 72))
                .foregroundStyle(coordinator.screenRecordingGranted ? .green : .blue)
            
            Text("Screen Recording Permission")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if coordinator.screenRecordingGranted {
                Text("Screen recording permission is enabled ✓")
                    .font(.title3)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
            } else {
                Text("Retake needs permission to capture your screen")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    InstructionStep(number: 1, text: "Click \"Open System Settings\" below")
                    InstructionStep(number: 2, text: "Find Retake in the list")
                    InstructionStep(number: 3, text: "Toggle the switch to enable screen recording")
                    InstructionStep(number: 4, text: "Return here and click \"I've Enabled Permission\"")
                }
                .padding(.top, 8)
                
                Button(action: {
                    coordinator.requestScreenRecordingPermission()
                }) {
                    Label("Open System Settings", systemImage: "gear")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }
}

struct MicrophoneStep: View {
    @Bindable var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: coordinator.microphoneGranted ? "checkmark.circle.fill" : "mic.fill")
                .font(.system(size: 72))
                .foregroundStyle(coordinator.microphoneGranted ? .green : .blue)
            
            Text("Microphone Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if coordinator.microphoneGranted {
                Text("Microphone access is enabled ✓")
                    .font(.title3)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                
                Text("You can now record audio commentary with your screen recordings")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Record audio commentary alongside your screen captures")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("This is optional. You can skip this step if you only need screen recording.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                
                HStack(spacing: 16) {
                    Button("Skip") {
                        coordinator.goToNextStep()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: {
                        Task {
                            await coordinator.requestMicrophonePermission()
                        }
                    }) {
                        Label("Enable Microphone", systemImage: "mic.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }
}

struct CompleteStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            
            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Retake is ready to capture your screen")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                TipRow(icon: "command", title: "Press ⇧⌘R to start a new recording")
                TipRow(icon: "arrow.uturn.backward", title: "Use the Redo button to re-record a section")
                TipRow(icon: "gearshape", title: "Access settings from the menu bar icon")
            }
            .padding(.top, 8)
            
            Text("The Retake icon will appear in your menu bar")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
}

struct InstructionStep: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.blue))
            
            Text(text)
                .font(.body)
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
                .foregroundStyle(.blue)
            Text(text)
                .font(.body)
        }
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
        }
    }
}
