//
//  ProcessedVideo.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import Foundation
import SwiftData
import UIKit

/// The video counterpart of `ProcessedImage`. The heavy media lives on disk in
/// `VideoFileStore`; only filenames, a poster frame and metadata are persisted.
@Model
final class ProcessedVideo {
    var id: UUID
    var captureDate: Date
    var subjectDescription: String
    var backgroundCategoryRawValue: String?
    var isSubjectLifted: Bool
    var captureModeRawValue: String = CaptureSubjectMode.singleSubject.rawValue
    /// Filename of the playable result (lifted subject or untouched scene).
    var processedFilename: String
    /// Filename of the untouched recording, kept so the lift can be redone.
    var originalFilename: String?
    /// True when the processed file carries a real alpha channel (HEVC w/ alpha).
    var hasAlphaChannel: Bool
    var durationSeconds: Double
    @Attribute(.externalStorage)
    var thumbnailData: Data?
    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.videos)
    var session: CaptureSession?

    init(
        processedFilename: String,
        originalFilename: String? = nil,
        captureDate: Date = Date(),
        subjectDescription: String = "",
        backgroundCategory: BackgroundCategory? = nil,
        session: CaptureSession? = nil,
        isSubjectLifted: Bool = true,
        captureMode: CaptureSubjectMode = .singleSubject,
        hasAlphaChannel: Bool = false,
        durationSeconds: Double = 0,
        thumbnail: UIImage? = nil
    ) {
        self.id = UUID()
        self.captureDate = captureDate
        self.subjectDescription = subjectDescription
        self.backgroundCategoryRawValue = backgroundCategory?.rawValue
        self.session = session
        self.isSubjectLifted = isSubjectLifted
        self.captureModeRawValue = captureMode.rawValue
        self.processedFilename = processedFilename
        self.originalFilename = originalFilename
        self.hasAlphaChannel = hasAlphaChannel
        self.durationSeconds = durationSeconds
        self.thumbnailData = thumbnail?.pngData()
    }

    var processedURL: URL {
        VideoFileStore.url(forFilename: processedFilename)
    }

    var originalURL: URL? {
        guard let originalFilename else { return nil }
        return VideoFileStore.url(forFilename: originalFilename)
    }

    var thumbnail: UIImage? {
        guard let thumbnailData else { return nil }
        return UIImage(data: thumbnailData)
    }

    var backgroundCategory: BackgroundCategory? {
        get {
            guard let backgroundCategoryRawValue else { return nil }
            return BackgroundCategory(rawValue: backgroundCategoryRawValue)
        }
        set { backgroundCategoryRawValue = newValue?.rawValue }
    }

    var captureMode: CaptureSubjectMode {
        get { CaptureSubjectMode(rawValue: captureModeRawValue) ?? .singleSubject }
        set { captureModeRawValue = newValue.rawValue }
    }

    var formattedDuration: String {
        let total = Int(durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// SwiftData cascades the record but not the files on disk, so callers
    /// delete media explicitly before removing the model.
    func deleteMediaFiles() {
        VideoFileStore.delete(filename: processedFilename)
        VideoFileStore.delete(filename: originalFilename)
    }
}
