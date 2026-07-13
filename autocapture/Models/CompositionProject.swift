//
//  CompositionProject.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation
import SwiftData

@Model
final class CompositionProject {
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var notes: String

    /// When true, composited subjects are relit toward the background's tone so
    /// they read as part of the scene instead of a cut-out. `colorMatchStrength`
    /// scales that nudge (1 = default; 0 leaves the subject untouched).
    var colorMatchEnabled: Bool = true
    var colorMatchStrength: Double = 1.0

    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.compositions)
    var session: CaptureSession?
    @Relationship(deleteRule: .nullify)
    var background: GeneratedBackground?
    @Relationship(deleteRule: .cascade)
    var layers: [CompositionLayer]

    init(
        name: String,
        notes: String = "",
        session: CaptureSession? = nil,
        background: GeneratedBackground? = nil,
        colorMatchEnabled: Bool = true,
        colorMatchStrength: Double = 1.0
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.name = name
        self.notes = notes
        self.colorMatchEnabled = colorMatchEnabled
        self.colorMatchStrength = colorMatchStrength
        self.session = session
        self.background = background
        self.layers = []
    }

    func touch() {
        updatedAt = Date()
    }
}
