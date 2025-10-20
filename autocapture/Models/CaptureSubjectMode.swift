//
//  CaptureSubjectMode.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import Foundation

enum CaptureSubjectMode: String, CaseIterable, Identifiable, Codable {
    case singleSubject
    case multiSubject
    case fullScene

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .singleSubject:
            return "Single"
        case .multiSubject:
            return "Multi"
        case .fullScene:
            return "Scene"
        }
    }

    var description: String {
        switch self {
        case .singleSubject:
            return "Lift one subject"
        case .multiSubject:
            return "Lift multiple subjects"
        case .fullScene:
            return "Keep full scene"
        }
    }

    var subtitle: String {
        switch self {
        case .singleSubject:
            return "Strict single-subject enforcement"
        case .multiSubject:
            return "Allow multiple subjects during lift"
        case .fullScene:
            return "Disable lift and keep background"
        }
    }

    var iconName: String {
        switch self {
        case .singleSubject:
            return "person.crop.square"
        case .multiSubject:
            return "person.2.crop.square.stack"
        case .fullScene:
            return "square.dashed"
        }
    }
}
