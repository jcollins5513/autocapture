//
//  BackgroundPromptComponents.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation

struct BackgroundPromptComponents: Codable, Sendable {
    var subject: String
    var style: String
    var lighting: String
    var camera: String
    var quality: String
    var additionalConstraints: [String]

    func renderPrompt(with customSubject: String?) -> String {
        let subjectValue: String
        if let customSubject, customSubject.isEmpty == false {
            subjectValue = customSubject
        } else {
            subjectValue = subject
        }

        let components: [String?] = [
            "Subject: \(subjectValue)",
            "Style: \(style)",
            "Lighting: \(lighting). Soft, even, diffuse ambient light with a neutral white balance and no strong colored cast, so a separately photographed vehicle can be composited in believably",
            "Camera: \(camera). Eye-level camera at roughly 1.2 meters height with a straight-on, head-on viewpoint and minimal converging perspective",
            "Composition: an open, empty, clean floor across the lower-center foreground with clear room to place a single vehicle; keep the horizon and vanishing point near the vertical center; uncluttered",
            "Constraints: No Text, No People, No Subject, No Vehicles, Nothing in foreground, Clean Floor, Neutral Reflections",
            additionalConstraints.isEmpty ? nil : "Additional Constraints: \(additionalConstraints.joined(separator: ", "))",
            "Quality: \(quality)"
        ]

        return components.compactMap { $0 }.joined(separator: "\n")
    }
}
