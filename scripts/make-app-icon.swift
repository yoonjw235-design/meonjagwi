import AppKit
import Foundation

guard CommandLine.arguments.count == 3,
      let image = NSImage(contentsOfFile: CommandLine.arguments[1]) else { fatalError("Icon source is missing") }
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let size = CGFloat(pixels)
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.21, yRadius: size * 0.21).addClip()
        // Draw a corner pixel through the same color-profile path as the banner.
        image.draw(in: CGRect(x: 0, y: 0, width: size, height: size),
                   from: CGRect(x: 0, y: 0, width: 1, height: 1), operation: .sourceOver, fraction: 1)
        let width = size * 0.94
        let height = width * image.size.height / image.size.width
        image.draw(in: CGRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height),
                   from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let name = "icon_\(points)x\(points)\(suffix).png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
    }
}
print("App icon sizes generated")
