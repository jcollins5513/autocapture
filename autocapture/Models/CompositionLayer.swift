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
        project: CompositionProject? = nil
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
    }

    var type: LayerType {
        get { LayerType(rawValue: typeRawValue) ?? .subject }
        set { typeRawValue = newValue.rawValue }
    }
}
