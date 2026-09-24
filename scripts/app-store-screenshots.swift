// SPDX-License-Identifier: MIT
// Turns raw full-screen screenshots into Mac App Store screenshots: 2880×1800 (16:10, a size App
// Store Connect takes for Mac), a headline and a line under it, then the top of the screen, where
// the notch is, enlarged on a dark backdrop.
//
//   swift scripts/app-store-screenshots.swift <manifest.tsv> <output folder>
//
// Each manifest line is tab-separated: the screenshot, the headline, the line under it, and
// optionally how many of the screenshot's pixels across to show (default 2000, centered; fewer
// zooms in). Lines starting with # are skipped. Output files are numbered in manifest order.
import AppKit

let canvas = CGSize(width: 2880, height: 1800)
/// Where the enlarged screen goes: its aspect decides how much of the screenshot's height shows.
let panel = CGRect(x: 240, y: 120, width: 2400, height: 1160)

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("usage: swift scripts/app-store-screenshots.swift <manifest.tsv> <output folder>")
    exit(64)
}
let manifest = try String(contentsOfFile: arguments[1], encoding: .utf8)
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let entries = manifest.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
for (index, line) in entries.enumerated() {
    let fields = line.components(separatedBy: "\t")
    guard fields.count >= 3, let source = NSImage(contentsOfFile: fields[0]),
        let screen = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
        print("skipped: \(line)")
        continue
    }
    let across = fields.count > 3 ? CGFloat(Double(fields[3]) ?? 2000) : 2000
    let name = String(format: "%02d", index + 1) + ".png"
    try render(screen: screen, headline: fields[1], subtitle: fields[2], across: across)
        .write(to: output.appendingPathComponent(name))
    print("wrote \(name): \(fields[1])")
}

func render(screen: CGImage, headline: String, subtitle: String, across: CGFloat) throws -> Data {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 32)
    else { throw CocoaError(.fileWriteUnknown) }
    bitmap.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // A dark backdrop, lit a little from behind the screen.
    NSGradient(colors: [NSColor(white: 0.06, alpha: 1), NSColor(red: 0.1, green: 0.09, blue: 0.14, alpha: 1)])?
        .draw(in: CGRect(origin: .zero, size: canvas), angle: -90)
    NSGradient(colors: [NSColor(white: 1, alpha: 0.07), NSColor(white: 1, alpha: 0)])?
        .draw(fromCenter: CGPoint(x: canvas.width / 2, y: panel.midY), radius: 0,
            toCenter: CGPoint(x: canvas.width / 2, y: panel.midY), radius: 1500, options: [])

    // The headline and the line under it, centered above the screen.
    let centered = NSMutableParagraphStyle()
    centered.alignment = .center
    NSAttributedString(
        string: headline,
        attributes: [
            .font: NSFont.systemFont(ofSize: 112, weight: .bold), .foregroundColor: NSColor.white,
            .paragraphStyle: centered,
        ]
    ).draw(in: CGRect(x: 120, y: canvas.height - 300, width: canvas.width - 240, height: 150))
    NSAttributedString(
        string: subtitle,
        attributes: [
            .font: NSFont.systemFont(ofSize: 52, weight: .regular),
            .foregroundColor: NSColor(white: 1, alpha: 0.68), .paragraphStyle: centered,
        ]
    ).draw(in: CGRect(x: 160, y: canvas.height - 410, width: canvas.width - 320, height: 80))

    // The top of the screen, centered, as much of it across as asked for, in the panel's shape.
    let width = min(across, CGFloat(screen.width))
    let height = width * panel.height / panel.width
    let crop = CGRect(x: (CGFloat(screen.width) - width) / 2, y: 0, width: width, height: height)
    guard let top = screen.cropping(to: crop) else { throw CocoaError(.fileReadCorruptFile) }
    let frame = NSBezierPath(roundedRect: panel, xRadius: 40, yRadius: 40)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 0, alpha: 0.7)
    shadow.shadowBlurRadius = 60
    shadow.shadowOffset = CGSize(width: 0, height: -20)
    shadow.set()
    NSColor.black.setFill()
    frame.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    frame.addClip()
    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.cgContext.draw(top, in: panel)
    NSGraphicsContext.restoreGraphicsState()
    NSColor(white: 1, alpha: 0.12).setStroke()
    frame.lineWidth = 3
    frame.stroke()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}
