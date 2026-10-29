import AppKit
import CheersCore
import Observation
import SwiftUI

enum OverlayPhase: Equatable {
    case hidden
    case listening(DictationMode)
    case transcribing
    case finished(InsertionOutcome)
    case message(String, symbol: String)
}

@Observable
final class OverlayModel {
    var phase: OverlayPhase = .hidden
    @ObservationIgnored var onStop: (() -> Void)?
}

final class OverlayController {
    private static let panelSize = CGSize(width: 480, height: 150)
    private static let bottomInset: CGFloat = 18

    var onStop: (() -> Void)? {
        get { model.onStop }
        set { model.onStop = newValue }
    }

    private let model = OverlayModel()
    private let panel: NSPanel
    private var dismissal: Task<Void, Never>?

    init(meter: AudioMeter) {
        panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let host = NSHostingView(rootView: OverlayView(model: model, meter: meter))
        host.sizingOptions = []
        panel.contentView = host
    }

    func show(_ phase: OverlayPhase) {
        dismissal?.cancel()
        if model.phase == .hidden {
            reposition()
        }
        panel.ignoresMouseEvents = phase != .listening(.handsFree)
        panel.orderFrontRegardless()
        model.phase = phase
    }

    func flash(_ phase: OverlayPhase, for duration: Duration = .seconds(1.4)) {
        show(phase)
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    func hide() {
        dismissal?.cancel()
        model.phase = .hidden
        panel.ignoresMouseEvents = true
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    private func reposition() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(CGPoint(
            x: frame.midX - Self.panelSize.width / 2,
            y: frame.minY + Self.bottomInset
        ))
    }
}
