import CheersCore
import FluidAudio
import Foundation
import os

actor Transcriber {
    enum TranscriberError: LocalizedError {
        case notReady

        var errorDescription: String? { "The speech model is still loading." }
    }

    static let sampleRate = 16_000

    private let logger = Logger(subsystem: "com.benkleyner.cheers", category: "Transcriber")
    private var manager: AsrManager?
    private var ctcModels: CtcModels?
    private var boosting: VocabularyBoostingSession?

    var isReady: Bool { manager != nil }

    func load(progress: @escaping @Sendable (DownloadProgress) -> Void) async throws {
        guard manager == nil else { return }
        let models = try await AsrModels.downloadAndLoad(version: .ultra, progressHandler: progress)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        _ = try? await manager.transcribe([Float](repeating: 0, count: Self.sampleRate), decoderState: &state)
        self.manager = manager
    }

    func setVocabulary(_ entries: [DictionaryEntry]) async {
        let terms = entries.filter(\.isSpeakable).map { entry in
            CustomVocabularyTerm(
                text: entry.term.trimmingCharacters(in: .whitespaces),
                aliases: entry.soundsLike.isEmpty ? nil : entry.soundsLike
            )
        }
        guard !terms.isEmpty else {
            boosting = nil
            return
        }
        do {
            let ctcModels: CtcModels
            if let loaded = self.ctcModels {
                ctcModels = loaded
            } else {
                ctcModels = try await CtcModels.downloadAndLoad()
                self.ctcModels = ctcModels
            }
            boosting = try await VocabularyBoostingSession(
                vocabulary: CustomVocabularyContext(terms: terms),
                ctcModels: ctcModels
            )
        } catch {
            logger.error("Vocabulary boosting unavailable: \(error.localizedDescription)")
            boosting = nil
        }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else { throw TranscriberError.notReady }
        guard samples.count >= Self.sampleRate / 4 else { return "" }

        var audio = samples
        if audio.count < Self.sampleRate {
            audio += [Float](repeating: 0, count: Self.sampleRate - audio.count)
        }

        var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(audio, decoderState: &state)
        guard let boosting, let timings = result.tokenTimings, !timings.isEmpty else {
            return result.text
        }
        let rescored = await boosting.rescore(text: result.text, tokenTimings: timings, audioSamples: audio)
        return rescored?.text ?? result.text
    }
}
