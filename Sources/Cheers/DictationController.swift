import CheersCore
import FluidAudio
import Foundation
import Observation

@Observable
final class DictationController {
    private(set) var isRecording = false
    private(set) var lastTranscript: String?

    @ObservationIgnored var modelStatus: () -> ModelStatus = { .loading }
    @ObservationIgnored private let recorder: AudioRecorder
    @ObservationIgnored private let inserter = TextInserter()
    @ObservationIgnored private let transcriber: Transcriber
    @ObservationIgnored private let overlay: OverlayController
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let dictionary: DictionaryStore
    @ObservationIgnored private let permissions: Permissions
    @ObservationIgnored private var machine = HotkeyStateMachine()
    @ObservationIgnored private var session = 0

    init(
        recorder: AudioRecorder,
        transcriber: Transcriber,
        overlay: OverlayController,
        settings: AppSettings,
        dictionary: DictionaryStore,
        permissions: Permissions
    ) {
        self.recorder = recorder
        self.transcriber = transcriber
        self.overlay = overlay
        self.settings = settings
        self.dictionary = dictionary
        self.permissions = permissions
        overlay.onStop = { [weak self] in self?.stopFromOverlay() }
    }

    func handle(_ input: HotkeyInput) {
        guard let command = machine.handle(input, at: ProcessInfo.processInfo.systemUptime) else { return }
        switch command {
        case .start(let mode):
            start(mode)
        case .lockHandsFree:
            guard isRecording else { return }
            overlay.show(.listening(.handsFree))
        case .finish:
            finish()
        case .cancel:
            cancel()
        }
    }

    func copyLastTranscript() {
        guard let lastTranscript else { return }
        inserter.copyToClipboard(lastTranscript)
    }

    private func start(_ mode: DictationMode) {
        permissions.refresh()
        guard permissions.microphone == .authorized else {
            reject("Cheers needs microphone access", symbol: "mic.slash.fill")
            Task { await permissions.requestMicrophone() }
            return
        }
        switch modelStatus() {
        case .ready:
            break
        case .downloading(let fraction):
            reject("Downloading model · \(Int(fraction * 100))%", symbol: "arrow.down.circle")
            return
        case .loading:
            reject("Warming up the model…", symbol: "hourglass")
            return
        case .failed:
            reject("Speech model failed to load", symbol: "exclamationmark.triangle.fill")
            return
        }

        inserter.prepareFrontmostApp()
        do {
            try recorder.start(deviceUID: settings.preferredMicrophoneUID)
        } catch {
            reject(error.localizedDescription, symbol: "mic.slash.fill")
            return
        }
        session += 1
        isRecording = true
        overlay.show(.listening(mode))
    }

    private func stopFromOverlay() {
        machine.reset()
        finish()
    }

    private func cancel() {
        guard isRecording else { return }
        _ = recorder.stop()
        isRecording = false
        overlay.hide()
    }

    private func finish() {
        guard isRecording else { return }
        let samples = recorder.stop()
        isRecording = false
        let current = session
        overlay.show(.transcribing)

        Task {
            do {
                let raw = try await transcriber.transcribe(samples)
                let text = postProcess(raw)
                guard !text.isEmpty else {
                    if current == session { overlay.hide() }
                    return
                }
                lastTranscript = text
                let outcome = await inserter.insert(text)
                if current == session, !isRecording {
                    overlay.flash(.finished(outcome), for: outcome == .pasted ? .seconds(0.8) : .seconds(1.6))
                }
            } catch {
                if current == session, !isRecording {
                    overlay.flash(.message(error.localizedDescription, symbol: "exclamationmark.triangle.fill"))
                }
            }
        }
    }

    private func postProcess(_ raw: String) -> String {
        let processor = TranscriptPostProcessor(dictionary: dictionary.entries, removeFillers: settings.removeFillers)
        var text = processor.process(raw)
        if settings.smartFormatting {
            text = TextNormalizer.shared.normalizeSentence(text)
        }
        return text
    }

    private func reject(_ message: String, symbol: String) {
        machine.reset()
        overlay.flash(.message(message, symbol: symbol))
    }
}
