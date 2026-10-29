import Foundation
import Observation
import ServiceManagement

@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var removeFillers: Bool {
        didSet { defaults.set(removeFillers, forKey: "removeFillers") }
    }

    var smartFormatting: Bool {
        didSet { defaults.set(smartFormatting, forKey: "smartFormatting") }
    }

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
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
