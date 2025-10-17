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

    @Relationship(deleteRule: .nullify, inverse: \CaptureSession.compositions)
    var session: CaptureSession?
    @Relationship(deleteRule: .nullify)
    var background: GeneratedBackground?
    @Relationship(deleteRule: .cascade)
    var layers: [CompositionLayer]

    init(name: String, notes: String = "", session: CaptureSession? = nil, background: GeneratedBackground? = nil) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.name = name
        self.notes = notes
        self.session = session
        self.background = background
        self.layers = []
    }

    func touch() {
        updatedAt = Date()
    }
}
