//
//  BackgroundRemovalService.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import Accelerate
import CoreImage
import UIKit
import Vision

struct ForegroundExtractionResult {
    let foregroundImage: UIImage
    let maskImage: UIImage
    let originalImage: UIImage
}

class BackgroundRemovalService {
    private let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])

    func extractForeground(from image: UIImage, allowMultipleSubjects: Bool) async throws -> ForegroundExtractionResult {
        guard let cgImage = image.cgImage else {
            throw CameraError.backgroundRemovalFailed
        }

        // Create the request for subject masking with optimized settings
        let request = VNGenerateForegroundInstanceMaskRequest()

        // Perform the request with high-quality options
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [
            .ciContext: context
        ])
        try handler.perform([request])

        guard let result = request.results?.first else {
            throw CameraError.noSubjectDetected
        }

        let instances = result.allInstances
        let instanceCount = instances.count

        guard instanceCount > 0 else {
            throw CameraError.noSubjectDetected
        }

        if !allowMultipleSubjects, instanceCount > 1 {
            throw CameraError.multipleSubjectsDetected
        }

        // Get the pixel buffer from the observation
        let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: instances, from: handler)

        // Convert mask to CIImage
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        // Create original image as CIImage
        let originalImage = CIImage(cgImage: cgImage)

        // Refine the mask for cleaner edges
        maskImage = refineMask(maskImage)

        // Apply the mask to create the final composited image
        let compositedImage = try applyMaskWithFeathering(mask: maskImage, to: originalImage)

        // Convert back to UIImage
        guard let outputCGImage = context.createCGImage(compositedImage, from: compositedImage.extent) else {
            throw CameraError.backgroundRemovalFailed
        }

        guard let maskCGImage = context.createCGImage(maskImage, from: maskImage.extent) else {
            throw CameraError.backgroundRemovalFailed
        }

        let foregroundImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        let maskUIImage = UIImage(cgImage: maskCGImage, scale: image.scale, orientation: image.imageOrientation)

        return ForegroundExtractionResult(
            foregroundImage: foregroundImage,
            maskImage: maskUIImage,
            originalImage: image
        )
    }

    func apply(mask: UIImage, to image: UIImage) throws -> UIImage {
        guard let maskCGImage = mask.cgImage else {
            throw CameraError.backgroundRemovalFailed
        }

        guard let maskCIImage = CIImage(cgImage: maskCGImage).clampedToExtent(),
              let originalCGImage = image.cgImage else {
            throw CameraError.backgroundRemovalFailed
        }

        let originalCIImage = CIImage(cgImage: originalCGImage)

        let compositedImage = try applyMaskWithFeathering(mask: maskCIImage, to: originalCIImage)

        guard let outputCGImage = context.createCGImage(compositedImage, from: compositedImage.extent) else {
            throw CameraError.backgroundRemovalFailed
        }

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Refines the mask using morphological operations and smoothing
    private func refineMask(_ mask: CIImage) -> CIImage {
        var refinedMask = mask

        // 1. Initial erosion to tighten the mask and pull edges inward
        if let morphologyFilter = CIFilter(name: "CIMorphologyMinimum") {
            morphologyFilter.setValue(refinedMask, forKey: kCIInputImageKey)
            morphologyFilter.setValue(3.0, forKey: kCIInputRadiusKey) // Aggressive edge tightening
            if let eroded = morphologyFilter.outputImage {
                refinedMask = eroded
            }
        }

        // 2. Small dilation to recover some detail (but less than erosion)
        if let morphologyFilter = CIFilter(name: "CIMorphologyMaximum") {
            morphologyFilter.setValue(refinedMask, forKey: kCIInputImageKey)
            morphologyFilter.setValue(1.5, forKey: kCIInputRadiusKey) // Gentle recovery
            if let dilated = morphologyFilter.outputImage {
                refinedMask = dilated
            }
        }

        // 3. Gamma adjustment to tighten boundaries (Apple's technique)
        if let gammaFilter = CIFilter(name: "CIGammaAdjust") {
            gammaFilter.setValue(refinedMask, forKey: kCIInputImageKey)
            gammaFilter.setValue(0.75, forKey: "inputPower") // <1.0 darkens/tightens mask
            if let gamma = gammaFilter.outputImage {
                refinedMask = gamma
            }
        }

        // 4. Apply Gaussian blur for smooth, feathered edges
        if let blurFilter = CIFilter(name: "CIGaussianBlur") {
            blurFilter.setValue(refinedMask, forKey: kCIInputImageKey)
            blurFilter.setValue(2.5, forKey: kCIInputRadiusKey) // Reduced for tighter fit
            if let blurred = blurFilter.outputImage {
                refinedMask = blurred
            }
        }

        // 5. Adjust contrast to sharpen the transition zone
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(refinedMask, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.3, forKey: kCIInputContrastKey) // Increased for definition
            if let contrasted = contrastFilter.outputImage {
                refinedMask = contrasted
            }
        }

        return refinedMask
    }

    /// Applies the mask with proper feathering for clean, natural edges
    private func applyMaskWithFeathering(mask: CIImage, to image: CIImage) throws -> CIImage {
        // Scale mask to match image size using bicubic interpolation (highest quality)
        let scaleX = image.extent.width / mask.extent.width
        let scaleY = image.extent.height / mask.extent.height

        // Use bicubic scaling for smoother results
        var scaledMask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Apply lanczos scale filter for even better quality
        if let scaleFilter = CIFilter(name: "CILanczosScaleTransform") {
            scaleFilter.setValue(mask, forKey: kCIInputImageKey)
            scaleFilter.setValue(scaleX, forKey: kCIInputScaleKey)
            scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let scaled = scaleFilter.outputImage {
                scaledMask = scaled
            }
        }

        // Create a transparent background
        let transparent = CIImage(color: .clear).cropped(to: image.extent)

        // Use the mask to blend the original image with transparency
        // This creates smooth alpha transitions at edges
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            throw CameraError.backgroundRemovalFailed
        }

        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(transparent, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)

        guard let outputImage = blendFilter.outputImage else {
            throw CameraError.backgroundRemovalFailed
        }

        // Apply subtle edge enhancement for crisper details
        guard let sharpenFilter = CIFilter(name: "CIUnsharpMask") else {
            return outputImage
        }

        sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.6, forKey: kCIInputRadiusKey) // Slightly increased
        sharpenFilter.setValue(0.4, forKey: kCIInputIntensityKey) // More sharpening

        return sharpenFilter.outputImage ?? outputImage
    }
}
