//
//  CameraError.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import Foundation

enum CameraError: LocalizedError {
    case cameraUnavailable
    case photoCaptureFailed
    case backgroundRemovalFailed
    case noSubjectDetected
    case multipleSubjectsDetected
    case unauthorized
    case microphoneUnauthorized
    case videoCaptureFailed
    case videoTrackMissing
    case videoProcessingFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .photoCaptureFailed:
            return "Failed to capture photo"
        case .backgroundRemovalFailed:
            return "Failed to remove background"
        case .noSubjectDetected:
            return "No clear subject detected in photo. Please try again with a clearer subject."
        case .multipleSubjectsDetected:
            return "Multiple subjects detected. Switch to Multi mode or capture a single subject to continue."
        case .unauthorized:
            return "Camera access not authorized. Please enable in Settings."
        case .microphoneUnauthorized:
            return "Microphone access not authorized. Enable it in Settings to record video with sound."
        case .videoCaptureFailed:
            return "Failed to record video"
        case .videoTrackMissing:
            return "That file does not contain any video to process."
        case .videoProcessingFailed:
            return "Failed to lift the subject from this video. Please try again."
        }
    }
}
