//
//  CameraViewModel.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import AVFoundation
import Combine
import SwiftData
import SwiftUI

@MainActor
class CameraViewModel: ObservableObject {
    let cameraService = CameraService()
    private let backgroundRemovalService = BackgroundRemovalService()
    private let videoLiftService = VideoSubjectLiftService()

    @Published var isProcessing = false
    /// 0...1 while a recorded clip is being lifted frame by frame.
    @Published var processingProgress: Double = 0
    @Published var processingMessage = "Processing..."
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var captureMediaMode: CaptureMediaMode = .photo {
        didSet {
            guard captureMediaMode != oldValue else { return }
            cameraService.setCaptureMode(captureMediaMode)
            if captureMediaMode == .video {
                Task { _ = await cameraService.requestMicrophoneAccess() }
            }
        }
    }
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var activeSession: CaptureSession?
    @Published var subjectDescription: String = ""
    @Published var subjectMode: CaptureSubjectMode = .singleSubject

    private var modelContext: ModelContext?
    private var recordingTimer: Timer?

    init() {
        setupBindings()
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func setActiveSession(_ session: CaptureSession?) {
        self.activeSession = session
        if let session {
            subjectDescription = session.notes
            session.status = .capturing
            session.touch()
            Task { [weak self] in
                guard let context = self?.modelContext else { return }
                try? context.save()
            }
        } else {
            subjectDescription = ""
        }
    }

    private func setupBindings() {
        // Bind flash mode
        cameraService.$flashMode
            .assign(to: &$flashMode)

        // Bind zoom factor
        cameraService.$currentZoomFactor
            .assign(to: &$currentZoomFactor)

        cameraService.$isRecording
            .assign(to: &$isRecording)
    }

    // MARK: - Video

    func toggleRecording() async {
        if cameraService.isRecording {
            await finishRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard isProcessing == false else { return }

        do {
            try cameraService.startRecording()
            recordingDuration = 0
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.cameraService.isRecording else { return }
                    self.recordingDuration += 0.1
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            recordingTimer = timer
        } catch {
            handleError(error)
        }
    }

    private func finishRecording() async {
        recordingTimer?.invalidate()
        recordingTimer = nil

        do {
            let recordedURL = try await cameraService.stopRecording()
            recordingDuration = 0
            await processRecording(at: recordedURL)
        } catch {
            handleError(CameraError.videoCaptureFailed)
        }
    }

    /// Runs the lift (when the mode asks for it) and stores the clip.
    func processRecording(at recordedURL: URL) async {
        isProcessing = true
        processingProgress = 0
        processingMessage = subjectMode == .fullScene ? "Saving video..." : "Lifting subject from video..."
        defer {
            isProcessing = false
            processingProgress = 0
            processingMessage = "Processing..."
        }

        do {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            if subjectMode == .fullScene {
                let filename = try VideoFileStore.importFile(at: recordedURL)
                try? FileManager.default.removeItem(at: recordedURL)
                await saveProcessedVideo(
                    processedFilename: filename,
                    originalFilename: nil,
                    isSubjectLifted: false,
                    captureMode: .fullScene,
                    hasAlphaChannel: false
                )
                return
            }

            let options = VideoSubjectLiftService.Options(
                allowMultipleSubjects: subjectMode == .multiSubject,
                background: .transparent
            )

            let result = try await videoLiftService.liftSubject(from: recordedURL, options: options) { [weak self] value in
                Task { @MainActor [weak self] in
                    self?.processingProgress = value
                }
            }

            let originalFilename = try? VideoFileStore.importFile(at: recordedURL)
            try? FileManager.default.removeItem(at: recordedURL)

            let processedFilename = try VideoFileStore.adopt(fileAt: result.outputURL)
            await saveProcessedVideo(
                processedFilename: processedFilename,
                originalFilename: originalFilename,
                isSubjectLifted: true,
                captureMode: subjectMode,
                hasAlphaChannel: result.hasAlphaChannel,
                duration: result.duration
            )
        } catch {
            try? FileManager.default.removeItem(at: recordedURL)
            handleError(error)
        }
    }

    private func saveProcessedVideo(
        processedFilename: String,
        originalFilename: String?,
        isSubjectLifted: Bool,
        captureMode: CaptureSubjectMode,
        hasAlphaChannel: Bool,
        duration: Double? = nil
    ) async {
        guard let context = modelContext else { return }

        let url = VideoFileStore.url(forFilename: processedFilename)
        let thumbnailSource = originalFilename.map(VideoFileStore.url(forFilename:)) ?? url
        // Lifted clips are transparent, so the poster frame comes from the
        // original recording whenever we still have it.
        let thumbnail = await VideoFileStore.thumbnail(for: thumbnailSource)
        let resolvedDuration = duration ?? (await VideoFileStore.duration(for: url))

        let video = ProcessedVideo(
            processedFilename: processedFilename,
            originalFilename: originalFilename,
            subjectDescription: subjectDescription,
            backgroundCategory: activeSession?.primaryCategory,
            session: activeSession,
            isSubjectLifted: isSubjectLifted,
            captureMode: captureMode,
            hasAlphaChannel: hasAlphaChannel,
            durationSeconds: resolvedDuration,
            thumbnail: thumbnail
        )

        if let session = activeSession {
            session.videos.append(video)
            session.touch()
        }

        context.insert(video)

        do {
            try context.save()
        } catch {
            print("Failed to save video: \(error)")
        }
    }

    func setupCamera() async {
        do {
            try await cameraService.setupSession()
            cameraService.startSession()
        } catch {
            handleError(error)
        }
    }

    func capturePhoto() async {
        guard !isProcessing else { return }

        isProcessing = true

        do {
            // Capture photo
            let photo = try await cameraService.capturePhoto()

            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            switch subjectMode {
            case .singleSubject:
                let result = try await backgroundRemovalService.extractForeground(from: photo, allowMultipleSubjects: false)
                saveProcessedImage(
                    result.foregroundImage,
                    isSubjectLifted: true,
                    captureMode: .singleSubject,
                    originalImage: result.originalImage,
                    maskImage: result.maskImage
                )
            case .multiSubject:
                let result = try await backgroundRemovalService.extractForeground(from: photo, allowMultipleSubjects: true)
                saveProcessedImage(
                    result.foregroundImage,
                    isSubjectLifted: true,
                    captureMode: .multiSubject,
                    originalImage: result.originalImage,
                    maskImage: result.maskImage
                )
            case .fullScene:
                saveProcessedImage(
                    photo,
                    isSubjectLifted: false,
                    captureMode: .fullScene,
                    originalImage: nil,
                    maskImage: nil
                )
            }

            isProcessing = false
        } catch let error as CameraError {
            isProcessing = false
            handleError(error)
        } catch {
            isProcessing = false
            handleError(CameraError.photoCaptureFailed)
        }
    }

    func toggleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
        cameraService.flashMode = flashMode
    }

    func flipCamera() {
        do {
            try cameraService.flipCamera()
        } catch {
            handleError(error)
        }
    }

    func setZoom(_ factor: CGFloat) {
        cameraService.setZoom(factor)
    }

    func focus(at point: CGPoint, in bounds: CGRect) {
        cameraService.focus(at: point, in: bounds)
    }

    func stopCamera() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        if cameraService.isRecording {
            Task { _ = try? await cameraService.stopRecording() }
        }
        cameraService.stopSession()
    }

    private func saveProcessedImage(
        _ image: UIImage,
        isSubjectLifted: Bool,
        captureMode: CaptureSubjectMode,
        originalImage: UIImage?,
        maskImage: UIImage?
    ) {
        guard let context = modelContext else { return }

        let processedImage = ProcessedImage(
            image: image,
            subjectDescription: subjectDescription,
            backgroundCategory: activeSession?.primaryCategory,
            session: activeSession,
            isSubjectLifted: isSubjectLifted,
            captureMode: captureMode,
            originalImage: originalImage,
            maskImage: maskImage
        )

        if let session = activeSession {
            session.images.append(processedImage)
            session.touch()
        }

        context.insert(processedImage)

        do {
            try context.save()
        } catch {
            print("Failed to save image: \(error)")
        }
    }

    private func handleError(_ error: Error) {
        if let cameraError = error as? CameraError {
            errorMessage = cameraError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
