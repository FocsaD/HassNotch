import AppKit
import Darwin

/// Trackpad haptic feedback.
/// 1. Directly on each trackpad's haptic engine (MultitouchSupport, like Alcove / HapticKey):
///    works on an external Magic Trackpad too, not only on the MacBook's built-in trackpad.
/// 2. If that isn't available, Apple's standard API (NSHapticFeedbackManager).
enum Haptics {
    private typealias CreateList = @convention(c) () -> Unmanaged<CFArray>?
    private typealias GetDeviceID = @convention(c) (UnsafeRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias ActuatorCreate = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias ActuatorOpen = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias Actuate = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32

    private struct API {
        let createList: CreateList
        let getDeviceID: GetDeviceID
        let actuatorCreate: ActuatorCreate
        let actuatorOpen: ActuatorOpen
        let actuate: Actuate
    }

    private static let api: API? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let a = dlsym(handle, "MTDeviceCreateList"),
              let b = dlsym(handle, "MTDeviceGetDeviceID"),
              let c = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let d = dlsym(handle, "MTActuatorOpen"),
              let e = dlsym(handle, "MTActuatorActuate") else { return nil }
        return API(createList: unsafeBitCast(a, to: CreateList.self),
                   getDeviceID: unsafeBitCast(b, to: GetDeviceID.self),
                   actuatorCreate: unsafeBitCast(c, to: ActuatorCreate.self),
                   actuatorOpen: unsafeBitCast(d, to: ActuatorOpen.self),
                   actuate: unsafeBitCast(e, to: Actuate.self))
    }()

    /// Open actuators by device ID (they stay open while the app runs).
    private static var actuators: [UInt64: UnsafeMutableRawPointer] = [:]

    /// One haptic tap on every connected Force Touch trackpad, at the strength chosen in Settings.
    /// The actuation IDs have different strengths; "very strong" plays several pulses.
    static func tap() {
        let pulses: [Int32]
        switch NotchSettings.shared.hapticStrength {
        case 0: pulses = [3]
        case 1: pulses = [6]
        case 2: pulses = [16]
        default: pulses = [16, 15, 16]
        }
        guard tapAllTrackpads(pulses[0]) || tapAllTrackpads(6) else {
            NSHapticFeedbackManager.defaultPerformer.perform(
                NotchSettings.shared.hapticStrength >= 2 ? .levelChange : .alignment, performanceTime: .now)
            return
        }
        for (index, pulse) in pulses.enumerated().dropFirst() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.07 * Double(index)) {
                _ = tapAllTrackpads(pulse) || tapAllTrackpads(6)
            }
        }
    }

    private static func tapAllTrackpads(_ actuationID: Int32) -> Bool {
        guard let api, let list = api.createList()?.takeRetainedValue() else { return false }
        var success = false
        for index in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            var deviceID: UInt64 = 0
            guard api.getDeviceID(device, &deviceID) == 0, deviceID != 0 else { continue }
            if actuators[deviceID] == nil,
               let actuator = api.actuatorCreate(deviceID),
               api.actuatorOpen(actuator) == 0 {
                actuators[deviceID] = actuator
            }
            guard let actuator = actuators[deviceID] else { continue }
            if api.actuate(actuator, actuationID, 0, 0, 0) == 0 {
                success = true
            } else {
                // The trackpad was disconnected in the meantime: reopen it next time.
                actuators[deviceID] = nil
            }
        }
        return success
    }
}
