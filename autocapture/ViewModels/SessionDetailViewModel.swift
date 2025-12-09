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
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var uploadResults: [UploadOutcome] = []
    @Published var errorMessage: String?
    @Published var showError = false

    private let uploadService: WebCompanionUploadService
    private let logger = Logger(subsystem: "com.autocapture", category: "SessionDetailViewModel")

    struct UploadOutcome: Identifiable {
        enum Status {
            case success
            case failed
        }

        let id = UUID()
        let filename: String
        let status: Status
        let message: String
        let processedUrl: String?
    }

    init(uploadService: WebCompanionUploadService = WebCompanionUploadService()) {
        self.uploadService = uploadService
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

                uploadResults.insert(
                    UploadOutcome(
                        filename: filename,
                        status: .success,
                        message: "Uploaded to web companion queue",
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

        session.status = .completed
        session.touch()
        try? context.save()
    }

    private func makeFilename(for image: ProcessedImage, at index: Int, stockNumber: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: image.captureDate)
        return "\(stockNumber)_\(timestamp)_\(index + 1).jpg"
    }
}

