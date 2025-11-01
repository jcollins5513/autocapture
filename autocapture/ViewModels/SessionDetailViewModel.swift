//
//  SessionDetailViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI
import UIKit
import Combine

@MainActor
final class SessionDetailViewModel: ObservableObject {
    @Published var isGeneratingBackground = false
    @Published var isCreatingCompositions = false
    @Published var isExporting = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showExportSheet = false
    @Published var exportImages: [UIImage] = []

    @Published var selectedCategory: BackgroundCategory = .automotive
    @Published var subjectDescription: String = ""
    @Published var aspectRatio: String = "16:9"
    @Published var shareWithCommunity = true

    private let backgroundGenerationService: BackgroundGenerationService
    private let logger = Logger(subsystem: "com.autocapture", category: "SessionDetailViewModel")

    init(backgroundGenerationService: BackgroundGenerationService? = nil, session: CaptureSession? = nil) {
        self.backgroundGenerationService = backgroundGenerationService ?? BackgroundGenerationService()
        if let session, let primaryCategory = session.primaryCategory {
            self.selectedCategory = primaryCategory
        }
    }

    func generateBackgroundAndApplyToAllVehicles(
        session: CaptureSession,
        context: ModelContext
    ) async {
        guard session.images.isEmpty == false else {
            errorMessage = "No vehicles found in this session. Please capture images first."
            showError = true
            return
        }

        isGeneratingBackground = true
        defer { isGeneratingBackground = false }

        do {
            // Generate background
            let request = BackgroundGenerationRequest(
                category: selectedCategory,
                subjectDescription: subjectDescription,
                aspectRatio: aspectRatio,
                shareWithCommunity: shareWithCommunity,
                session: session
            )

            let result = try await backgroundGenerationService.generateBackground(for: request)

            // Save background to session
            context.insert(result.background)
            session.generatedBackgrounds.append(result.background)
            try context.save()

            // Apply to all vehicles
            await applyBackgroundToAllVehicles(
                session: session,
                background: result.background,
                context: context
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func applyBackgroundToAllVehicles(
        session: CaptureSession,
        background: GeneratedBackground,
        context: ModelContext
    ) async {
        guard session.images.isEmpty == false else {
            errorMessage = "No vehicles found in this session."
            showError = true
            return
        }

        isCreatingCompositions = true
        defer { isCreatingCompositions = false }

        do {
            // Calculate canvas size from aspect ratio
            let canvasSize = canvasSizeForAspectRatio(background.aspectRatio)

            // Create compositions for all vehicles
            _ = try SessionCompositionService.createCompositionsForAllVehicles(
                session: session,
                background: background,
                canvasSize: canvasSize,
                context: context
            )

            logger.info(
                "Successfully created compositions for all vehicles in session \(session.stockNumber)"
            )
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func updateCompositionScales(session: CaptureSession, context: ModelContext) async {
        isCreatingCompositions = true
        defer { isCreatingCompositions = false }
        
        do {
            let canvasSize: CGSize
            if let firstBackground = session.compositions.first?.background {
                canvasSize = canvasSizeForAspectRatio(firstBackground.aspectRatio)
            } else {
                canvasSize = canvasSizeForAspectRatio("16:9")
            }
            
            try SessionCompositionService.updateScalesForExistingCompositions(
                session: session,
                canvasSize: canvasSize,
                context: context
            )
            
            logger.info("Successfully updated scales for compositions in session \(session.stockNumber)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    func exportAllCompositions(session: CaptureSession) {
        guard session.compositions.isEmpty == false else {
            errorMessage = "No compositions found. Please create compositions first."
            showError = true
            return
        }

        isExporting = true
        defer { isExporting = false }

        // Use default canvas size (16:9) or get from first composition's background
        let canvasSize: CGSize
        if let firstBackground = session.compositions.first?.background {
            canvasSize = canvasSizeForAspectRatio(firstBackground.aspectRatio)
        } else {
            canvasSize = canvasSizeForAspectRatio("16:9")
        }

        let images = SessionCompositionService.exportAllCompositions(
            session: session,
            canvasSize: canvasSize
        )

        guard images.isEmpty == false else {
            errorMessage = "Failed to export compositions."
            showError = true
            return
        }

        exportImages = images
        showExportSheet = true
        logger.info("Exported \(images.count) compositions from session \(session.stockNumber)")
    }

    private func canvasSizeForAspectRatio(_ aspectRatio: String) -> CGSize {
        // Use high-resolution canvas sizes for export quality
        switch aspectRatio {
        case "1:1":
            return CGSize(width: 2048, height: 2048)
        case "3:2":
            return CGSize(width: 2560, height: 1707)
        case "4:5":
            return CGSize(width: 2048, height: 2560)
        case "9:16":
            return CGSize(width: 2048, height: 3584)
        case "16:9":
            return CGSize(width: 3584, height: 2016)
        default:
            return CGSize(width: 3584, height: 2016) // Default to 16:9
        }
    }
}

