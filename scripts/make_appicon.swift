// Generates MyDict app-icon PNGs into an .iconset directory.
// Usage: swift scripts/make_appicon.swift <output.iconset-dir>
import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "build/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

func renderIcon(px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: px, height: px)

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    let size = CGFloat(px)
    let inset = size * 0.06
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.40, green: 0.55, blue: 0.96, alpha: 1.0),
        NSColor(calibratedRed: 0.27, green: 0.36, blue: 0.86, alpha: 1.0)
    ])
    gradient?.draw(in: path, angle: -90)

    // White dictionary glyph, centered.
    let base = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: nil)
    if let base {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let glyph = base.withSymbolConfiguration(config) {
            let g = glyph.size
            let target = NSRect(
                x: (size - g.width) / 2,
                y: (size - g.height) / 2,
                width: g.width, height: g.height
            )
            glyph.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in entries {
    guard let data = renderIcon(px: px) else {
        FileHandle.standardError.write("failed \(name)\n".data(using: .utf8)!)
        continue
    }
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).png")
    try? data.write(to: url)
}
print("Wrote iconset to \(outputDir)")
