import AppKit

let output = URL(filePath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: output)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let colors: [NSColor] = [
    NSColor(red: 0.30, green: 0.84, blue: 1.00, alpha: 1),
    NSColor(red: 0.47, green: 0.40, blue: 1.00, alpha: 1),
    NSColor(red: 0.98, green: 0.34, blue: 0.82, alpha: 1),
    NSColor(red: 1.00, green: 0.60, blue: 0.36, alpha: 1),
    NSColor(red: 0.36, green: 1.00, blue: 0.76, alpha: 1),
]
let frequencies = [1.45, 2.15, 1.10, 2.75, 3.30]
let offsets = [0.4, 2.1, 3.3, 4.6, 5.8]
let weights = [1.0, 0.85, 0.75, 0.6, 0.48]

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = context
    let cg = context.cgContext
    let s = CGFloat(size)

    let inset = s * 0.1
    let tile = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let squircle = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)

    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    squircle.fill()
    cg.restoreGState()

    squircle.addClip()
    NSGradient(colors: [
        NSColor(red: 0.07, green: 0.07, blue: 0.13, alpha: 1),
        NSColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1),
    ])!.draw(in: tile, angle: -90)

    cg.setBlendMode(.screen)
    let midY = tile.midY
    let width = tile.width * 0.78
    let minX = tile.midX - width / 2
    let amplitude = tile.height * 0.26

    for pass in 0..<2 {
        for index in colors.indices {
            let path = CGMutablePath()
            var upper: [CGPoint] = []
            for step in 0...160 {
                let u = Double(step) / 160
                let x = u * 2 - 1
                let envelope = pow(1 - x * x, 2.4)
                let y = amplitude * weights[index] * envelope * sin(frequencies[index] * .pi * x + offsets[index])
                upper.append(CGPoint(x: minX + u * width, y: midY + y))
            }
            path.addLines(between: upper)
            for point in upper.reversed() {
                path.addLine(to: CGPoint(x: point.x, y: 2 * midY - point.y))
            }
            path.closeSubpath()

            cg.saveGState()
            cg.addPath(path)
            cg.clip()
            let alpha = pass == 0 ? 0.3 : 0.62
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    colors[index].withAlphaComponent(0).cgColor,
                    colors[index].withAlphaComponent(alpha).cgColor,
                    colors[index].withAlphaComponent(alpha).cgColor,
                    colors[index].withAlphaComponent(0).cgColor,
                ] as CFArray,
                locations: [0, 0.3, 0.7, 1]
            )!
            if pass == 0 {
                cg.setShadow(offset: .zero, blur: s * 0.04, color: colors[index].cgColor)
            }
            cg.drawLinearGradient(gradient, start: CGPoint(x: minX, y: midY), end: CGPoint(x: minX + width, y: midY), options: [])
            cg.restoreGState()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(size: base * scale).write(to: output.appending(path: name))
    }
}
