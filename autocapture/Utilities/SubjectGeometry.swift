//
//  SubjectGeometry.swift
//  AutoCapture
//

import CoreGraphics
import UIKit

/// Helpers for locating the actual (non-transparent) footprint of a lifted
/// subject within its image, so effects like the contact shadow can hug the
/// subject instead of anchoring to the transparent image frame.
enum SubjectGeometry {
    /// Bounding box of the subject's non-transparent pixels, in the image's
    /// point coordinate space (origin top-left). Returns nil when the image has
    /// no usable alpha — callers should fall back to the full image bounds.
    static func opaqueBounds(of image: UIImage) -> CGRect? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        // Scan a downsampled copy — subject silhouettes don't need full
        // resolution to find their bounds, and this keeps the scan cheap.
        let maxDim = 200.0
        let longest = max(image.size.width, image.size.height)
        let scale = min(1.0, maxDim / Double(longest))
        let w = max(1, Int((Double(image.size.width) * scale).rounded()))
        let h = max(1, Int((Double(image.size.height) * scale).rounded()))
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: bytesPerRow * h)

        guard let ctx = CGContext(
            data: &data,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Flip to a UIKit (top-left, y-down) space so UIImage.draw renders the
        // subject upright and memory row 0 is the top of the image.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()

        let threshold: UInt8 = 12
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * bytesPerRow
            for x in 0..<w where data[row + x * 4 + 3] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        let sx = image.size.width / Double(w)
        let sy = image.size.height / Double(h)
        return CGRect(
            x: Double(minX) * sx,
            y: Double(minY) * sy,
            width: Double(maxX - minX + 1) * sx,
            height: Double(maxY - minY + 1) * sy
        )
    }

    /// `opaqueBounds` expressed as fractions (0...1) of the image size, for
    /// positioning overlays relative to a laid-out image view.
    static func normalizedOpaqueBounds(of image: UIImage) -> CGRect? {
        guard let bounds = opaqueBounds(of: image),
              image.size.width > 0, image.size.height > 0 else { return nil }
        return CGRect(
            x: bounds.minX / image.size.width,
            y: bounds.minY / image.size.height,
            width: bounds.width / image.size.width,
            height: bounds.height / image.size.height
        )
    }
}
