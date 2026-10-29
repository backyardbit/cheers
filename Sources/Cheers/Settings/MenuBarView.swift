import SwiftUI

struct MenuBarView: View {
    let model: AppModel

    var body: some View {
        Text(statusText)

        if !model.permissions.microphone.isAuthorized {
            Button("Grant Microphone Access…") {
                Task { await model.permissions.requestMicrophone() }
            }
        }
        if !model.permissions.accessibility {
            Button("Grant Accessibility Access…") {
                model.permissions.requestAccessibility()
            }
        }
        if case .failed = model.modelStatus {
            Button("Retry Loading Model") {
                model.retryModelLoad()
            }
        }

        Divider()

        Button("Copy Last Transcript") {
            model.controller.copyLastTranscript()
        }
        .disabled(model.controller.lastTranscript == nil)

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Cheers") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var statusText: String {
        switch model.modelStatus {
        case .loading:
            "Warming up the model…"
        case .downloading(let fraction):
            "Downloading model · \(Int(fraction * 100))%"
        case .failed(let message):
            "Model failed: \(message)"
        case .ready:
            model.controller.isRecording ? "Listening…" : "Ready · hold fn to dictate"
        }
    }
}
