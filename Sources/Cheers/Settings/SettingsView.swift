import CheersCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(model: model)
            }
            Tab("Dictionary", systemImage: "character.book.closed") {
                DictionarySettingsView(store: model.dictionary)
            }
        }
        .frame(width: 560, height: 500)
        .onAppear {
            NSApp.activate()
            model.permissions.refresh()
        }
    }
}

private struct GeneralSettingsView: View {
    let model: AppModel

    var body: some View {
        @Bindable var settings = model.settings

        Form {
            Section("Shortcuts") {
                LabeledContent("Also dictate with") {
                    HStack {
                        if model.isCapturingTrigger {
                            Text("Press a modifier key…")
                                .foregroundStyle(.secondary)
                            Button("Cancel") { model.cancelTriggerCapture() }
                        } else {
                            Text(settings.alternateTrigger?.displayName ?? "fn only")
                            Button("Record…") { model.captureTrigger() }
                            if settings.alternateTrigger != nil {
                                Button("Clear") { settings.alternateTrigger = nil }
                            }
                        }
                    }
                }
                Text("For keyboards without an Apple fn key. Click Record and press the key you want to hold, such as Control, Option or Command on either side.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                LabeledContent("Push to talk", value: "Hold \(settings.triggerDescription)")
                LabeledContent("Hands-free", value: "Shift + \(settings.triggerDescription), press again to finish")
                LabeledContent("Cancel", value: "Esc")
                HStack {
                    Text("Set “Press 🌐 key to” to “Do Nothing” so the emoji picker stays out of the way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Keyboard Settings…") {
                        model.permissions.openKeyboardSettings()
                    }
                }
            }

            Section("Transcription") {
                LabeledContent("Model") {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Parakeet Ultra 0.6B")
                        Text(modelStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Remove filler words", isOn: $settings.removeFillers)
                Toggle("Smart formatting for numbers, dates and currency", isOn: $settings.smartFormatting)
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Microphone",
                    detail: "Hear you while the shortcut is held",
                    granted: model.permissions.microphone.isAuthorized
                ) {
                    Task { await model.permissions.requestMicrophone() }
                }
                PermissionRow(
                    title: "Accessibility",
                    detail: "Detect fn and paste into the focused field",
                    granted: model.permissions.accessibility
                ) {
                    model.permissions.requestAccessibility()
                }
            }

            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .onDisappear { model.cancelTriggerCapture() }
    }

    private var modelStatusText: String {
        switch model.modelStatus {
        case .loading: "Loading on the Neural Engine…"
        case .downloading(let fraction): "Downloading · \(Int(fraction * 100))%"
        case .ready: "Ready on the Neural Engine"
        case .failed(let message): message
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .labelStyle(.titleAndIcon)
            } else {
                Button("Grant…", action: request)
            }
        }
    }
}
