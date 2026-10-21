// Renders the 1024px app icon: a dusk sky whose stars form a calendar grid, one "today" star glowing,
// above a sun sitting on the horizon. Usage: swift scripts/make_icon.swift out.png
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"
let size = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func gradient(_ stops: [(UInt32, CGFloat, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map { color($0.0, $0.1) } as CFArray,
               locations: stops.map { $0.2 })!
}

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
let horizon: CGFloat = 395

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x000000, 0.4))
ctx.addPath(shape); ctx.setFillColor(color(0x10162E)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shape); ctx.clip()

// Sky
ctx.drawLinearGradient(gradient([(0x111836, 1, 0), (0x2E2A6B, 1, 0.38), (0x8C4A8E, 1, 0.74), (0xFF8E5E, 1, 1)]),
                       start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: horizon), options: [])

// Glow around the sun
ctx.drawRadialGradient(gradient([(0xFFD27A, 0.85, 0), (0xFF8A5B, 0.35, 0.45), (0xFF8A5B, 0, 1)]),
                       startCenter: CGPoint(x: 512, y: horizon), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: horizon), endRadius: 420, options: [])

// Star calendar: 7 x 3 grid, one bright "today"
let cols = 7, rows = 3
let x0: CGFloat = 262, x1: CGFloat = 762, yTop: CGFloat = 812, rowGap: CGFloat = 78
for r in 0..<rows {
    for c in 0..<cols {
        let x = x0 + CGFloat(c) * (x1 - x0) / CGFloat(cols - 1)
        let y = yTop - CGFloat(r) * rowGap
        let today = (r == 1 && c == 4)
        let radius: CGFloat = today ? 19 : 10.5
        if today {
            ctx.drawRadialGradient(gradient([(0xFFFFFF, 0.9, 0), (0xFFC58A, 0.35, 0.4), (0xFFC58A, 0, 1)]),
                                   startCenter: CGPoint(x: x, y: y), startRadius: 0,
                                   endCenter: CGPoint(x: x, y: y), endRadius: 70, options: [])
        }
        let alpha: CGFloat = today ? 1 : 0.38 + 0.12 * CGFloat(rows - r)
        ctx.setFillColor(color(0xFFFFFF, alpha))
        ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }
}

// Sun disc, clipped at the horizon
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: horizon, width: 1024, height: 1024))
let sunR: CGFloat = 150
ctx.addEllipse(in: CGRect(x: 512 - sunR, y: horizon - sunR, width: sunR * 2, height: sunR * 2))
ctx.clip()
ctx.drawLinearGradient(gradient([(0xFFF0B0, 1, 0), (0xFFB257, 1, 0.6), (0xFF7A55, 1, 1)]),
                       start: CGPoint(x: 512, y: horizon + sunR), end: CGPoint(x: 512, y: horizon), options: [])
ctx.restoreGState()

// Water
ctx.drawLinearGradient(gradient([(0x3A2557, 1, 0), (0x161A38, 1, 0.55), (0x0D1128, 1, 1)]),
                       start: CGPoint(x: 512, y: horizon), end: CGPoint(x: 512, y: 100), options: [])

// Reflection of the sun
for i in 0..<6 {
    let y = horizon - 34 - CGFloat(i) * 42
    let w = 300 - CGFloat(i) * 46
    let h: CGFloat = 13 - CGFloat(i)
    ctx.setFillColor(color(0xFFB45E, 0.75 - CGFloat(i) * 0.11))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 512 - w / 2, y: y, width: w, height: h),
                       cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
    ctx.fillPath()
}

// Horizon line
ctx.setFillColor(color(0xFFE2B0, 0.9))
ctx.fill(CGRect(x: 100, y: horizon - 2, width: 824, height: 4))
ctx.restoreGState()

// Rim light
ctx.addPath(CGPath(roundedRect: tile.insetBy(dx: 1.5, dy: 1.5), cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.setStrokeColor(color(0xFFFFFF, 0.14)); ctx.setLineWidth(3); ctx.strokePath()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
