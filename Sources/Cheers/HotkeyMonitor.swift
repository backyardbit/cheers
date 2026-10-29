import AppKit
import CheersCore

final class HotkeyMonitor {
    var onInput: ((HotkeyInput) -> Void)?
    var onCapture: ((TriggerKey?) -> Void)?

    var triggers: Set<TriggerKey> = [.function] {
        didSet { held.formIntersection(triggers) }
    }

    private static let escapeKeyCode: UInt16 = 53
    private static let shiftKeyCodes: Set<UInt16> = [56, 60]

    private var monitors: [Any] = []
    private var held: Set<TriggerKey> = []

    func start() {
        stop()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        held.removeAll()
    }

    private func handle(_ event: NSEvent) {
        if let onCapture {
            capture(event, completion: onCapture)
            return
        }
        switch event.type {
        case .flagsChanged:
            let flags = event.modifierFlags
            if let trigger = triggers.first(where: { $0.keyCode == event.keyCode }) {
                let isDown = trigger.isDown(modifierFlags: flags.rawValue)
                guard isDown != held.contains(trigger) else { return }
                if isDown {
                    held.insert(trigger)
                    if held.count == 1 {
                        onInput?(.triggerDown(shiftHeld: flags.contains(.shift)))
                    }
                } else {
                    held.remove(trigger)
                    if held.isEmpty {
                        onInput?(.triggerUp)
                    }
                }
            } else if Self.shiftKeyCodes.contains(event.keyCode), flags.contains(.shift) {
                onInput?(.shiftDown)
            }
        case .keyDown:
            onInput?(event.keyCode == Self.escapeKeyCode ? .escape : .otherKeyDown)
        default:
            break
        }
    }

    private func capture(_ event: NSEvent, completion: (TriggerKey?) -> Void) {
        switch event.type {
        case .flagsChanged:
            guard let key = TriggerKey(keyCode: event.keyCode),
                  key.isDown(modifierFlags: event.modifierFlags.rawValue)
            else { return }
            onCapture = nil
            completion(key)
        case .keyDown where event.keyCode == Self.escapeKeyCode:
            onCapture = nil
            completion(nil)
        default:
            break
        }
    }
}
