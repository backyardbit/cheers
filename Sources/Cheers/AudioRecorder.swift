import AVFoundation
import Accelerate
import Foundation
import os

nonisolated final class AudioRecorder: @unchecked Sendable {
    enum RecorderError: LocalizedError {
        case noInputDevice

        var errorDescription: String? { "No microphone is available." }
    }

    let meter = AudioMeter()

    private let samples = OSAllocatedUnfairLock(initialState: [Float]())
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    func start(deviceUID: String?) throws {
        guard engine == nil else { return }
        samples.withLock { $0.removeAll(keepingCapacity: true) }
        meter.reset()

        let engine = AVAudioEngine()
        let input = engine.inputNode
        if let deviceUID, var deviceID = AudioDevices.deviceID(forUID: deviceUID), let unit = input.audioUnit {
            AudioUnitSetProperty(
                unit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &deviceID,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Double(Transcriber.sampleRate),
                channels: 1,
                interleaved: false
            ),
            let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: inputFormat.sampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: monoFormat, to: targetFormat)
        else { throw RecorderError.noInputDevice }

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.consume(buffer, monoFormat: monoFormat, targetFormat: targetFormat, converter: converter)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        self.engine = engine
        self.converter = converter
        self.targetFormat = targetFormat
    }

    func finish(tail: Duration) async -> [Float] {
        try? await Task.sleep(for: tail)
        return stop()
    }

    func stop() -> [Float] {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.engine = nil
            flushConverter()
        }
        meter.reset()
        return samples.withLock { buffer in
            defer { buffer.removeAll() }
            return buffer
        }
    }

    private func flushConverter() {
        defer {
            converter = nil
            targetFormat = nil
        }
        guard let converter, let targetFormat,
            let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: 4096)
        else { return }
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            status.pointee = .endOfStream
            return nil
        }
        guard error == nil, output.frameLength > 0, let data = output.floatChannelData?[0] else { return }
        let remainder = Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
        samples.withLock { $0.append(contentsOf: remainder) }
    }

    private func consume(
        _ buffer: AVAudioPCMBuffer,
        monoFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter
    ) {
        guard let channels = buffer.floatChannelData, buffer.frameLength > 0,
            let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameLength),
            let destination = mono.floatChannelData?[0]
        else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        mono.frameLength = buffer.frameLength
        destination.update(from: channels[0], count: frameCount)
        if channelCount > 1 {
            for channel in 1..<channelCount {
                vDSP_vadd(destination, 1, channels[channel], 1, destination, 1, vDSP_Length(frameCount))
            }
            var scale = 1 / Float(channelCount)
            vDSP_vsmul(destination, 1, &scale, destination, 1, vDSP_Length(frameCount))
        }

        let ratio = targetFormat.sampleRate / monoFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(frameCount) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        nonisolated(unsafe) let source = mono
        nonisolated(unsafe) var supplied = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return source
        }
        guard error == nil, output.frameLength > 0, let data = output.floatChannelData?[0] else { return }

        let chunk = Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
        samples.withLock { $0.append(contentsOf: chunk) }
        meter.ingest(chunk)
    }
}
