import SwiftUI

struct MicrophonePicker: View {
    let model: AppModel

    var body: some View {
        Picker("Microphone", selection: selection) {
            Text(systemDefaultLabel).tag(String?.none)
            ForEach(model.microphones.devices) { device in
                Text(device.name).tag(Optional(device.uid))
            }
            if let uid = model.settings.preferredMicrophoneUID, !model.microphones.isConnected(uid) {
                Text("\(model.settings.preferredMicrophoneName ?? "Saved microphone") (not connected)")
                    .tag(Optional(uid))
            }
        }
    }

    private var selection: Binding<String?> {
        Binding(
            get: { model.settings.preferredMicrophoneUID },
            set: { uid in
                model.settings.preferredMicrophoneUID = uid
                model.settings.preferredMicrophoneName = model.microphones.devices.first { $0.uid == uid }?.name
            }
        )
    }

    private var systemDefaultLabel: String {
        model.microphones.systemDefaultName.map { "System Default (\($0))" } ?? "System Default"
    }
}
