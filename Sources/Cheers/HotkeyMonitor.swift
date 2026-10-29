import AppKit
import CheersCore

final class HotkeyMonitor {
    var onInput: ((HotkeyInput) -> Void)?

    private static let fnKeyCode: UInt16 = 63
    private static let escapeKeyCode: UInt16 = 53
    private static let shiftKeyCodes: Set<UInt16> = [56, 60]

    private var monitors: [Any] = []
    private var fnIsDown = false

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
        fnIsDown = false
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            let flags = event.modifierFlags
            if event.keyCode == Self.fnKeyCode {
                let isDown = flags.contains(.function)
                guard isDown != fnIsDown else { return }
                fnIsDown = isDown
                onInput?(isDown ? .fnDown(shiftHeld: flags.contains(.shift)) : .fnUp)
            } else if Self.shiftKeyCodes.contains(event.keyCode), flags.contains(.shift) {
                onInput?(.shiftDown)
            }
        case .keyDown:
            onInput?(event.keyCode == Self.escapeKeyCode ? .escape : .otherKeyDown)
        default:
            break
        }
    }
}
