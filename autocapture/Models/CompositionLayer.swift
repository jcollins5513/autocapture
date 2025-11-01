//
//  CompositionLayer.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation
import SwiftData

@Model
final class CompositionLayer {
    enum LayerType: String, Codable, CaseIterable, Identifiable {
        case subject
        case background
        case adjustment
        case upload
        case text
        case object

        var id: String { rawValue }
    }

    var id: UUID
    var createdAt: Date
    var name: String
    var order: Int
    var opacity: Double
    var offsetX: Double
    var offsetY: Double
    var scale: Double
    var rotation: Double
    var isLocked: Bool
    var isVisible: Bool
    var typeRawValue: String
    var processedImageID: UUID?

    // Text layer properties (optional to support migration)
    var textContent: String?
    var textFontName: String?
    var textFontSize: Double?
    var textColor: String? // Hex color string
    var textAlignment: String? // "left", "center", "right"

    // Object layer properties (optional to support migration)
    var objectPrompt: String?
    var objectGenerationService: String? // e.g., "nano_bannanna"

    @Attribute(.externalStorage)
    var imageData: Data
    @Relationship(deleteRule: .nullify, inverse: \CompositionProject.layers)
    var project: CompositionProject?

    init(
        name: String,
        order: Int,
        imageData: Data,
        type: LayerType = .subject,
        opacity: Double = 1.0,
        offsetX: Double = 0,
        offsetY: Double = 0,
        scale: Double = 1.0,
        rotation: Double = 0,
        isLocked: Bool = false,
        isVisible: Bool = true,
        processedImageID: UUID? = nil,
        project: CompositionProject? = nil,
        textContent: String? = nil,
        textFontName: String? = nil,
        textFontSize: Double? = nil,
        textColor: String? = nil,
        textAlignment: String? = nil,
        objectPrompt: String? = nil,
        objectGenerationService: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.name = name
        self.order = order
        self.opacity = opacity
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.rotation = rotation
        self.isLocked = isLocked
        self.isVisible = isVisible
        self.typeRawValue = type.rawValue
        self.imageData = imageData
        self.processedImageID = processedImageID
        self.project = project
        self.textContent = textContent
        self.textFontName = textFontName
        self.textFontSize = textFontSize
        self.textColor = textColor
        self.textAlignment = textAlignment
        self.objectPrompt = objectPrompt
        self.objectGenerationService = objectGenerationService
    }

    var type: LayerType {
        get { LayerType(rawValue: typeRawValue) ?? .subject }
        set { typeRawValue = newValue.rawValue }
    }
}
