import AVFoundation
import AppKit
import ApplicationServices
import Observation

@Observable
final class Permissions {
    private(set) var microphone = AVCaptureDevice.authorizationStatus(for: .audio)
    private(set) var accessibility = AXIsProcessTrusted()

    var allGranted: Bool { microphone == .authorized && accessibility }

    @discardableResult
    func refresh() -> Bool {
        let wasTrusted = accessibility
        microphone = AVCaptureDevice.authorizationStatus(for: .audio)
        accessibility = AXIsProcessTrusted()
        return !wasTrusted && accessibility
    }

    func requestMicrophone() async {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        default:
            break
        }
        refresh()
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }

    func openKeyboardSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    private func open(_ link: String) {
        if let url = URL(string: link) {
            NSWorkspace.shared.open(url)
        }
    }
}

extension AVAuthorizationStatus {
    var isAuthorized: Bool { self == .authorized }
}
