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

    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var activeSession: CaptureSession?
    @Published var subjectDescription: String = ""
    @Published var subjectMode: CaptureSubjectMode = .singleSubject

    private var modelContext: ModelContext?

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

    func importImageFromLibrary(_ image: UIImage, removeBackground: Bool) async {
        guard !isProcessing else { return }

        isProcessing = true
        defer { isProcessing = false }

        do {
            if removeBackground {
                let selectedMode: CaptureSubjectMode
                if subjectMode == .fullScene {
                    selectedMode = .singleSubject
                } else {
                    selectedMode = subjectMode
                }

                let allowMultipleSubjects = selectedMode == .multiSubject
                let result = try await backgroundRemovalService.extractForeground(
                    from: image,
                    allowMultipleSubjects: allowMultipleSubjects
                )

                saveProcessedImage(
                    result.foregroundImage,
                    isSubjectLifted: true,
                    captureMode: selectedMode,
                    originalImage: result.originalImage,
                    maskImage: result.maskImage
                )
            } else {
                saveProcessedImage(
                    image,
                    isSubjectLifted: false,
                    captureMode: .fullScene,
                    originalImage: nil,
                    maskImage: nil
                )
            }
        } catch let error as CameraError {
            handleError(error)
        } catch {
            handleError(CameraError.backgroundRemovalFailed)
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
