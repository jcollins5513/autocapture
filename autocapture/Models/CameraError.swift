//
//  CameraError.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import Foundation

enum CameraError: LocalizedError {
    case cameraUnavailable
    case photoCaptureFailed
    case backgroundRemovalFailed
    case noSubjectDetected
    case unauthorized
    
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
        case .unauthorized:
            return "Camera access not authorized. Please enable in Settings."
        }
    }
}


