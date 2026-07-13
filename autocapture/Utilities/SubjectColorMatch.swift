//
//  SubjectColorMatch.swift
//  AutoCapture
//
//  Relights a lifted subject toward the tone of the background it's being
//  composited onto, so it reads as part of the scene instead of a cut-out.
//  Four coordinated moves are applied, all scaled by a caller-supplied strength:
//    1. Saturation harmonization — pull the subject's chroma partway toward the
//       environment's, so a hyper-saturated cut-out stops screaming.
//    2. Contrast compression — soften the subject's tonal range toward the flat
//       ambient of a diffuse room, taming glossy speculars and crushed blacks.
//    3. Luminance-preserving white balance + a gentle exposure match — the
//       subject inherits the environment's color cast and brightness.
//    4. An ambient "veil" — lerp the whole subject a few percent toward the
//       background color, lifting/tinting its blacks and adding the room's haze.
//  A per-channel average white balance alone is invisible on a saturated hero
//  color (the dominant channel is clamped and then cancelled by the exposure
//  lift); the saturation/contrast/veil terms are what actually dissolve the
//  cut-out look. Everything is tuned so 100% strength is clearly visible yet
//  photoreal, and all color work happens in straight-alpha space so transparent
//  and anti-aliased edge pixels are never miscolored.
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
    // White balance + exposure keep the subject's identity; the saturation,
    // contrast and veil terms are what actually dissolve the cut-out look.
    private static let baseWhiteBalanceStrength: CGFloat = 0.35
    private static let baseExposureStrength: CGFloat = 0.22
    private static let basePull: CGFloat = 0.50          // fraction of the chroma gap to close
    private static let baseContrastDrop: CGFloat = 0.15  // how far to flatten toward ambient
    private static let baseVeil: CGFloat = 0.06          // ambient haze / shadow-lift amount

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

        // --- White balance + exposure (luminance-preserving nudge) ---
        // Match the subject's per-channel chroma ratios to the target's without
        // changing its own brightness, then a mild exposure match on top.
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

        // --- Saturation harmonization ---
        // Close part of the chroma gap between subject and background. satFactor
        // scales chroma ~linearly (CIColorControls lerps toward luma-gray), so
        // the target/current ratio is the right multiplier. Floored at 0.55 so a
        // red car stays clearly red; ceilinged at 1.10 for the rare flat subject.
        let sSubj = saturation(of: source)
        let sBg = saturation(of: target)
        let pull = basePull * strength
        let sTarget = sSubj - pull * (sSubj - sBg)
        let satFactor = sSubj > 0.01 ? clamp(sTarget / sSubj, min: 0.55, max: 1.10) : 1

        // --- Contrast compression toward the flat ambient ---
        let contrastFactor = clamp(1 - baseContrastDrop * strength, min: 0.55, max: 1.0)

        // --- Ambient veil (shadow lift + haze), tinted by the background tone ---
        let veil = clamp(baseVeil * strength, min: 0, max: 0.18)

        // Nothing meaningful to do — avoid an expensive round-trip.
        if abs(satFactor - 1) < 0.01, abs(contrastFactor - 1) < 0.01, veil < 0.005,
           abs(gainR - 1) < 0.01, abs(gainG - 1) < 0.01, abs(gainB - 1) < 0.01 {
            return subject
        }

        return applyRelight(
            to: subject,
            satFactor: satFactor,
            contrast: contrastFactor,
            gainR: gainR, gainG: gainG, gainB: gainB,
            veil: veil,
            ambient: target
        ) ?? subject
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

    /// Ordered chain: reshape the subject's own tonal frame (saturation +
    /// contrast) first, align it to the environment (per-channel gains), then let
    /// the atmosphere (veil) sit last — all in straight-alpha space so edges and
    /// transparent pixels keep correct color and coverage.
    private static func applyRelight(
        to image: UIImage,
        satFactor: CGFloat,
        contrast: CGFloat,
        gainR: CGFloat, gainG: CGFloat, gainB: CGFloat,
        veil: CGFloat,
        ambient: Tone
    ) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Straight-alpha: the contrast pivot (0.5) and the veil bias are additive
        // terms that would miscolor premultiplied transparent/edge pixels.
        let straight = ciImage.unpremultiplyingAlpha()

        let tone = CIFilter.colorControls()
        tone.inputImage = straight
        tone.saturation = Float(satFactor)
        tone.contrast = Float(contrast)
        tone.brightness = 0
        guard let toned = tone.outputImage else { return nil }

        // out = (in · gain) · (1 - veil) + veil · ambient
        let k = 1 - veil
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = toned
        matrix.rVector = CIVector(x: gainR * k, y: 0, z: 0, w: 0)
        matrix.gVector = CIVector(x: 0, y: gainG * k, z: 0, w: 0)
        matrix.bVector = CIVector(x: 0, y: 0, z: gainB * k, w: 0)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: veil * ambient.r, y: veil * ambient.g, z: veil * ambient.b, w: 0)
        guard let matched = matrix.outputImage else { return nil }

        let output = matched.premultiplyingAlpha()
        guard let cgImage = ciContext.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    // MARK: - Helpers

    /// HSV saturation of a tone: 0 for neutral gray, →1 for a pure hue. Symmetric
    /// for subject and background, so no extra sampling is needed.
    private static func saturation(of tone: Tone) -> CGFloat {
        let mx = max(tone.r, max(tone.g, tone.b))
        let mn = min(tone.r, min(tone.g, tone.b))
        return mx > 0.004 ? (mx - mn) / mx : 0
    }

    private static func clamp(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        Swift.min(hi, Swift.max(lo, value))
    }
}
