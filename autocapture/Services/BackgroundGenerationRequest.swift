//
//  BackgroundGenerationRequest.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import Foundation

struct BackgroundGenerationRequest: Sendable {
    var category: BackgroundCategory
    var subjectDescription: String
    var aspectRatio: String
    var shareWithCommunity: Bool
    var session: CaptureSession?
}
