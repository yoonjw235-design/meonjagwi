import CoreGraphics
import PetGeometry

/// Runtime coat matching preserves the original assets, GIF timing, alpha,
/// dark outlines and pink cheeks/ears. Reference is fixed per clip, not per frame.
enum CoatNormalizer {
    static func normalize(_ image: CGImage, reference: inout CoatTone?) -> CGImage {
        let width = image.width, height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let raw = context.data else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let bytes = raw.bindMemory(to: UInt8.self, capacity: width * height * 4)
        func rgb(_ i: Int) -> (Double, Double, Double) {
            let factor = 255 / Double(max(1, bytes[i + 3]))
            return (Double(bytes[i]) * factor, Double(bytes[i + 1]) * factor, Double(bytes[i + 2]) * factor)
        }
        if reference == nil {
            var histogram = Array(repeating: Array(repeating: 0, count: 256), count: 3)
            var count = 0
            for i in stride(from: 0, to: width * height * 4, by: 4) where bytes[i + 3] > 200 {
                let (r, g, b) = rgb(i)
                guard CoatTone.isYellowCoat(r, g, b) else { continue }
                histogram[0][min(255, Int(r.rounded()))] += 1
                histogram[1][min(255, Int(g.rounded()))] += 1
                histogram[2][min(255, Int(b.rounded()))] += 1
                count += 1
            }
            guard count > 0 else { return image }
            func median(_ channel: Int) -> Double {
                var sum = 0
                for value in 0..<256 { sum += histogram[channel][value]; if sum >= (count + 1) / 2 { return Double(value) } }
                return 255
            }
            reference = CoatTone(median(0), median(1), median(2))
        }
        guard let reference else { return image }
        for i in stride(from: 0, to: width * height * 4, by: 4) where bytes[i + 3] > 8 {
            let (r, g, b) = rgb(i)
            guard CoatTone.isYellowCoat(r, g, b) else { continue }
            let color = CoatTone.matched(r, g, b, reference: reference)
            let alpha = Double(bytes[i + 3]) / 255
            bytes[i] = UInt8(min(255, max(0, (color.0 * alpha).rounded())))
            bytes[i + 1] = UInt8(min(255, max(0, (color.1 * alpha).rounded())))
            bytes[i + 2] = UInt8(min(255, max(0, (color.2 * alpha).rounded())))
        }
        return context.makeImage() ?? image
    }
}
