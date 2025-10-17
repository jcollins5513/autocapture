//
//  VisualEditorViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
final class VisualEditorViewModel: ObservableObject {
    @Published var selectedCategory: BackgroundCategory = .automotive
    @Published var subjectDescription: String = ""
    @Published var aspectRatio: String = "16:9"
    @Published var shareWithCommunity = true
    @Published var isGenerating = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var generatedBackgrounds: [GeneratedBackground] = []

    @Published var activeProject: CompositionProject?

    private let backgroundGenerationService: BackgroundGenerationService
    private var modelContext: ModelContext?

    init(backgroundGenerationService: BackgroundGenerationService? = nil) {
        self.backgroundGenerationService = backgroundGenerationService ?? BackgroundGenerationService()
    }

    func configure(context: ModelContext, project: CompositionProject, session: CaptureSession?) {
        self.modelContext = context
        self.activeProject = project
        if let session {
            generatedBackgrounds = session.generatedBackgrounds.sorted { $0.createdAt > $1.createdAt }
            if let primary = session.primaryCategory {
                selectedCategory = primary
            }
            ensureSubjectLayers(for: project, from: session, context: context)
        } else {
            generatedBackgrounds = []
        }
        if let projectBackground = project.background {
            if generatedBackgrounds.contains(where: { $0.id == projectBackground.id }) == false {
                generatedBackgrounds.insert(projectBackground, at: 0)
            }
        }
    }

    private func ensureSubjectLayers(for project: CompositionProject, from session: CaptureSession, context: ModelContext) {
        let existingIDs = Set(project.layers.compactMap { $0.processedImageID })
        let sortedImages = session.images.sorted { $0.captureDate < $1.captureDate }
        var addedLayer = false

        for image in sortedImages where existingIDs.contains(image.id) == false {
            guard let uiImage = image.image,
                  let data = uiImage.pngData(),
                  data.isEmpty == false else {
                continue
            }

            let layerName: String
            if image.subjectDescription.isEmpty {
                layerName = "Subject \(project.layers.count + 1)"
            } else {
                layerName = image.subjectDescription
            }

            let newLayer = CompositionLayer(
                name: layerName,
                order: project.layers.count,
                imageData: data,
                type: .subject,
                processedImageID: image.id,
                project: project
            )

            project.layers.append(newLayer)
            context.insert(newLayer)
            addedLayer = true
        }

        if addedLayer {
            project.layers.enumerated().forEach { index, layer in
                layer.order = index
            }
            project.touch()
            do {
                try context.save()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    func generateBackground(for session: CaptureSession?) async {
        guard let modelContext else { return }
        isGenerating = true
        defer { isGenerating = false }

        do {
            let request = BackgroundGenerationRequest(
                category: selectedCategory,
                subjectDescription: subjectDescription,
                aspectRatio: aspectRatio,
                shareWithCommunity: shareWithCommunity,
                session: session
            )

            let result = try await backgroundGenerationService.generateBackground(for: request)

            modelContext.insert(result.background)
            session?.generatedBackgrounds.append(result.background)
            activeProject?.background = result.background
            generatedBackgrounds.insert(result.background, at: 0)
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func select(background: GeneratedBackground) {
        activeProject?.background = background
        activeProject?.touch()
        Task { [weak self] in
            guard let self, let context = self.modelContext else { return }
            do {
                try context.save()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    func addLayer(
        from image: UIImage,
        name: String? = nil,
        type: CompositionLayer.LayerType = .upload,
        processedImageID: UUID? = nil
    ) {
        guard let context = modelContext, let project = activeProject, let data = image.pngData() else { return }
        let layerName = name ?? "Layer \(project.layers.count + 1)"
        let newLayer = CompositionLayer(
            name: layerName,
            order: project.layers.count,
            imageData: data,
            type: type,
            processedImageID: processedImageID
        )
        newLayer.project = project
        project.layers.append(newLayer)
        project.touch()
        context.insert(newLayer)
        do {
            try context.save()
        } catch {
            context.delete(newLayer)
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func update(layer: CompositionLayer, offset: CGSize, scale: CGFloat, rotation: Angle) {
        layer.offsetX = offset.width
        layer.offsetY = offset.height
        layer.scale = scale
        layer.rotation = rotation.degrees
        layer.project?.touch()
        Task { [weak self] in
            guard let context = self?.modelContext else { return }
            do {
                try context.save()
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }

    func toggleVisibility(for layer: CompositionLayer) {
        layer.isVisible.toggle()
        layer.project?.touch()
        saveAsync()
    }

    func toggleLock(for layer: CompositionLayer) {
        layer.isLocked.toggle()
        layer.project?.touch()
        saveAsync()
    }

    func delete(layer: CompositionLayer) {
        guard let context = modelContext else { return }
        context.delete(layer)
        do {
            try context.save()
            activeProject?.layers.removeAll { $0.id == layer.id }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func reorderLayers(from source: IndexSet, to destination: Int) {
        guard let project = activeProject else { return }
        project.layers.move(fromOffsets: source, toOffset: destination)
        for (index, layer) in project.layers.enumerated() {
            layer.order = index
        }
        project.touch()
        saveAsync()
    }

    func moveLayerUp(_ layer: CompositionLayer) {
        guard let project = activeProject,
              let index = project.layers.firstIndex(where: { $0.id == layer.id }),
              index > 0 else { return }

        project.layers.swapAt(index, index - 1)
        normalizeOrder(in: project)
        saveAsync()
    }

    func moveLayerDown(_ layer: CompositionLayer) {
        guard let project = activeProject,
              let index = project.layers.firstIndex(where: { $0.id == layer.id }),
              index < project.layers.count - 1 else { return }

        project.layers.swapAt(index, index + 1)
        normalizeOrder(in: project)
        saveAsync()
    }

    private func normalizeOrder(in project: CompositionProject) {
        for (order, layer) in project.layers.enumerated() {
            layer.order = order
        }
        project.touch()
    }

    private func saveAsync() {
        Task { [weak self] in
            guard let context = self?.modelContext else { return }
            do {
                try context.save()
            } catch {
                await MainActor.run {
                    self?.errorMessage = error.localizedDescription
                    self?.showError = true
                }
            }
        }
    }
}
