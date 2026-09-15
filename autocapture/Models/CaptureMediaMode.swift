//
//  CaptureMediaMode.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import Foundation

/// Whether the camera is capturing stills or movies. Subject lifting runs the
/// same way in both cases, just frame-by-frame for video.
enum CaptureMediaMode: String, CaseIterable, Identifiable, Codable {
    case photo
    case video

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photo:
            return "Photo"
        case .video:
            return "Video"
        }
    }

    var iconName: String {
        switch self {
        case .photo:
            return "camera"
        case .video:
            return "video"
        }
    }
}
