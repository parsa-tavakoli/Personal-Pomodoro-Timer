// Turns Resources/logo.png (a rounded tile on a white background) into a macOS AppIcon.icns.
// Usage: swift scripts/make_icon.swift Resources/logo.png Resources/AppIcon.icns
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else {
    print("usage: make_icon.swift <input.png> <output.icns>")
    exit(1)
}
let input = URL(fileURLWithPath: args[1])
let output = URL(fileURLWithPath: args[2])

guard let source = NSImage(contentsOf: input)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("could not read \(input.path)")
    exit(1)
}

// Render into a known RGBA buffer so we can scan pixels.
let w = source.width, h = source.height
var pixels = [UInt8](repeating: 0, count: w * h * 4)
let space = CGColorSpaceCreateDeviceRGB()
let scan = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                     space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
scan.draw(source, in: CGRect(x: 0, y: 0, width: w, height: h))

// Bounding box of the tile: anything that isn't near-white or transparent.
var minX = w, minY = h, maxX = -1, maxY = -1
for y in 0..<h {
    for x in 0..<w {
        let i = (y * w + x) * 4
        let (r, g, b, a) = (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
        guard a > 20, !(r > 235 && g > 235 && b > 235) else { continue }
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX > minX, maxY > minY else { print("no tile found"); exit(1) }

// Trim a few pixels to drop the anti-aliased white fringe. Buffer rows run top-down.
let inset = 3
let crop = CGRect(x: minX + inset, y: minY + inset,
                  width: maxX - minX - 2 * inset, height: maxY - minY - 2 * inset)
let tile = source.cropping(to: crop)!

/// Draws the tile on a transparent square canvas using the standard macOS icon grid
/// (824/1024 content, ~22% corner radius), scaling to fill and clipping the corners.
func renderIcon(size: Int) -> Data {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let s = CGFloat(size)
    let content = s * 824 / 1024
    let box = CGRect(x: (s - content) / 2, y: (s - content) / 2, width: content, height: content)
    ctx.addPath(CGPath(roundedRect: box, cornerWidth: content * 0.225, cornerHeight: content * 0.225, transform: nil))
    ctx.clip()

    let scale = max(content / CGFloat(tile.width), content / CGFloat(tile.height))
    let dw = CGFloat(tile.width) * scale, dh = CGFloat(tile.height) * scale
    ctx.draw(tile, in: CGRect(x: box.midX - dw / 2, y: box.midY - dh / 2, width: dw, height: dh))

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try! renderIcon(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! renderIcon(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try! iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { print("iconutil failed"); exit(1) }

print("Wrote \(output.path) (tile \(Int(crop.width))x\(Int(crop.height)) from \(w)x\(h))")
print("Preview: \(iconset.appendingPathComponent("icon_512x512@2x.png").path)")
