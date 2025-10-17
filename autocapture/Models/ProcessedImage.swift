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
    var subjectDescription: String
    var backgroundCategoryRawValue: String?
    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.images)
    var session: CaptureSession?

    init(
        image: UIImage,
        captureDate: Date = Date(),
        subjectDescription: String = "",
        backgroundCategory: BackgroundCategory? = nil,
        session: CaptureSession? = nil
    ) {
        self.id = UUID()
        self.captureDate = captureDate
        self.imageData = image.pngData() ?? Data()
        self.subjectDescription = subjectDescription
        self.backgroundCategoryRawValue = backgroundCategory?.rawValue
        self.session = session
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
}
