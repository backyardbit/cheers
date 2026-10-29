import AppKit
import CheersCore
import FluidAudio
import Observation

enum ModelStatus: Equatable {
    case loading
    case downloading(Double)
    case ready
    case failed(String)
}

@Observable
final class AppModel {
    private(set) var modelStatus: ModelStatus = .loading
    private(set) var isCapturingTrigger = false

    let settings = AppSettings()
    let permissions = Permissions()
    let dictionary = DictionaryStore()
    let microphones = MicrophoneMonitor()

    @ObservationIgnored let controller: DictationController
    @ObservationIgnored private let transcriber = Transcriber()
    @ObservationIgnored private let hotkeys = HotkeyMonitor()
    @ObservationIgnored private var vocabularyTask: Task<Void, Never>?
    @ObservationIgnored private var permissionTimer: Timer?

    init() {
        let recorder = AudioRecorder()
        controller = DictationController(
            recorder: recorder,
            transcriber: transcriber,
            overlay: OverlayController(meter: recorder.meter),
            settings: settings,
            dictionary: dictionary,
            permissions: permissions
        )
        controller.modelStatus = { [weak self] in self?.modelStatus ?? .loading }
    }

    func launch() {
        hotkeys.onInput = { [weak controller] input in controller?.handle(input) }
        hotkeys.triggers = settings.triggers
        settings.onTriggersChanged = { [weak hotkeys] triggers in hotkeys?.triggers = triggers }
        hotkeys.start()

        dictionary.onChange = { [weak self] entries in self?.scheduleVocabularyUpdate(entries) }

        if !permissions.accessibility {
            permissions.requestAccessibility()
        }
        Task { await permissions.requestMicrophone() }

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.permissions.refresh() {
                    self.hotkeys.start()
                }
            }
        }

        Task { await loadModel() }
    }

    func captureTrigger() {
        isCapturingTrigger = true
        hotkeys.onCapture = { [weak self] key in
            guard let self else { return }
            isCapturingTrigger = false
            if let key, key != .function {
                settings.alternateTrigger = key
            }
        }
    }

    func cancelTriggerCapture() {
        hotkeys.onCapture = nil
        isCapturingTrigger = false
    }

    func retryModelLoad() {
        Task { await loadModel() }
    }

    private func loadModel() async {
        modelStatus = .loading
        do {
            try await transcriber.load { [weak self] progress in
                Task { @MainActor in self?.apply(progress) }
            }
            await transcriber.setVocabulary(dictionary.entries)
            modelStatus = .ready
        } catch {
            modelStatus = .failed(error.localizedDescription)
        }
    }

    private func apply(_ progress: DownloadProgress) {
        guard modelStatus != .ready else { return }
        switch progress.phase {
        case .listing, .downloading:
            modelStatus = .downloading(progress.fractionCompleted)
        case .compiling:
            modelStatus = .loading
        }
    }

    private func scheduleVocabularyUpdate(_ entries: [DictionaryEntry]) {
        vocabularyTask?.cancel()
        vocabularyTask = Task { [transcriber] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await transcriber.setVocabulary(entries)
        }
    }
}
