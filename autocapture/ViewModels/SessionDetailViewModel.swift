//
//  SessionDetailViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI
import UIKit
import Combine

@MainActor
final class SessionDetailViewModel: ObservableObject {
    @Published var isGeneratingBackground = false
    @Published var isCreatingCompositions = false
    @Published var isExporting = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadResults: [UploadOutcome] = []
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showExportSheet = false
    @Published var exportImages: [UIImage] = []

    @Published var selectedCategory: BackgroundCategory = .automotive
    @Published var subjectDescription: String = ""
    @Published var aspectRatio: String = "16:9"
    @Published var shareWithCommunity = true

    private let backgroundGenerationService: BackgroundGenerationService
    private let uploadService: WebCompanionUploadService
    private let logger = Logger(subsystem: "com.autocapture", category: "SessionDetailViewModel")

    struct UploadOutcome: Identifiable {
        enum Status {
            case success
            case queued
            case failed
        }

        let id = UUID()
        let filename: String
        let status: Status
        let message: String
        let processedUrl: String?
    }

    init(
        backgroundGenerationService: BackgroundGenerationService? = nil,
        uploadService: WebCompanionUploadService = WebCompanionUploadService(),
        session: CaptureSession? = nil
    ) {
        self.backgroundGenerationService = backgroundGenerationService ?? BackgroundGenerationService()
        self.uploadService = uploadService
        if let session, let primaryCategory = session.primaryCategory {
            self.selectedCategory = primaryCategory
        }
    }

    func generateBackgroundAndApplyToAllVehicles(
        session: CaptureSession,
        context: ModelContext
    ) async {
        guard let background = await generateBackground(session: session, context: context) else {
            return
        }

        await applyBackgroundToAllVehicles(
            session: session,
            background: background,
            context: context
        )
    }

    /// Generates a background and stores it on the session without applying it,
    /// so the user can keep generating until they find one they like.
    @discardableResult
    func generateBackground(session: CaptureSession, context: ModelContext) async -> GeneratedBackground? {
        isGeneratingBackground = true
        defer { isGeneratingBackground = false }

        do {
            let request = BackgroundGenerationRequest(
                category: selectedCategory,
                subjectDescription: subjectDescription,
                aspectRatio: aspectRatio,
                shareWithCommunity: shareWithCommunity,
                session: session
            )

            let result = try await backgroundGenerationService.generateBackground(for: request)

            // Save background to session; generations are kept even when the
            // user regenerates, building up a library to pick from.
            context.insert(result.background)
            session.generatedBackgrounds.append(result.background)
            try context.save()
            return result.background
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    /// Marks a background as the reusable default for all later sessions,
    /// clearing the flag from any previously chosen background.
    func setDefaultBackground(_ background: GeneratedBackground, context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<GeneratedBackground>(
                predicate: #Predicate { $0.isDefault == true }
            )
            for existing in try context.fetch(descriptor) where existing.id != background.id {
                existing.isDefault = false
                existing.touch()
            }
            background.isDefault = true
            background.touch()
            try context.save()
            logger.info("Set default background \(background.id.uuidString, privacy: .public)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func clearDefaultBackground(_ background: GeneratedBackground, context: ModelContext) {
        background.isDefault = false
        background.touch()
        do {
            try context.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func applyBackgroundToAllVehicles(
        session: CaptureSession,
        background: GeneratedBackground,
        context: ModelContext
    ) async {
        guard session.images.isEmpty == false else {
            errorMessage = "No vehicles found in this session."
            showError = true
            return
        }

        isCreatingCompositions = true
        defer { isCreatingCompositions = false }

        do {
            // Calculate canvas size from aspect ratio
            let canvasSize = canvasSizeForAspectRatio(background.aspectRatio)

            // Create compositions for all vehicles
            _ = try SessionCompositionService.createCompositionsForAllVehicles(
                session: session,
                background: background,
                canvasSize: canvasSize,
                context: context
            )

            logger.info(
                "Successfully created compositions for all vehicles in session \(session.stockNumber)"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateCompositionScales(session: CaptureSession, context: ModelContext) async {
        isCreatingCompositions = true
        defer { isCreatingCompositions = false }

        do {
            let canvasSize: CGSize
            if let firstBackground = session.compositions.first?.background {
                canvasSize = canvasSizeForAspectRatio(firstBackground.aspectRatio)
            } else {
                canvasSize = canvasSizeForAspectRatio("16:9")
            }

            try SessionCompositionService.updateScalesForExistingCompositions(
                session: session,
                canvasSize: canvasSize,
                context: context
            )

            logger.info("Successfully updated scales for compositions in session \(session.stockNumber)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func exportAllCompositions(session: CaptureSession) {
        guard session.compositions.isEmpty == false else {
            errorMessage = "No compositions found. Please create compositions first."
            showError = true
            return
        }

        isExporting = true
        defer { isExporting = false }

        // Use default canvas size (16:9) or get from first composition's background
        let canvasSize: CGSize
        if let firstBackground = session.compositions.first?.background {
            canvasSize = canvasSizeForAspectRatio(firstBackground.aspectRatio)
        } else {
            canvasSize = canvasSizeForAspectRatio("16:9")
        }

        let images = SessionCompositionService.exportAllCompositions(
            session: session,
            canvasSize: canvasSize
        )

        guard images.isEmpty == false else {
            errorMessage = "Failed to export compositions."
            showError = true
            return
        }

        exportImages = images
        showExportSheet = true
        logger.info("Exported \(images.count) compositions from session \(session.stockNumber)")
    }

    func uploadLiftedSubjects(session: CaptureSession) async {
        guard session.images.isEmpty == false else {
            errorMessage = "No images found in this session."
            showError = true
            return
        }

        let liftedImages = session.images.filter { $0.isSubjectLifted }

        guard liftedImages.isEmpty == false else {
            errorMessage = "No subject-lifted images found to upload."
            showError = true
            return
        }

        isExporting = true
        defer { isExporting = false }

        var successCount = 0
        var failureCount = 0

        for (index, image) in liftedImages.enumerated() {
            guard let imageData = image.imageData as Data? else { continue }

            do {
                try await WebCompanionService.uploadImage(
                    imageData: imageData,
                    stockNumber: session.stockNumber,
                    isProcessed: true,
                    filename: "lifted-subject-\(index + 1).png"
                )
                successCount += 1
            } catch {
                logger.error("Failed to upload image \(index): \(error.localizedDescription)")
                failureCount += 1
            }
        }

        if failureCount > 0 {
            if successCount > 0 {
                errorMessage = "Uploaded \(successCount) images, but \(failureCount) failed."
            } else {
                errorMessage = "Failed to upload images. Check your connection."
            }
            showError = true
        } else {
            logger.info("Successfully uploaded \(successCount) lifted subjects to Web Companion")
        }
    }

    func uploadSession(_ session: CaptureSession, context: ModelContext) async {
        guard session.images.isEmpty == false else {
            errorMessage = "No captures found for this session. Capture photos before uploading."
            showError = true
            return
        }

        isUploading = true
        uploadProgress = 0
        defer { isUploading = false }

        let images = session.images.sorted(by: { $0.captureDate < $1.captureDate })
        let totalCount = Double(images.count)
        var completedCount = 0.0

        for (index, image) in images.enumerated() {
            guard let uiImage = image.originalImage ?? image.image else {
                let message = "Skipping image \(image.id.uuidString) because data could not be loaded."
                logger.error("\(message)")
                uploadResults.insert(
                    UploadOutcome(
                        filename: "capture-\(index + 1).png",
                        status: .failed,
                        message: message,
                        processedUrl: nil
                    ),
                    at: 0
                )
                continue
            }

            let filename = makeFilename(for: image, at: index, stockNumber: session.stockNumber)

            do {
                let upload = try await uploadService.upload(
                    image: uiImage,
                    stockNumber: session.stockNumber,
                    filename: filename
                )

                // The server returns `pending` for originals it still has to
                // process — that's queued, not done. Only report success once a
                // processed image actually exists.
                let isProcessed = upload.status == "processed" || upload.processedUrl != nil
                uploadResults.insert(
                    UploadOutcome(
                        filename: filename,
                        status: isProcessed ? .success : .queued,
                        message: isProcessed
                            ? "Uploaded and processed"
                            : "Uploaded — queued for background removal",
                        processedUrl: upload.processedUrl
                    ),
                    at: 0
                )
            } catch {
                let message = error.localizedDescription
                logger.error("Upload failed for \(filename, privacy: .public): \(message, privacy: .public)")
                uploadResults.insert(
                    UploadOutcome(
                        filename: filename,
                        status: .failed,
                        message: message,
                        processedUrl: nil
                    ),
                    at: 0
                )
                errorMessage = message
                showError = true
            }

            completedCount += 1
            uploadProgress = completedCount / totalCount
        }

        try? context.save()
    }

    private func makeFilename(for image: ProcessedImage, at index: Int, stockNumber: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: image.captureDate)
        return "\(stockNumber)_\(timestamp)_\(index + 1).jpg"
    }

    private func canvasSizeForAspectRatio(_ aspectRatio: String) -> CGSize {
        // Use high-resolution canvas sizes for export quality
        switch aspectRatio {
        case "1:1":
            return CGSize(width: 2048, height: 2048)
        case "3:2":
            return CGSize(width: 2560, height: 1707)
        case "4:5":
            return CGSize(width: 2048, height: 2560)
        case "9:16":
            return CGSize(width: 2048, height: 3584)
        case "16:9":
            return CGSize(width: 3584, height: 2016)
        default:
            return CGSize(width: 3584, height: 2016) // Default to 16:9
        }
    }
}
