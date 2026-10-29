import CheersCore
import Foundation
import Observation
import ServiceManagement

@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var removeFillers: Bool {
        didSet { defaults.set(removeFillers, forKey: "removeFillers") }
    }

    var smartCleanup: Bool {
        didSet { defaults.set(smartCleanup, forKey: "smartCleanup") }
    }

    var smartFormatting: Bool {
        didSet { defaults.set(smartFormatting, forKey: "smartFormatting") }
    }

    var preferredMicrophoneUID: String? {
        didSet { defaults.set(preferredMicrophoneUID, forKey: "preferredMicrophoneUID") }
    }

    var preferredMicrophoneName: String? {
        didSet { defaults.set(preferredMicrophoneName, forKey: "preferredMicrophoneName") }
    }

    var alternateTrigger: TriggerKey? {
        didSet {
            defaults.set(alternateTrigger.map { Int($0.keyCode) }, forKey: "alternateTriggerKeyCode")
            onTriggersChanged?(triggers)
        }
    }

    var triggers: Set<TriggerKey> {
        Set([.function, alternateTrigger].compactMap(\.self))
    }

    var triggerDescription: String {
        alternateTrigger.map { "fn or \($0.displayName)" } ?? "fn"
    }

    @ObservationIgnored var onTriggersChanged: ((Set<TriggerKey>) -> Void)?

    var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    init() {
        removeFillers = defaults.object(forKey: "removeFillers") as? Bool ?? true
        smartFormatting = defaults.object(forKey: "smartFormatting") as? Bool ?? true
        smartCleanup = defaults.object(forKey: "smartCleanup") as? Bool ?? true
        preferredMicrophoneUID = defaults.string(forKey: "preferredMicrophoneUID")
        preferredMicrophoneName = defaults.string(forKey: "preferredMicrophoneName")
        alternateTrigger = (defaults.object(forKey: "alternateTriggerKeyCode") as? Int)
            .flatMap { TriggerKey(keyCode: UInt16($0)) }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
