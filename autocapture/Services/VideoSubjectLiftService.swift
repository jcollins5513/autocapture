//
//  VideoSubjectLiftService.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import AVFoundation
import CoreImage
import CoreMedia
import OSLog
import UIKit
import Vision
import VideoToolbox

struct VideoLiftResult {
    let outputURL: URL
    /// False when the device could not encode HEVC with alpha and the subject
    /// was flattened onto the requested fallback color instead.
    let hasAlphaChannel: Bool
    let duration: Double
}

/// Runs the same Vision foreground-instance mask used for stills across every
/// frame of a movie, writing a new movie that contains only the subject.
final class VideoSubjectLiftService {
    /// What sits behind the lifted subject in the rendered movie.
    enum Background {
        /// Real transparency via HEVC with alpha, falling back to `.color(.black)`
        /// when the device cannot encode it.
        case transparent
        case color(CIColor)
        case image(UIImage)
    }

    struct Options {
        var allowMultipleSubjects: Bool = true
        var background: Background = .transparent
        /// Frames are scaled so the longest side is at most this many pixels
        /// before masking; subject lifting on full 4K frames is far too slow for
        /// a usable capture loop.
        var maximumDimension: CGFloat = 1_920

        init(
            allowMultipleSubjects: Bool = true,
            background: Background = .transparent,
            maximumDimension: CGFloat = 1_920
        ) {
            self.allowMultipleSubjects = allowMultipleSubjects
            self.background = background
            self.maximumDimension = maximumDimension
        }
    }

    private let logger = Logger(subsystem: "com.autocapture", category: "VideoSubjectLiftService")
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private let processingQueue = DispatchQueue(label: "com.autocapture.videoLift", qos: .userInitiated)

    // MARK: - Entry point

    /// Lifts the subject out of every frame of `sourceURL`.
    /// - Parameter progress: called on an arbitrary queue with 0...1 completion.
    /// - Returns: the URL of the rendered movie inside `VideoFileStore`.
    func liftSubject(
        from sourceURL: URL,
        options: Options = Options(),
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> VideoLiftResult {
        let asset = AVURLAsset(url: sourceURL)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw CameraError.videoTrackMissing
        }

        let duration = CMTimeGetSeconds(try await asset.load(.duration))
        let naturalSize = try await videoTrack.load(.naturalSize)
        let preferredTransform = try await videoTrack.load(.preferredTransform)
        let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
        let renderSize = Self.renderSize(for: naturalSize, maximumDimension: options.maximumDimension)

        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first

        let reader = try AVAssetReader(asset: asset)
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else { throw CameraError.videoProcessingFailed }
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            if reader.canAdd(output) {
                reader.add(output)
                audioOutput = output
            }
        }

        let outputURL = VideoFileStore.makeDestinationURL(extension: "mov")
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let wantsAlpha: Bool
        switch options.background {
        case .transparent:
            wantsAlpha = true
        case .color, .image:
            wantsAlpha = false
        }

        var usesAlpha = wantsAlpha
        var videoInput = Self.makeVideoInput(
            size: renderSize,
            frameRate: nominalFrameRate,
            alpha: usesAlpha
        )
        if wantsAlpha, writer.canAdd(videoInput) == false {
            logger.notice("HEVC with alpha unavailable; flattening lifted subject onto a solid background")
            usesAlpha = false
            videoInput = Self.makeVideoInput(size: renderSize, frameRate: nominalFrameRate, alpha: false)
        }
        guard writer.canAdd(videoInput) else { throw CameraError.videoProcessingFailed }
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = preferredTransform
        writer.add(videoInput)

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(renderSize.width),
                kCVPixelBufferHeightKey as String: Int(renderSize.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
            ]
        )

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil, let audioTrack {
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            if let formatDescription = formatDescriptions.first {
                let input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: nil,
                    sourceFormatHint: formatDescription
                )
                input.expectsMediaDataInRealTime = false
                if writer.canAdd(input) {
                    writer.add(input)
                    audioInput = input
                }
            }
        }

        // Flattening background used when alpha is unavailable or when the user
        // asked for a solid/image backdrop.
        let backdrop = Self.backdrop(
            for: options.background,
            usesAlpha: usesAlpha,
            size: renderSize,
            context: context
        )

        guard reader.startReading() else {
            throw reader.error ?? CameraError.videoProcessingFailed
        }
        guard writer.startWriting() else {
            throw writer.error ?? CameraError.videoProcessingFailed
        }
        writer.startSession(atSourceTime: .zero)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [self] in
                    try await renderVideo(
                        videoOutput: videoOutput,
                        input: videoInput,
                        adaptor: adaptor,
                        renderSize: renderSize,
                        backdrop: backdrop,
                        allowMultipleSubjects: options.allowMultipleSubjects,
                        orientation: Self.imageOrientation(for: preferredTransform),
                        duration: duration,
                        progress: progress
                    )
                }

                if let audioInput, let audioOutput {
                    group.addTask { [self] in
                        try await transfer(from: audioOutput, to: audioInput)
                    }
                }

                try await group.waitForAll()
            }
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }

        if reader.status == .failed {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw reader.error ?? CameraError.videoProcessingFailed
        }

        await writer.finishWriting()

        guard writer.status == .completed else {
            try? FileManager.default.removeItem(at: outputURL)
            throw writer.error ?? CameraError.videoProcessingFailed
        }

        progress?(1.0)
        return VideoLiftResult(outputURL: outputURL, hasAlphaChannel: usesAlpha, duration: duration)
    }

    // MARK: - Video pass

    private func renderVideo(
        videoOutput: AVAssetReaderTrackOutput,
        input: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        renderSize: CGSize,
        backdrop: CIImage?,
        allowMultipleSubjects: Bool,
        orientation: CGImagePropertyOrientation,
        duration: Double,
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        var lastMask: CIImage?
        var sawSubject = false
        var frameIndex = 0

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: processingQueue) { [self] in
                while input.isReadyForMoreMediaData {
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        input.markAsFinished()
                        if sawSubject == false {
                            continuation.resume(throwing: CameraError.noSubjectDetected)
                        } else {
                            continuation.resume()
                        }
                        return
                    }

                    guard let sourceBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                    do {
                        let frame = CIImage(cvPixelBuffer: sourceBuffer)
                        let scaled = Self.scale(frame, to: renderSize)

                        let mask = try subjectMask(
                            for: sourceBuffer,
                            orientation: orientation,
                            allowMultipleSubjects: allowMultipleSubjects,
                            isFirstFrame: frameIndex == 0
                        )

                        if let mask {
                            sawSubject = true
                            lastMask = mask
                        }

                        // A frame where Vision loses the subject reuses the last
                        // good mask so the clip does not flicker to empty.
                        let effectiveMask = mask ?? lastMask
                        let composited = compose(
                            frame: scaled,
                            mask: effectiveMask,
                            renderSize: renderSize,
                            backdrop: backdrop
                        )

                        try append(
                            composited,
                            at: presentationTime,
                            adaptor: adaptor,
                            renderSize: renderSize
                        )

                        frameIndex += 1
                        if duration > 0 {
                            progress?(min(CMTimeGetSeconds(presentationTime) / duration, 0.99))
                        }
                    } catch {
                        input.markAsFinished()
                        continuation.resume(throwing: error)
                        return
                    }
                }
            }
        }
    }

    private func subjectMask(
        for pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        allowMultipleSubjects: Bool,
        isFirstFrame: Bool
    ) throws -> CIImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [.ciContext: context]
        )
        try handler.perform([request])

        guard let result = request.results?.first, result.allInstances.isEmpty == false else {
            return nil
        }

        // Single-subject mode mirrors the still-photo rule: reject the clip up
        // front rather than silently lifting extra subjects part way through.
        if isFirstFrame, allowMultipleSubjects == false, result.allInstances.count > 1 {
            throw CameraError.multipleSubjectsDetected
        }

        let maskBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        return CIImage(cvPixelBuffer: maskBuffer)
    }

    private func compose(
        frame: CIImage,
        mask: CIImage?,
        renderSize: CGSize,
        backdrop: CIImage?
    ) -> CIImage {
        let bounds = CGRect(origin: .zero, size: renderSize)
        let background = backdrop ?? CIImage(color: .clear).cropped(to: bounds)

        guard let mask else {
            // No subject anywhere yet: emit the backdrop so timing stays intact.
            return background.cropped(to: bounds)
        }

        let scaledMask = Self.scale(mask, to: renderSize)

        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            return frame.cropped(to: bounds)
        }
        blend.setValue(frame, forKey: kCIInputImageKey)
        blend.setValue(background, forKey: kCIInputBackgroundImageKey)
        blend.setValue(scaledMask, forKey: kCIInputMaskImageKey)

        return (blend.outputImage ?? frame).cropped(to: bounds)
    }

    private func append(
        _ image: CIImage,
        at time: CMTime,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        renderSize: CGSize
    ) throws {
        guard let pool = adaptor.pixelBufferPool else {
            throw CameraError.videoProcessingFailed
        }

        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let destination = buffer else {
            throw CameraError.videoProcessingFailed
        }

        context.render(
            image,
            to: destination,
            bounds: CGRect(origin: .zero, size: renderSize),
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        guard adaptor.append(destination, withPresentationTime: time) else {
            throw CameraError.videoProcessingFailed
        }
    }

    private func transfer(from output: AVAssetReaderTrackOutput, to input: AVAssetWriterInput) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            input.requestMediaDataWhenReady(on: processingQueue) {
                while input.isReadyForMoreMediaData {
                    guard let sampleBuffer = output.copyNextSampleBuffer() else {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                    if input.append(sampleBuffer) == false {
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private static func makeVideoInput(size: CGSize, frameRate: Float, alpha: Bool) -> AVAssetWriterInput {
        var compression: [String: Any] = [
            AVVideoAverageBitRateKey: Int(size.width * size.height * 8)
        ]
        if frameRate > 0 {
            compression[AVVideoExpectedSourceFrameRateKey] = Int(frameRate.rounded())
        }
        if alpha {
            compression[kVTCompressionPropertyKey_AlphaChannelMode as String] =
                kVTAlphaChannelMode_PremultipliedAlpha as String
        }

        return AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: alpha ? AVVideoCodecType.hevcWithAlpha : AVVideoCodecType.hevc,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height),
                AVVideoCompressionPropertiesKey: compression
            ]
        )
    }

    private static func backdrop(
        for background: Background,
        usesAlpha: Bool,
        size: CGSize,
        context: CIContext
    ) -> CIImage? {
        let bounds = CGRect(origin: .zero, size: size)

        switch background {
        case .transparent:
            // Without alpha support the only sane flattening target is opaque black.
            return usesAlpha ? nil : CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: bounds)
        case .color(let color):
            return CIImage(color: color).cropped(to: bounds)
        case .image(let image):
            guard let ciImage = CIImage(image: image) else {
                return CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: bounds)
            }
            // Fill the frame, cropping the overflow, so backgrounds never letterbox.
            let scale = max(size.width / ciImage.extent.width, size.height / ciImage.extent.height)
            let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let offset = CGAffineTransform(
                translationX: (size.width - scaled.extent.width) / 2 - scaled.extent.origin.x,
                y: (size.height - scaled.extent.height) / 2 - scaled.extent.origin.y
            )
            return scaled.transformed(by: offset).cropped(to: bounds)
        }
    }

    private static func scale(_ image: CIImage, to size: CGSize) -> CIImage {
        guard image.extent.width > 0, image.extent.height > 0 else { return image }
        let normalized = image.transformed(
            by: CGAffineTransform(translationX: -image.extent.origin.x, y: -image.extent.origin.y)
        )
        return normalized.transformed(
            by: CGAffineTransform(
                scaleX: size.width / normalized.extent.width,
                y: size.height / normalized.extent.height
            )
        )
    }

    private static func renderSize(for naturalSize: CGSize, maximumDimension: CGFloat) -> CGSize {
        let longest = max(naturalSize.width, naturalSize.height)
        let scale = longest > maximumDimension ? maximumDimension / longest : 1
        // Encoders want even dimensions.
        let width = max(2, (naturalSize.width * scale).rounded(.down))
        let height = max(2, (naturalSize.height * scale).rounded(.down))
        return CGSize(width: width - width.truncatingRemainder(dividingBy: 2), height: height - height.truncatingRemainder(dividingBy: 2))
    }

    /// Vision works on the untransformed buffer, so the track's display
    /// transform is converted into an EXIF orientation hint.
    private static func imageOrientation(for transform: CGAffineTransform) -> CGImagePropertyOrientation {
        switch (transform.a, transform.b, transform.c, transform.d) {
        case (0, 1, -1, 0):
            return .right
        case (0, -1, 1, 0):
            return .left
        case (-1, 0, 0, -1):
            return .down
        default:
            return .up
        }
    }
}
