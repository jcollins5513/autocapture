//
//  SessionCompositionService.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import Foundation
import OSLog
import SwiftData
import UIKit

enum SessionCompositionService {
    private static let logger = Logger(subsystem: "com.autocapture", category: "SessionCompositionService")

    /// Creates individual compositions for each vehicle in a session with a shared background
    /// Each vehicle is automatically centered on the background
    @MainActor
    static func createCompositionsForAllVehicles(
        session: CaptureSession,
        background: GeneratedBackground,
        canvasSize: CGSize,
        context: ModelContext
    ) throws -> [CompositionProject] {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            throw CompositionError.invalidCanvasSize
        }

        guard session.images.isEmpty == false else {
            throw CompositionError.noVehiclesInSession
        }

        var createdCompositions: [CompositionProject] = []

        for (index, processedImage) in session.images.enumerated() {
            guard let vehicleImage = processedImage.image,
                  let imageData = vehicleImage.pngData(),
                  imageData.isEmpty == false else {
                logger.warning("Skipping image with invalid data. imageID=\(processedImage.id.uuidString, privacy: .public)")
                continue
            }

            // Create a new composition project for this vehicle
            let compositionName: String
            if processedImage.subjectDescription.isEmpty == false {
                compositionName = "\(processedImage.subjectDescription) - \(session.stockNumber)"
            } else {
                compositionName = "Vehicle \(index + 1) - \(session.stockNumber)"
            }

            let composition = CompositionProject(
                name: compositionName,
                notes: "",
                session: session,
                background: background
            )

            // Create a layer for the vehicle image, centered on the canvas
            let layerName = processedImage.subjectDescription.isEmpty
                ? "Vehicle \(index + 1)"
                : processedImage.subjectDescription

            let vehicleLayer = CompositionLayer(
                name: layerName,
                order: 0,
                imageData: imageData,
                type: .subject,
                opacity: 1.0,
                offsetX: 0, // Centered by default (CompositionRenderer centers at 0,0)
                offsetY: 0,
                scale: calculateOptimalScale(
                    vehicleSize: vehicleImage.size,
                    canvasSize: canvasSize
                ),
                rotation: 0,
                isLocked: false,
                isVisible: true,
                processedImageID: processedImage.id,
                project: composition
            )

            composition.layers.append(vehicleLayer)
            context.insert(composition)
            context.insert(vehicleLayer)
            session.compositions.append(composition)

            createdCompositions.append(composition)
            logger.debug(
                "Created composition. name=\(compositionName, privacy: .public) vehicleSize=\(vehicleImage.size.debugDescription, privacy: .public) scale=\(vehicleLayer.scale, privacy: .public)"
            )
        }

        try context.save()
        logger.info("Created \(createdCompositions.count) compositions for session \(session.stockNumber)")
        return createdCompositions
    }

    /// Calculates optimal scale to fit vehicle within canvas while maintaining aspect ratio
    /// Ensures vehicle is properly sized and centered with appropriate margins
    static func calculateOptimalScale(vehicleSize: CGSize, canvasSize: CGSize) -> Double {
        guard vehicleSize.width > 0, vehicleSize.height > 0,
              canvasSize.width > 0, canvasSize.height > 0 else {
            return 1.0
        }

        // Calculate scale to fit vehicle within 35-40% of canvas (leaving very generous margins)
        // This prevents vehicles from appearing too zoomed in - vehicles should be prominent
        // but not fill the entire frame
        let margin: CGFloat = 0.38
        let maxWidth = canvasSize.width * margin
        let maxHeight = canvasSize.height * margin

        let widthScale = maxWidth / vehicleSize.width
        let heightScale = maxHeight / vehicleSize.height

        // Use the smaller scale to ensure vehicle fits within both dimensions
        let optimalScale = min(widthScale, heightScale)

        // Apply an additional safety multiplier to ensure vehicles are not too large
        // Even after fitting to 38%, we scale down by another 15% for extra margin
        let safetyMultiplier: Double = 0.85
        let scaledResult = optimalScale * safetyMultiplier

        // Clamp between 0.1 and 1.2 for reasonable bounds (further reduced max)
        let clampedScale = max(0.1, min(1.2, Double(scaledResult)))
        
        logger.debug(
            "Scale calculation: vehicleSize=\(vehicleSize.debugDescription, privacy: .public) canvasSize=\(canvasSize.debugDescription, privacy: .public) margin=\(margin, privacy: .public) calculatedScale=\(optimalScale, privacy: .public) safetyMultiplier=\(safetyMultiplier, privacy: .public) scaledResult=\(scaledResult, privacy: .public) clampedScale=\(clampedScale, privacy: .public)"
        )
        
        return clampedScale
    }
    
    /// Updates scales for existing vehicle layers in a session to use the new scaling algorithm
    /// This is useful when compositions were created with an older, too-zoom scale
    @MainActor
    static func updateScalesForExistingCompositions(
        session: CaptureSession,
        canvasSize: CGSize,
        context: ModelContext
    ) throws {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            throw CompositionError.invalidCanvasSize
        }
        
        var updatedCount = 0
        
        for composition in session.compositions {
            // Find vehicle/subject layers
            for layer in composition.layers where layer.type == .subject {
                // Get the actual image size from the layer's image data
                guard let image = UIImage(data: layer.imageData) else { continue }
                
                let newScale = calculateOptimalScale(
                    vehicleSize: image.size,
                    canvasSize: canvasSize
                )
                
                // Only update if the scale changed significantly (more than 5%)
                if abs(layer.scale - newScale) > 0.05 {
                    layer.scale = newScale
                    updatedCount += 1
                    logger.debug(
                        "Updated scale for layer \(layer.name, privacy: .public): \(layer.scale, privacy: .public) -> \(newScale, privacy: .public)"
                    )
                }
            }
        }
        
        if updatedCount > 0 {
            try context.save()
            logger.info("Updated scales for \(updatedCount) layers in session \(session.stockNumber)")
        }
    }

    /// Exports all compositions from a session as UIImage array
    @MainActor
    static func exportAllCompositions(
        session: CaptureSession,
        canvasSize: CGSize
    ) -> [UIImage] {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            logger.error("Invalid canvas size for export")
            return []
        }

        var exportedImages: [UIImage] = []

        for composition in session.compositions.sorted(by: { $0.createdAt < $1.createdAt }) {
            guard let renderedImage = CompositionRenderer.render(
                project: composition,
                canvasSize: canvasSize
            ) else {
                logger.warning(
                    "Failed to render composition. compositionID=\(composition.id.uuidString, privacy: .public)"
                )
                continue
            }

            exportedImages.append(renderedImage)
            logger.debug(
                "Exported composition. name=\(composition.name, privacy: .public) size=\(renderedImage.size.debugDescription, privacy: .public)"
            )
        }

        logger.info("Exported \(exportedImages.count) compositions from session \(session.stockNumber)")
        return exportedImages
    }

    enum CompositionError: LocalizedError {
        case invalidCanvasSize
        case noVehiclesInSession

        var errorDescription: String? {
            switch self {
            case .invalidCanvasSize:
                return "Invalid canvas size. Width and height must be greater than zero."
            case .noVehiclesInSession:
                return "No vehicles found in this session. Please capture images first."
            }
        }
    }
}

