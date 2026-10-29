import CoreAudio
import Foundation
import Observation

struct AudioInputDevice: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let uid: String
    let name: String
}

nonisolated enum AudioDevices {
    static func inputDevices() -> [AudioInputDevice] {
        var address = globalAddress(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id in
            guard inputChannelCount(of: id) > 0,
                let uid = stringProperty(kAudioDevicePropertyDeviceUID, of: id),
                let name = stringProperty(kAudioObjectPropertyName, of: id)
            else { return nil }
            return AudioInputDevice(id: id, uid: uid, name: name)
        }
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = globalAddress(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        inputDevices().first { $0.uid == uid }?.id
    }

    static func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
            var address = globalAddress(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { _, _ in
                Task { @MainActor in handler() }
            }
        }
    }

    private static func inputChannelCount(of id: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> String? {
        var address = globalAddress(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    private static func globalAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

@Observable
final class MicrophoneMonitor {
    private(set) var devices: [AudioInputDevice] = []
    private(set) var systemDefaultName: String?

    init() {
        refresh()
        AudioDevices.observeChanges { [weak self] in self?.refresh() }
    }

    func isConnected(_ uid: String) -> Bool {
        devices.contains { $0.uid == uid }
    }

    func activeName(preferredUID: String?) -> String? {
        if let preferredUID, let device = devices.first(where: { $0.uid == preferredUID }) {
            return device.name
        }
        return systemDefaultName
    }

    private func refresh() {
        devices = AudioDevices.inputDevices()
        let defaultID = AudioDevices.defaultInputDeviceID()
        systemDefaultName = devices.first { $0.id == defaultID }?.name
    }
}
