//
//  SubjectColorMatch.swift
//  AutoCapture
//
//  Relights a lifted subject toward the tone of the background it's being
//  composited onto, so it reads as part of the scene instead of a cut-out.
//  Two nudges are applied: a luminance-preserving white-balance correction so
//  the subject picks up the environment's color cast, and a gentle exposure
//  match so it isn't obviously brighter or darker than its surroundings. Both
//  are deliberately subtle and scaled by a caller-supplied strength so the
//  effect can be tuned (or disabled) without ever fully repainting the subject.
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

enum SubjectColorMatch {
    /// Average tone of a region, in straight (un-premultiplied) 0...1 RGB.
    struct Tone: Equatable {
        var r: CGFloat
        var g: CGFloat
        var b: CGFloat

        /// Rec.709 relative luminance.
        var luminance: CGFloat { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    }

    // Base correction amounts, before the caller's global strength multiplier.
    // Kept low so the subject keeps its own identity — we're nudging it into the
    // light, not recoloring it to match the floor.
    private static let baseWhiteBalanceStrength: CGFloat = 0.35
    private static let baseExposureStrength: CGFloat = 0.22

    // The background is sampled over its lower-center floor — the surface the
    // subject actually sits on and takes its bounce light from — rather than the
    // whole frame, which may include bright ceilings or dark walls.
    private static let floorSampleRegion = CGRect(x: 0.12, y: 0.5, width: 0.76, height: 0.48)

    private static let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])

    /// Average tone of the background's floor region.
    static func backgroundTone(of image: UIImage) -> Tone? {
        averageTone(of: image, in: floorSampleRegion)
    }

    /// Returns a copy of `subject` nudged toward `target`, or the original image
    /// when the correction would be a no-op or can't be computed. `strength`
    /// scales the whole effect (0 = untouched, 1 = the default nudge).
    static func matched(subject: UIImage, toward target: Tone, strength: CGFloat) -> UIImage {
        guard strength > 0 else { return subject }
        guard let source = averageTone(of: subject, in: nil), source.luminance > 0.004,
              target.luminance > 0.004 else { return subject }

        // Luminance-preserving white balance: match the subject's per-channel
        // chroma ratios to the target's, so it inherits the environment's cast
        // without changing its own brightness.
        func whiteBalanceGain(_ subjectChannel: CGFloat, _ targetChannel: CGFloat) -> CGFloat {
            let subjectRatio = subjectChannel / source.luminance
            guard subjectRatio > 0.004 else { return 1 }
            let targetRatio = targetChannel / target.luminance
            return clamp(targetRatio / subjectRatio, min: 0.6, max: 1.6)
        }

        let wbR = whiteBalanceGain(source.r, target.r)
        let wbG = whiteBalanceGain(source.g, target.g)
        let wbB = whiteBalanceGain(source.b, target.b)
        let exposure = clamp(target.luminance / source.luminance, min: 0.65, max: 1.5)

        let wbStrength = baseWhiteBalanceStrength * strength
        let exposureStrength = baseExposureStrength * strength
        func blend(_ gain: CGFloat, _ amount: CGFloat) -> CGFloat { 1 + (gain - 1) * amount }

        let gainR = clamp(blend(wbR, wbStrength) * blend(exposure, exposureStrength), min: 0.5, max: 1.9)
        let gainG = clamp(blend(wbG, wbStrength) * blend(exposure, exposureStrength), min: 0.5, max: 1.9)
        let gainB = clamp(blend(wbB, wbStrength) * blend(exposure, exposureStrength), min: 0.5, max: 1.9)

        // Nothing meaningful to do — avoid an expensive round-trip.
        if abs(gainR - 1) < 0.01, abs(gainG - 1) < 0.01, abs(gainB - 1) < 0.01 {
            return subject
        }

        return applyChannelGains(to: subject, r: gainR, g: gainG, b: gainB) ?? subject
    }

    // MARK: - Sampling

    /// Alpha-weighted average color of `image` (optionally restricted to a unit
    /// rect). Transparent pixels of a lifted subject contribute nothing, so the
    /// result reflects only the visible subject, not its cut-out frame.
    private static func averageTone(of image: UIImage, in unitRect: CGRect?) -> Tone? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }

        // A small downsample is plenty for an average and keeps the scan cheap.
        let maxDim = 140.0
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

        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()

        let minX = unitRect.map { max(0, Int((Double($0.minX) * Double(w)).rounded(.down))) } ?? 0
        let maxX = unitRect.map { min(w, Int((Double($0.maxX) * Double(w)).rounded(.up))) } ?? w
        let minY = unitRect.map { max(0, Int((Double($0.minY) * Double(h)).rounded(.down))) } ?? 0
        let maxY = unitRect.map { min(h, Int((Double($0.maxY) * Double(h)).rounded(.up))) } ?? h
        guard maxX > minX, maxY > minY else { return nil }

        // Pixels are premultiplied, so summing RGB and dividing by summed alpha
        // yields the alpha-weighted average of the straight (un-premultiplied)
        // color — exactly the visible-coverage average we want.
        var sumR = 0.0, sumG = 0.0, sumB = 0.0, sumA = 0.0
        for y in minY..<maxY {
            let row = y * bytesPerRow
            for x in minX..<maxX {
                let p = row + x * 4
                sumR += Double(data[p])
                sumG += Double(data[p + 1])
                sumB += Double(data[p + 2])
                sumA += Double(data[p + 3])
            }
        }
        guard sumA > 0 else { return nil }
        return Tone(r: CGFloat(sumR / sumA), g: CGFloat(sumG / sumA), b: CGFloat(sumB / sumA))
    }

    // MARK: - Applying

    private static func applyChannelGains(to image: UIImage, r: CGFloat, g: CGFloat, b: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.colorMatrix()
        filter.inputImage = ciImage
        filter.rVector = CIVector(x: r, y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: g, z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: b, w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Helpers

    private static func clamp(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(hi, Swift.max(lo, value))
    }
}
