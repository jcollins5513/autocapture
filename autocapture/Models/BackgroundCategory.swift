//
//  BackgroundCategory.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation

enum BackgroundCategory: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case automotive
    case realEstate
    case restaurant
    case smallBusiness
    case hospitality
    case lifestyle
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automotive:
            return "Automotive"
        case .realEstate:
            return "Real Estate"
        case .restaurant:
            return "Restaurant"
        case .smallBusiness:
            return "Small Business"
        case .hospitality:
            return "Hospitality"
        case .lifestyle:
            return "Lifestyle"
        case .custom:
            return "Custom"
        }
    }

    var defaultPromptComponents: BackgroundPromptComponents {
        switch self {
        case .automotive:
            return BackgroundPromptComponents(
                subject: "dealership showroom backdrop",
                style: "photo-real, shallow depth of field",
                lighting: "soft key light from camera-left, practical warm lights in background",
                camera: "35mm lens, f/2.8, ISO 200, 1/125s",
                quality: "high detail, subtle film grain",
                additionalConstraints: [
                    "metallic accents",
                    "sleek architectural lines"
                ]
            )
        case .realEstate:
            return BackgroundPromptComponents(
                subject: "modern luxury living room backdrop",
                style: "photo-real architectural",
                lighting: "balanced natural window light",
                camera: "24mm lens, f/4, ISO 100, 1/80s",
                quality: "magazine editorial quality",
                additionalConstraints: [
                    "neutral palette",
                    "staged interior styling"
                ]
            )
        case .restaurant:
            return BackgroundPromptComponents(
                subject: "chef's table restaurant interior backdrop",
                style: "photo-real cinematic",
                lighting: "warm ambient lighting with gentle spot highlights",
                camera: "50mm lens, f/2, ISO 400, 1/60s",
                quality: "rich textures, inviting atmosphere",
                additionalConstraints: [
                    "elegant table setting",
                    "decor emphasis"
                ]
            )
        case .smallBusiness:
            return BackgroundPromptComponents(
                subject: "modern small business studio backdrop",
                style: "photo-real commercial",
                lighting: "soft key light with practical accents",
                camera: "35mm lens, f/3.2, ISO 160, 1/100s",
                quality: "clean professional finish",
                additionalConstraints: [
                    "modular shelving",
                    "subtle branding surfaces"
                ]
            )
        case .hospitality:
            return BackgroundPromptComponents(
                subject: "boutique hotel lobby backdrop",
                style: "photo-real, editorial",
                lighting: "glowing ambient light with soft uplighting",
                camera: "28mm lens, f/3.5, ISO 200, 1/80s",
                quality: "luxurious detail, polished surfaces",
                additionalConstraints: [
                    "architectural symmetry",
                    "decorative lighting fixtures"
                ]
            )
        case .lifestyle:
            return BackgroundPromptComponents(
                subject: "stylized lifestyle studio backdrop",
                style: "photo-real with artistic accents",
                lighting: "soft diffused daylight",
                camera: "35mm lens, f/2.2, ISO 160, 1/100s",
                quality: "editorial grade styling",
                additionalConstraints: [
                    "tonal gradients",
                    "minimal props"
                ]
            )
        case .custom:
            return BackgroundPromptComponents(
                subject: "custom user-defined backdrop",
                style: "photo-real",
                lighting: "balanced studio lighting",
                camera: "50mm lens, f/2.8, ISO 200, 1/125s",
                quality: "high detail, polished",
                additionalConstraints: []
            )
        }
    }
}
