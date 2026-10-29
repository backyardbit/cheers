import AppKit
import FluidAudio
import SwiftUI

@main
enum Entry {
    static func main() {
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--transcribe"), index + 1 < arguments.count {
            HeadlessTranscription.run(path: arguments[index + 1])
        } else {
            CheersApp.main()
        }
    }
}

struct CheersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: delegate.model)
        } label: {
            Image(systemName: delegate.model.controller.isRecording ? "waveform.circle.fill" : "waveform")
        }

        Settings {
            SettingsView(model: delegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.launch()
    }
}

enum HeadlessTranscription {
    static func run(path: String) {
        Task {
            do {
                let transcriber = Transcriber()
                let formatter = TranscriptFormatter()
                formatter.prewarm()
                let started = Date()
                try await transcriber.load { _ in }
                let loaded = Date()
                let samples = try AudioConverter().resampleAudioFile(URL(filePath: path))
                let raw = try await transcriber.transcribe(samples)
                let finished = Date()
                let text = await formatter.format(raw, options: FormattingOptions())
                let formatted = Date()
                print("raw:   \(raw)")
                print("final: \(text)")
                print(
                    String(
                        format: "load %.2fs · transcribe %.0fms · cleanup %.0fms for %.1fs of audio",
                        loaded.timeIntervalSince(started),
                        finished.timeIntervalSince(loaded) * 1000,
                        formatted.timeIntervalSince(finished) * 1000,
                        Double(samples.count) / Double(Transcriber.sampleRate)
                    ))
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }
}
