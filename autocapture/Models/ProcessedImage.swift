//
//  ProcessedImage.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import Foundation
import SwiftData
import UIKit

@Model
final class ProcessedImage {
    var id: UUID
    var captureDate: Date
    @Attribute(.externalStorage)
    var imageData: Data
    @Attribute(.externalStorage)
    var liftedImageData: Data?
    var subjectDescription: String
    var backgroundCategoryRawValue: String?
    var isSubjectLifted: Bool
    var captureModeRawValue: String = CaptureSubjectMode.singleSubject.rawValue
    @Attribute(.externalStorage)
    var originalImageData: Data?
    @Attribute(.externalStorage)
    var maskImageData: Data?
    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.images)
    var session: CaptureSession?

    init(
        image: UIImage,
        captureDate: Date = Date(),
        subjectDescription: String = "",
        backgroundCategory: BackgroundCategory? = nil,
        session: CaptureSession? = nil,
        isSubjectLifted: Bool = true,
        captureMode: CaptureSubjectMode = .singleSubject,
        originalImage: UIImage? = nil,
        maskImage: UIImage? = nil,
        liftedImage: UIImage? = nil
    ) {
        self.id = UUID()
        self.captureDate = captureDate
        self.imageData = image.pngData() ?? Data()
        self.liftedImageData = liftedImage?.pngData()
        self.subjectDescription = subjectDescription
        self.backgroundCategoryRawValue = backgroundCategory?.rawValue
        self.session = session
        self.isSubjectLifted = isSubjectLifted
        self.captureModeRawValue = captureMode.rawValue
        self.originalImageData = originalImage?.pngData()
        self.maskImageData = maskImage?.pngData()
    }

    var image: UIImage? {
        UIImage(data: imageData)
    }

    var backgroundCategory: BackgroundCategory? {
        get {
            guard let rawValue = backgroundCategoryRawValue else { return nil }
            return BackgroundCategory(rawValue: rawValue)
        }
        set {
            backgroundCategoryRawValue = newValue?.rawValue
        }
    }

    var captureMode: CaptureSubjectMode {
        get {
            CaptureSubjectMode(rawValue: captureModeRawValue) ?? .singleSubject
        }
        set {
            captureModeRawValue = newValue.rawValue
        }
    }

    var originalImage: UIImage? {
        guard let originalImageData else { return nil }
        return UIImage(data: originalImageData)
    }

    var maskImage: UIImage? {
        guard let maskImageData else { return nil }
        return UIImage(data: maskImageData)
    }

    var liftedImage: UIImage? {
        guard let liftedImageData else { return nil }
        return UIImage(data: liftedImageData)
    }
}
