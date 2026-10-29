import SwiftUI

struct WaveformView: View {
    let meter: AudioMeter
    let isListening: Bool

    @State private var engine = WaveEngine()

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphics, size in
                engine.step(
                    to: context.date.timeIntervalSinceReferenceDate,
                    snapshot: meter.snapshot(),
                    isListening: isListening
                )
                engine.draw(in: &graphics, size: size)
            }
        }
    }
}

final class WaveEngine {
    private struct Strand {
        let color: Color
        let frequency: Double
        let speed: Double
        let offset: Double
        let band: Int
        let weight: Double
    }

    private static let strands: [Strand] = [
        Strand(color: Color(red: 0.30, green: 0.84, blue: 1.00), frequency: 1.45, speed: 2.1, offset: 0.0, band: 0, weight: 0.9),
        Strand(color: Color(red: 0.47, green: 0.40, blue: 1.00), frequency: 2.15, speed: -2.6, offset: 1.7, band: 1, weight: 0.96),
        Strand(color: Color(red: 0.98, green: 0.34, blue: 0.82), frequency: 1.10, speed: 1.5, offset: 3.1, band: 2, weight: 1.0),
        Strand(color: Color(red: 1.00, green: 0.60, blue: 0.36), frequency: 2.75, speed: -3.2, offset: 4.4, band: 3, weight: 0.9),
        Strand(color: Color(red: 0.36, green: 1.00, blue: 0.76), frequency: 3.30, speed: 3.7, offset: 5.6, band: 4, weight: 0.8),
    ]

    private static let resolution = 72

    private var lastTime: Double?
    private var level = 0.0
    private var bands = [Double](repeating: 0.4, count: AudioMeter.bandCount)
    private var activity = 0.0
    private var flow = 0.0
    private var clock = 0.0

    func step(to time: Double, snapshot: AudioMeter.Snapshot, isListening: Bool) {
        let dt = min(max(time - (lastTime ?? time), 0), 1.0 / 20)
        lastTime = time
        clock += dt

        let targetLevel = isListening ? Double(snapshot.level) : 0
        let levelTau = targetLevel > level ? 0.05 : 0.24
        level += (targetLevel - level) * smoothing(dt, levelTau)

        for index in bands.indices {
            let target = isListening ? Double(snapshot.bands[index]) : 0.4
            bands[index] += (target - bands[index]) * smoothing(dt, 0.12)
        }

        activity += ((isListening ? 1 : 0) - activity) * smoothing(dt, 0.3)
        flow += dt * (0.7 + level * 2.2)
    }

    func draw(in graphics: inout GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let paths = Self.strands.map { strandPath($0, size: size) }

        drawBaseline(in: &graphics, size: size, midY: midY)

        graphics.drawLayer { glow in
            glow.addFilter(.blur(radius: 7))
            glow.blendMode = .plusLighter
            for (strand, path) in zip(Self.strands, paths) {
                glow.fill(path, with: fade(strand.color, opacity: 0.3, size: size))
            }
        }

        graphics.drawLayer { crisp in
            crisp.blendMode = .screen
            for (strand, path) in zip(Self.strands, paths) {
                crisp.fill(path, with: fade(strand.color, opacity: 0.55, size: size))
                crisp.stroke(path, with: fade(.white, opacity: 0.12, size: size), lineWidth: 0.6)
            }
        }

        drawComet(in: &graphics, size: size, midY: midY)
    }

    private func strandPath(_ strand: Strand, size: CGSize) -> Path {
        let midY = size.height / 2
        let maxAmplitude = size.height * 0.47

        let energy = pow(level, 0.85) * (0.62 + 0.7 * bands[strand.band]) * strand.weight
        let resting = 0.035 + 0.012 * sin(clock * 1.6 + strand.offset)
        let listening = max(resting, min(energy, 1))
        let thinking = 0.05 + 0.035 * sin(clock * 3.4 + strand.offset * 1.3)
        let amplitude = maxAmplitude * (activity * listening + (1 - activity) * thinking)

        let wobble = 0.18 * sin(clock * 0.55 + strand.offset)
        let phase = flow * strand.speed + strand.offset

        var upper: [CGPoint] = []
        upper.reserveCapacity(Self.resolution + 1)
        for step in 0...Self.resolution {
            let u = Double(step) / Double(Self.resolution)
            let x = u * 2 - 1
            let envelope = pow(1 - x * x, 2.4)
            let y = amplitude * envelope * sin((strand.frequency + wobble) * .pi * x + phase)
            upper.append(CGPoint(x: u * size.width, y: midY - y))
        }

        var path = Path()
        path.addLines(upper)
        for point in upper.reversed() {
            path.addLine(to: CGPoint(x: point.x, y: 2 * midY - point.y))
        }
        path.closeSubpath()
        return path
    }

    private func drawBaseline(in graphics: inout GraphicsContext, size: CGSize, midY: Double) {
        var line = Path()
        line.move(to: CGPoint(x: 0, y: midY))
        line.addLine(to: CGPoint(x: size.width, y: midY))
        graphics.stroke(line, with: fade(.white, opacity: 0.18 + 0.2 * level, size: size), lineWidth: 1)
    }

    private func drawComet(in graphics: inout GraphicsContext, size: CGSize, midY: Double) {
        let strength = 1 - activity
        guard strength > 0.02 else { return }

        let travel = sin(clock * 2.3)
        let x = size.width * (0.5 + 0.4 * travel)
        let hue = Self.strands[Int((clock * 0.8).truncatingRemainder(dividingBy: Double(Self.strands.count)))].color

        graphics.drawLayer { comet in
            comet.blendMode = .plusLighter
            comet.opacity = strength
            comet.addFilter(.blur(radius: 4))
            let halo = CGRect(x: x - 34, y: midY - 9, width: 68, height: 18)
            comet.fill(
                Path(ellipseIn: halo),
                with: .radialGradient(
                    Gradient(colors: [hue.opacity(0.9), hue.opacity(0)]),
                    center: CGPoint(x: x, y: midY),
                    startRadius: 0,
                    endRadius: 34
                )
            )
            let core = CGRect(x: x - 9, y: midY - 2, width: 18, height: 4)
            comet.fill(Path(ellipseIn: core), with: .color(.white.opacity(0.9)))
        }
    }

    private func fade(_ color: Color, opacity: Double, size: CGSize) -> GraphicsContext.Shading {
        .linearGradient(
            Gradient(stops: [
                .init(color: color.opacity(0), location: 0),
                .init(color: color.opacity(opacity), location: 0.3),
                .init(color: color.opacity(opacity), location: 0.7),
                .init(color: color.opacity(0), location: 1),
            ]),
            startPoint: CGPoint(x: 0, y: size.height / 2),
            endPoint: CGPoint(x: size.width, y: size.height / 2)
        )
    }

    private func smoothing(_ dt: Double, _ tau: Double) -> Double {
        1 - exp(-dt / tau)
    }
}
