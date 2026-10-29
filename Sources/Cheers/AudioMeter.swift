import Accelerate
import Foundation
import os

nonisolated final class AudioMeter: @unchecked Sendable {
    struct Snapshot: Sendable {
        var level: Float = 0
        var bands = [Float](repeating: 0, count: AudioMeter.bandCount)
    }

    static let bandCount = 5

    private static let fftSize = 512
    private static let bandEdges = [3, 8, 16, 32, 64, 160]

    private let state = OSAllocatedUnfairLock(initialState: Snapshot())
    private let fft = vDSP.FFT(log2n: 9, radix: .radix2, ofType: DSPSplitComplex.self)
    private let hann = vDSP.window(
        ofType: Float.self,
        usingSequence: .hanningDenormalized,
        count: AudioMeter.fftSize,
        isHalfWindow: false
    )
    private var history: [Float] = []
    private var noiseFloor: Float = -60
    private var peak: Float = -30

    func snapshot() -> Snapshot {
        state.withLock { $0 }
    }

    func reset() {
        history.removeAll(keepingCapacity: true)
        state.withLock { $0 = Snapshot() }
    }

    func ingest(_ chunk: [Float]) {
        guard !chunk.isEmpty else { return }
        history.append(contentsOf: chunk)
        if history.count > Self.fftSize {
            history.removeFirst(history.count - Self.fftSize)
        }

        let rms = vDSP.rootMeanSquare(chunk)
        let decibels = 20 * log10(max(rms, 1e-7))
        let level = normalizedLevel(decibels)
        let bands = history.count == Self.fftSize ? spectrumBands() : Snapshot().bands
        state.withLock { $0 = Snapshot(level: level, bands: bands) }
    }

    private func normalizedLevel(_ decibels: Float) -> Float {
        noiseFloor = decibels < noiseFloor ? max(decibels, -90) : min(noiseFloor + 0.02, decibels)
        peak = decibels > peak ? decibels : peak - 0.08
        let floor = noiseFloor + 4
        let span = max(peak - floor, 14)
        return min(max((decibels - floor) / span, 0), 1)
    }

    private func spectrumBands() -> [Float] {
        guard let fft else { return Snapshot().bands }
        let half = Self.fftSize / 2
        let windowed = vDSP.multiply(history, hann)
        var real = [Float](repeating: 0, count: half)
        var imaginary = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                guard let realBase = realPointer.baseAddress, let imaginaryBase = imaginaryPointer.baseAddress else {
                    return
                }
                var split = DSPSplitComplex(realp: realBase, imagp: imaginaryBase)
                windowed.withUnsafeBufferPointer { samples in
                    samples.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(half))
                    }
                }
                fft.forward(input: split, output: &split)
                vDSP.squareMagnitudes(split, result: &power)
            }
        }

        let energies = (0..<Self.bandCount).map { band -> Float in
            let range = Self.bandEdges[band]..<Self.bandEdges[band + 1]
            return sqrt(vDSP.mean(power[range]))
        }
        let mean = vDSP.mean(energies)
        guard mean > 0 else { return Snapshot().bands }
        return energies.map { min($0 / mean, 2.5) / 2.5 }
    }
}
