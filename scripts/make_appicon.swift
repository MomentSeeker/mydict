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

    func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }

    func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    func fill(_ path: NSBezierPath, _ color: NSColor) {
        color.setFill()
        path.fill()
    }

    func drawText(_ text: String, at point: NSPoint, size fontSize: CGFloat, alpha: CGFloat = 0.28) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: c(20, 31, 46, alpha)
        ]
        text.draw(at: point, withAttributes: attrs)
    }

    let scale = size / 1024
    let iconRect = NSRect(x: size * 0.058, y: size * 0.055, width: size * 0.884, height: size * 0.884)
    let iconPath = rounded(iconRect, iconRect.width * 0.225)

    let baseShadow = NSShadow()
    baseShadow.shadowBlurRadius = 26 * scale
    baseShadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    baseShadow.shadowColor = c(0, 35, 88, 0.26)
    baseShadow.set()
    fill(iconPath, c(38, 135, 241))
    NSShadow().set()

    NSGraphicsContext.saveGraphicsState()
    iconPath.addClip()

    NSGradient(colors: [
        c(42, 164, 255),
        c(23, 117, 231),
        c(10, 78, 181)
    ])?.draw(in: iconPath, angle: 42)

    let glow = NSBezierPath(ovalIn: NSRect(x: size * 0.34, y: size * 0.63, width: size * 0.78, height: size * 0.42))
    fill(glow, c(116, 215, 255, 0.24))

    let lowerGlow = NSBezierPath(ovalIn: NSRect(x: -size * 0.10, y: size * 0.08, width: size * 0.88, height: size * 0.58))
    fill(lowerGlow, c(0, 35, 105, 0.22))

    // The inset tile echoes the supplied prototype while staying abstract enough
    // to read cleanly at small Dock sizes.
    let cardRect = NSRect(x: size * 0.205, y: size * 0.390, width: size * 0.595, height: size * 0.365)
    let cardPath = rounded(cardRect, size * 0.105)
    let cardShadow = NSShadow()
    cardShadow.shadowBlurRadius = 18 * scale
    cardShadow.shadowOffset = NSSize(width: 0, height: -8 * scale)
    cardShadow.shadowColor = c(0, 36, 101, 0.25)
    cardShadow.set()
    fill(cardPath, c(56, 170, 255, 0.95))
    NSShadow().set()

    NSGraphicsContext.saveGraphicsState()
    cardPath.addClip()
    NSGradient(colors: [
        c(74, 191, 255, 0.98),
        c(25, 122, 229, 0.96),
        c(10, 55, 123, 0.94)
    ])?.draw(in: cardPath, angle: -28)

    fill(NSBezierPath(rect: NSRect(x: cardRect.minX, y: cardRect.minY, width: cardRect.width * 0.18, height: cardRect.height)), c(0, 42, 108, 0.18))
    fill(NSBezierPath(ovalIn: NSRect(x: cardRect.minX + cardRect.width * 0.40, y: cardRect.minY + cardRect.height * 0.12, width: cardRect.width * 0.34, height: cardRect.height * 0.62)), c(246, 190, 164, 0.30))
    fill(NSBezierPath(ovalIn: NSRect(x: cardRect.minX + cardRect.width * 0.30, y: cardRect.minY + cardRect.height * 0.05, width: cardRect.width * 0.34, height: cardRect.height * 0.82)), c(25, 22, 36, 0.28))
    fill(NSBezierPath(ovalIn: NSRect(x: cardRect.minX + cardRect.width * 0.56, y: cardRect.minY + cardRect.height * 0.30, width: cardRect.width * 0.08, height: cardRect.height * 0.10)), c(18, 26, 44, 0.42))
    fill(NSBezierPath(ovalIn: NSRect(x: cardRect.minX + cardRect.width * 0.69, y: cardRect.minY + cardRect.height * 0.31, width: cardRect.width * 0.07, height: cardRect.height * 0.09)), c(18, 26, 44, 0.36))
    NSGraphicsContext.restoreGraphicsState()

    let spine = NSBezierPath()
    spine.move(to: NSPoint(x: cardRect.minX + cardRect.width * 0.18, y: cardRect.minY + 2 * scale))
    spine.line(to: NSPoint(x: cardRect.minX + cardRect.width * 0.18, y: cardRect.maxY - 2 * scale))
    spine.lineWidth = max(1, 7 * scale)
    c(255, 255, 255, 0.18).setStroke()
    spine.stroke()

    let sheetShadow = NSShadow()
    sheetShadow.shadowBlurRadius = 28 * scale
    sheetShadow.shadowOffset = NSSize(width: 0, height: -14 * scale)
    sheetShadow.shadowColor = c(5, 20, 40, 0.34)
    sheetShadow.set()

    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: size * 0.50, yBy: size * 0.315)
    transform.rotate(byDegrees: -15)
    transform.translateX(by: -size * 0.50, yBy: -size * 0.315)
    transform.concat()

    let paperRect = NSRect(x: size * 0.125, y: size * 0.105, width: size * 0.795, height: size * 0.385)
    let paperPath = rounded(paperRect, size * 0.030)
    fill(paperPath, c(247, 250, 248, 0.98))
    NSShadow().set()

    NSGraphicsContext.saveGraphicsState()
    paperPath.addClip()
    NSGradient(colors: [
        c(255, 255, 255, 1),
        c(218, 229, 229, 1),
        c(248, 250, 247, 1)
    ])?.draw(in: paperPath, angle: 22)

    fill(NSBezierPath(rect: NSRect(x: paperRect.minX, y: paperRect.minY, width: paperRect.width, height: paperRect.height * 0.26)), c(190, 210, 215, 0.30))
    fill(NSBezierPath(ovalIn: NSRect(x: paperRect.minX + paperRect.width * 0.02, y: paperRect.minY - paperRect.height * 0.56, width: paperRect.width * 0.75, height: paperRect.height * 1.20)), c(153, 94, 47, 0.50))
    fill(NSBezierPath(rect: NSRect(x: paperRect.minX + paperRect.width * 0.64, y: paperRect.minY, width: paperRect.width * 0.36, height: paperRect.height)), c(231, 238, 240, 0.72))

    let lineCount = 9
    for index in 0..<lineCount {
        let y = paperRect.minY + paperRect.height * (0.17 + CGFloat(index) * 0.078)
        let x = paperRect.minX + paperRect.width * (index.isMultiple(of: 2) ? 0.58 : 0.66)
        let w = paperRect.width * (index.isMultiple(of: 3) ? 0.30 : 0.24)
        let line = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: max(1.5, 8 * scale)), xRadius: 3 * scale, yRadius: 3 * scale)
        fill(line, c(17, 28, 40, index.isMultiple(of: 2) ? 0.28 : 0.18))
    }

    drawText("phonetic", at: NSPoint(x: paperRect.minX + paperRect.width * 0.55, y: paperRect.minY + paperRect.height * 0.69), size: 34 * scale, alpha: 0.24)
    drawText("definition", at: NSPoint(x: paperRect.minX + paperRect.width * 0.63, y: paperRect.minY + paperRect.height * 0.45), size: 30 * scale, alpha: 0.20)
    drawText("/ phone-in /", at: NSPoint(x: paperRect.minX + paperRect.width * 0.58, y: paperRect.minY + paperRect.height * 0.28), size: 28 * scale, alpha: 0.18)

    let gloss = rounded(NSRect(x: paperRect.minX + paperRect.width * 0.02, y: paperRect.maxY - paperRect.height * 0.18, width: paperRect.width * 0.95, height: paperRect.height * 0.14), 16 * scale)
    fill(gloss, c(255, 255, 255, 0.30))
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()

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
