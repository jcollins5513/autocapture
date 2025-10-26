//
//  CaptureSession.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation
import SwiftData
import UIKit

@Model
final class CaptureSession {
    enum Status: String, Codable, CaseIterable, Identifiable {
        case planning
        case capturing
        case editing
        case completed

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .planning:
                return "Planning"
            case .capturing:
                return "Capturing"
            case .editing:
                return "Editing"
            case .completed:
                return "Completed"
            }
        }
    }

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var stockNumber: String
    var title: String
    var notes: String
    var statusRawValue: String
    var categories: [String]

    @Relationship(deleteRule: .cascade)
    var images: [ProcessedImage]
    @Relationship(deleteRule: .cascade)
    var compositions: [CompositionProject]
    @Relationship(deleteRule: .cascade)
    var generatedBackgrounds: [GeneratedBackground]
    @Attribute(.externalStorage)
    var overlayImageData: Data?

    init(stockNumber: String, title: String? = nil, notes: String = "", categories: [BackgroundCategory] = []) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.stockNumber = stockNumber
        self.title = title ?? "Session \(stockNumber)"
        self.notes = notes
        self.statusRawValue = Status.planning.rawValue
        self.categories = categories.map(\.rawValue)
        self.images = []
        self.compositions = []
        self.generatedBackgrounds = []
    }

    var status: Status {
        get { Status(rawValue: statusRawValue) ?? .planning }
        set { statusRawValue = newValue.rawValue }
    }

    var primaryCategory: BackgroundCategory? {
        get {
            guard let first = categories.first else { return nil }
            return BackgroundCategory(rawValue: first)
        }
        set {
            if let newValue {
                if categories.isEmpty {
                    categories = [newValue.rawValue]
                } else {
                    categories[0] = newValue.rawValue
                }
            }
        }
    }

    func touch() {
        updatedAt = Date()
    }

    var overlayImage: UIImage? {
        get {
            guard let overlayImageData else { return nil }
            return UIImage(data: overlayImageData)
        }
        set {
            overlayImageData = newValue?.pngData()
        }
    }
}
