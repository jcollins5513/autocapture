//
//  GeneratedBackground.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation
import SwiftData

@Model
final class GeneratedBackground {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var prompt: String
    var categoryRawValue: String
    var aspectRatio: String
    var isCommunityShared: Bool
    @Attribute(.externalStorage)
    var imageData: Data?
    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.generatedBackgrounds)
    var session: CaptureSession?

    init(
        prompt: String,
        category: BackgroundCategory,
        aspectRatio: String = "16:9",
        isCommunityShared: Bool = false,
        session: CaptureSession? = nil,
        imageData: Data? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.prompt = prompt
        self.categoryRawValue = category.rawValue
        self.aspectRatio = aspectRatio
        self.isCommunityShared = isCommunityShared
        self.session = session
        self.imageData = imageData
    }

    var category: BackgroundCategory {
        get { BackgroundCategory(rawValue: categoryRawValue) ?? .custom }
        set { categoryRawValue = newValue.rawValue }
    }

    func touch() {
        updatedAt = Date()
    }
}
