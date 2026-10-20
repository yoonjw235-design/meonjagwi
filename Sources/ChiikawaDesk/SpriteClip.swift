import AppKit
import ImageIO
import PetGeometry

/// Original GIF frames and timing. PNG/GIF files on disk remain unchanged.
final class SpriteClip {
    let frames: [NSImage]
    let frameEnds: [TimeInterval]
    let duration: TimeInterval
    let sourceSize: CGSize
    init?(url: URL, playbackScale: Double = 1) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        var images: [NSImage] = [], ends: [TimeInterval] = []
        var elapsed: TimeInterval = 0
        var coatReference: CoatTone?
        var size = CGSize.zero
        for index in 0..<CGImageSourceGetCount(source) {
            guard let original = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            let cg = url.lastPathComponent.hasPrefix("Usagi ") ? CoatNormalizer.normalize(original, reference: &coatReference) : original
            size = CGSize(width: cg.width, height: cg.height)
            images.append(NSImage(cgImage: cg, size: size))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            elapsed += max(0.02, delay) * playbackScale
            ends.append(elapsed)
        }
        guard !images.isEmpty else { return nil }
        frames = images; frameEnds = ends; duration = elapsed; sourceSize = size
    }
    func frameIndex(at elapsed: TimeInterval) -> Int {
        let time = max(0, elapsed).truncatingRemainder(dividingBy: duration)
        return frameEnds.firstIndex(where: { $0 > time }) ?? 0
    }
    func image(at elapsed: TimeInterval) -> NSImage { frames[frameIndex(at: elapsed)] }
    func draw(pose: String, elapsed: TimeInterval, baseline: CGFloat, width: CGFloat, character: CharacterKind = .hachiware) {
        let crop: CGRect
        let target: CGSize
        var belowBaseline: CGFloat = 0
        // Crops are unions across every frame, so ears and tails don't change scale.
        if character == .usagi {
            switch pose {
            case "held": crop = CGRect(x: 41, y: 85, width: 597, height: 389); target = CGSize(width: 142, height: 142 * 389 / 597)
            case "rest":
                crop = CGRect(x: 26, y: 52, width: 226, height: 206)
                target = CGSize(width: 103, height: 103 * 206 / 226)
                // The original shifts the whole body vertically as the ears move.
                // Keep the body grounded without changing frame timing or size.
                let bottoms: [CGFloat] = [258, 253, 245, 245, 246, 246, 246, 246, 245, 246, 257, 257]
                belowBaseline = (258 - bottoms[min(frameIndex(at: elapsed), bottoms.count - 1)]) * 103 / 226
            case "happy": crop = CGRect(x: 22, y: 21, width: 265, height: 263); target = CGSize(width: 104 * 1.2, height: 104 * 1.2 * 263 / 265)
            case "run": crop = CGRect(x: 33, y: 2, width: 208, height: 316); target = CGSize(width: 128 * 1.08 * 208 / 316, height: 128 * 1.08)
            case "notify": crop = CGRect(x: 56, y: 19, width: 329, height: 454); target = CGSize(width: 126 * 329 / 454, height: 126)
            case "fall", "jump": crop = CGRect(x: 118, y: 42, width: 886, height: 1267); target = CGSize(width: 125 * 886 / 1267, height: 125)
            default: crop = CGRect(x: 63, y: 27, width: 234, height: 325); target = CGSize(width: 124 * 234 / 325, height: 124)
            }
        } else {
        switch pose {
        case "held": crop = CGRect(x: 61, y: 40, width: 359, height: 401); target = CGSize(width: 89.5 * 0.9, height: 100 * 0.9)
        case "rest":
            crop = CGRect(x: 24, y: 45, width: 246, height: 218)
            target = CGSize(width: 101 * 0.945 * 1.015, height: 101 * 0.945 * 1.015 * 218 / 246)
            // Body and feet meet original y=239; tail extends to y=263.
            belowBaseline = 101 * 0.945 * 1.015 * (263 - 239) / 246
        case "happy": crop = CGRect(x: 53, y: 11, width: 400, height: 487); target = CGSize(width: 80.5 * 1.1, height: 98 * 1.1)
        case "run": crop = CGRect(x: 20, y: 31, width: 262, height: 288); target = CGSize(width: 91, height: 100)
        case "notify": crop = CGRect(x: 49, y: 8, width: 230, height: 280); target = CGSize(width: 80.5, height: 98)
        case "fall", "jump": crop = CGRect(x: 49, y: 56, width: 1304, height: 1064); target = CGSize(width: 108, height: 108 * 1064 / 1304)
        default: crop = CGRect(x: 8, y: 8, width: 229, height: 278); target = CGSize(width: 79 * 1.12, height: 96 * 1.12)
        }
        }
        let source = CGRect(x: crop.minX, y: sourceSize.height - crop.maxY, width: crop.width, height: crop.height)
        let destination = CGRect(x: (width - target.width) / 2, y: baseline - belowBaseline, width: target.width, height: target.height)
        image(at: elapsed).draw(in: destination, from: source, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    }
}
