import Foundation
import AppKit
import Carbon

/// Actions that can be triggered by global hotkeys
enum HotkeyAction: String, CaseIterable {
    case startStopRecording
    
    var defaultKeyCode: UInt16 {
        switch self {
        case .startStopRecording: return UInt16(kVK_ANSI_R)
        }
    }
    
    var defaultModifiers: NSEvent.ModifierFlags {
        [.command, .shift]
    }
    
    var description: String {
        switch self {
        case .startStopRecording: return "Start/Stop Recording"
        }
    }
}

/// Protocol for hotkey registration abstraction
/// Allows swapping implementations (NSEvent global monitor vs KeyboardShortcuts SPM)
@MainActor
protocol HotkeyRegistrar {
    func register(action: HotkeyAction, handler: @escaping () -> Void) throws
    func unregister(action: HotkeyAction)
    func unregisterAll()
}

/// NSEvent-based global hotkey implementation
/// Fallback implementation using NSEvent.addGlobalMonitorForEvents
/// Note: Requires Accessibility permissions on macOS 10.15+
@MainActor
final class NSEventHotkeyRegistrar: HotkeyRegistrar {
    enum RegistrationError: LocalizedError {
        case alreadyRegistered
        case monitorCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .alreadyRegistered: return "Hotkey already registered for this action"
            case .monitorCreationFailed: return "Failed to create global event monitor"
            }
        }
    }
    
    private var monitors: [HotkeyAction: Any] = [:]
    private var handlers: [HotkeyAction: () -> Void] = [:]
    
    func register(action: HotkeyAction, handler: @escaping () -> Void) throws {
        guard monitors[action] == nil else {
            throw RegistrationError.alreadyRegistered
        }
        
        let keyCode = action.defaultKeyCode
        let modifiers = action.defaultModifiers
        
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == keyCode,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers else {
                return
            }
            
            Task { @MainActor in
                handler()
            }
        }
        
        guard let monitor = monitor else {
            throw RegistrationError.monitorCreationFailed
        }
        
        monitors[action] = monitor
        handlers[action] = handler
    }
    
    func unregister(action: HotkeyAction) {
        if let monitor = monitors[action] {
            NSEvent.removeMonitor(monitor)
            monitors.removeValue(forKey: action)
            handlers.removeValue(forKey: action)
        }
    }
    
    func unregisterAll() {
        for (action, monitor) in monitors {
            NSEvent.removeMonitor(monitor)
            handlers.removeValue(forKey: action)
        }
        monitors.removeAll()
    }
    
    deinit {
        // Note: Monitors are automatically cleaned up when the object is deallocated
        // Manual cleanup is not required for NSEvent monitors
    }
}

/// Hotkey configuration and management
/// Provides a clean API for registering/unregistering global hotkeys
/// Abstracted to allow future migration to KeyboardShortcuts SPM when Swift 6.2 macro support is stable
@MainActor
@Observable
final class HotkeyConfiguration {
    private let registrar: HotkeyRegistrar
    private(set) var registeredActions: Set<HotkeyAction> = []
    
    /// Initialize with a specific registrar implementation
    /// Defaults to NSEventHotkeyRegistrar
    init(registrar: HotkeyRegistrar = NSEventHotkeyRegistrar()) {
        self.registrar = registrar
    }
    
    /// Register a hotkey handler for a specific action
    /// - Parameters:
    ///   - action: The action to register
    ///   - handler: The closure to execute when the hotkey is pressed
    /// - Throws: Registration errors if hotkey is already registered or system monitor creation fails
    func register(action: HotkeyAction, handler: @escaping () -> Void) throws {
        try registrar.register(action: action, handler: handler)
        registeredActions.insert(action)
    }
    
    /// Unregister a specific hotkey action
    /// - Parameter action: The action to unregister
    func unregister(action: HotkeyAction) {
        registrar.unregister(action: action)
        registeredActions.remove(action)
    }
    
    /// Unregister all hotkeys
    /// Called during cleanup or app termination
    func unregisterAll() {
        registrar.unregisterAll()
        registeredActions.removeAll()
    }
    
    /// Check if a specific action is currently registered
    /// - Parameter action: The action to check
    /// - Returns: True if the action is registered
    func isRegistered(action: HotkeyAction) -> Bool {
        registeredActions.contains(action)
    }
}


