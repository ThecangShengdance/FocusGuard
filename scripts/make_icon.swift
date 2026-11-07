#!/usr/bin/env swift

// 生成 FocusGuard 的 AppIcon 资源。
// 用法：在项目根目录执行 `swift scripts/make_icon.swift`

import AppKit
import Foundation

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsURL = root.appendingPathComponent("Sources/Resources/Assets.xcassets")
let iconSetURL = assetsURL.appendingPathComponent("AppIcon.appiconset")

try fileManager.createDirectory(at: iconSetURL, withIntermediateDirectories: true)

let catalogContents = """
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try catalogContents.write(to: assetsURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255
    let g = CGFloat((hex >> 8) & 0xFF) / 255
    let b = CGFloat(hex & 0xFF) / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawIcon(size: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "FocusGuardIcon", code: 1)
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "FocusGuardIcon", code: 2)
    }
    NSGraphicsContext.current = graphics
    let ctx = graphics.cgContext
    ctx.setShouldAntialias(true)
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let s = CGFloat(size)
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let corner = rect.width * 0.225
    let background = CGPath(
        roundedRect: rect,
        cornerWidth: corner,
        cornerHeight: corner,
        transform: nil
    )

    ctx.saveGState()
    ctx.addPath(background)
    ctx.clip()

    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            color(0xFF9A5C).cgColor,
            color(0xF15A34).cgColor,
            color(0xD83220).cgColor
        ] as CFArray,
        locations: [0, 0.52, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )

    let glow = CGGradient(
        colorsSpace: space,
        colors: [
            NSColor.white.withAlphaComponent(0.22).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.12),
        startRadius: 0,
        endCenter: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.maxY - rect.height * 0.12),
        endRadius: rect.width * 0.72,
        options: []
    )

    let center = CGPoint(x: s / 2, y: s / 2)
    let radius = s * 0.285
    let white = NSColor(srgbRed: 1, green: 0.98, blue: 0.94, alpha: 1)

    // 时钟外环，在两点钟方向留出缺口
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.13).cgColor)
    ctx.setLineWidth(s * 0.078)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: radius, startAngle: .pi * 0.31, endAngle: .pi * 2.21, clockwise: false)
    ctx.strokePath()

    ctx.setStrokeColor(white.cgColor)
    ctx.setLineWidth(s * 0.062)
    ctx.setLineCap(.round)
    ctx.addArc(center: center, radius: radius, startAngle: .pi * 0.31, endAngle: .pi * 2.21, clockwise: false)
    ctx.strokePath()

    // 指针
    ctx.setStrokeColor(white.cgColor)
    ctx.setLineWidth(s * 0.058)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: center.x, y: center.y - radius * 0.05))
    ctx.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.58))
    ctx.strokePath()

    ctx.setLineWidth(s * 0.05)
    ctx.move(to: CGPoint(x: center.x, y: center.y))
    ctx.addLine(to: CGPoint(x: center.x + radius * 0.40, y: center.y - radius * 0.16))
    ctx.strokePath()

    // 中心点
    ctx.setFillColor(white.cgColor)
    let dot = s * 0.038
    ctx.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))

    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "FocusGuardIcon", code: 3)
    }
    try data.write(to: url)
}

struct IconEntry {
    let pointSize: Int
    let scale: Int
    let filename: String
}

let entries: [IconEntry] = [
    IconEntry(pointSize: 16, scale: 1, filename: "icon_16x16.png"),
    IconEntry(pointSize: 16, scale: 2, filename: "icon_16x16@2x.png"),
    IconEntry(pointSize: 32, scale: 1, filename: "icon_32x32.png"),
    IconEntry(pointSize: 32, scale: 2, filename: "icon_32x32@2x.png"),
    IconEntry(pointSize: 128, scale: 1, filename: "icon_128x128.png"),
    IconEntry(pointSize: 128, scale: 2, filename: "icon_128x128@2x.png"),
    IconEntry(pointSize: 256, scale: 1, filename: "icon_256x256.png"),
    IconEntry(pointSize: 256, scale: 2, filename: "icon_256x256@2x.png"),
    IconEntry(pointSize: 512, scale: 1, filename: "icon_512x512.png"),
    IconEntry(pointSize: 512, scale: 2, filename: "icon_512x512@2x.png")
]

for entry in entries {
    let pixels = entry.pointSize * entry.scale
    try drawIcon(size: pixels, to: iconSetURL.appendingPathComponent(entry.filename))
    print("generated \(entry.filename) (\(pixels)×\(pixels))")
}

var imageJSON: [String] = []
for entry in entries {
    imageJSON.append("""
        {
          "filename" : "\(entry.filename)",
          "idiom" : "mac",
          "scale" : "\(entry.scale)x",
          "size" : "\(entry.pointSize)x\(entry.pointSize)"
        }
    """)
}

let iconContents = """
{
  "images" : [
\(imageJSON.joined(separator: ",\n"))
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try iconContents.write(to: iconSetURL.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote Contents.json")
