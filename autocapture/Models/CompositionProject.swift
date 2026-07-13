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

    // Persisted as optionals so a composition created before this feature
    // existed migrates deterministically to nil (SwiftData does not reliably
    // stamp a declared default onto a newly-added non-optional scalar, and can
    // backfill legacy rows with false/0 instead — which would silently disable
    // relighting). nil means "predates the feature" and reads as enabled at full
    // strength via the accessors below.
    private var colorMatchEnabledRaw: Bool?
    private var colorMatchStrengthRaw: Double?

    /// When true, composited subjects are relit toward the background's tone so
    /// they read as part of the scene instead of a cut-out. `colorMatchStrength`
    /// scales that nudge (1 = default; 0 leaves the subject untouched).
    var colorMatchEnabled: Bool {
        get { colorMatchEnabledRaw ?? true }
        set { colorMatchEnabledRaw = newValue }
    }
    var colorMatchStrength: Double {
        get { colorMatchStrengthRaw ?? 1.0 }
        set { colorMatchStrengthRaw = newValue }
    }

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
        self.colorMatchEnabledRaw = colorMatchEnabled
        self.colorMatchStrengthRaw = colorMatchStrength
        self.session = session
        self.background = background
        self.layers = []
    }

    func touch() {
        updatedAt = Date()
    }
}
