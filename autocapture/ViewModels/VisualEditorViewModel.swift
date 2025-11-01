//
//  VisualEditorViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

// swiftlint:disable type_body_length function_body_length file_length
import Combine
import Foundation
import OSLog
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
    @Published private(set) var backgroundLibrary: [BackgroundCategory: [GeneratedBackground]] = [:]
    @Published var isImportingLayer = false
    @Published private(set) var cleaningLayerIDs: Set<UUID> = []

    @Published var activeProject: CompositionProject?

    private let backgroundGenerationService: BackgroundGenerationService
    private let backgroundRemovalService: BackgroundRemovalService
    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.autocapture", category: "VisualEditorViewModel")

    init(
        backgroundGenerationService: BackgroundGenerationService? = nil,
        backgroundRemovalService: BackgroundRemovalService? = nil
    ) {
        self.backgroundGenerationService = backgroundGenerationService ?? BackgroundGenerationService()
        self.backgroundRemovalService = backgroundRemovalService ?? BackgroundRemovalService()
    }

    func configure(
        context: ModelContext,
        project: CompositionProject,
        session: CaptureSession?,
        selectedImageIDs: Set<UUID>
    ) {
        logger.debug("configure invoked. projectID=\(project.id.uuidString, privacy: .public) sessionID=\(session?.id.uuidString ?? "nil", privacy: .public) selectedIDs=\(selectedImageIDs.debugDescription, privacy: .public)")
        self.modelContext = context
        self.activeProject = project

        if let session {
            generatedBackgrounds = session.generatedBackgrounds.sorted { $0.createdAt > $1.createdAt }
            if let primary = session.primaryCategory {
                selectedCategory = primary
            }
            // Removed automatic synchronization - users will manually add captures
            loadBackgroundLibrary(excluding: session)
        } else {
            generatedBackgrounds = []
            backgroundLibrary = [:]
        }

        if let projectBackground = project.background,
           generatedBackgrounds.contains(where: { $0.id == projectBackground.id }) == false {
            generatedBackgrounds.insert(projectBackground, at: 0)
        }
        logger.debug("Configuration complete. layers=\(project.layers.count, privacy: .public) backgrounds=\(self.generatedBackgrounds.count, privacy: .public)")
    }

    private func synchronizeSubjectLayers(
        for project: CompositionProject,
        from session: CaptureSession,
        selectedIDs: Set<UUID>,
        context: ModelContext
    ) {
        var requiresSave = false

        let sortedImages = session.images
            .filter { selectedIDs.isEmpty ? true : selectedIDs.contains($0.id) }
            .sorted { $0.captureDate < $1.captureDate }

        let existingSubjectLayers = project.layers.filter { $0.processedImageID != nil }
        let existingIDs = Set(existingSubjectLayers.compactMap { $0.processedImageID })

        if selectedIDs.isEmpty == false {
            let layersToRemove = existingSubjectLayers.filter { layer in
                guard let identifier = layer.processedImageID else { return false }
                return selectedIDs.contains(identifier) == false
            }

            if layersToRemove.isEmpty == false {
                for layer in layersToRemove {
                    project.layers.removeAll { $0.id == layer.id }
                    context.delete(layer)
                }
                requiresSave = true
            }
        }

        var updatedExistingIDs = existingIDs

        for image in sortedImages where updatedExistingIDs.contains(image.id) == false {
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
            updatedExistingIDs.insert(image.id)
            requiresSave = true
        }

        if requiresSave {
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
        let layerName = name ?? generateDefaultLayerName(for: type)
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

    func importLayer(
        from image: UIImage,
        removeBackground: Bool,
        name: String? = nil,
        type: CompositionLayer.LayerType = .upload
    ) {
        guard removeBackground else {
            addLayer(from: image, name: name, type: type, processedImageID: nil)
            isImportingLayer = false
            return
        }

        Task.detached(priority: .userInitiated) { [weak self, backgroundRemovalService] in
            guard let self else { return }

            await MainActor.run {
                self.isImportingLayer = true
            }

            do {
                let processedImage = try await backgroundRemovalService.removeBackground(from: image)
                await MainActor.run {
                    let resolvedType: CompositionLayer.LayerType = removeBackground ? .subject : type
                    let resolvedName = name ?? self.generateDefaultLayerName(for: resolvedType)
                    self.addLayer(
                        from: processedImage,
                        name: resolvedName,
                        type: resolvedType,
                        processedImageID: nil
                    )
                    self.isImportingLayer = false
                }
            } catch {
                await MainActor.run {
                    self.isImportingLayer = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    private func generateDefaultLayerName(for type: CompositionLayer.LayerType) -> String {
        guard let project = activeProject else { return "Layer" }
        let count = project.layers.count + 1
        switch type {
        case .subject:
            return "Subject \(count)"
        case .upload:
            return "Imported Layer \(count)"
        case .background:
            return "Background \(count)"
        case .adjustment:
            return "Adjustment \(count)"
        case .text:
            return "Text \(count)"
        case .object:
            return "Object \(count)"
        }
    }

    func addCapturedImages(from session: CaptureSession, selectedIDs: Set<UUID>) {
        guard let context = modelContext, let project = activeProject else { return }

        let imagesToAdd = session.images.filter { selectedIDs.contains($0.id) }

        for image in imagesToAdd {
            // Check if layer already exists for this image
            if project.layers.contains(where: { $0.processedImageID == image.id }) {
                continue
            }

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
        }

        normalizeOrder(in: project)
        saveAsync()
    }

    func addTextLayer(text: String, fontSize: Double, color: String) {
        guard let context = modelContext, let project = activeProject else { return }

        // Create an image representation of the text
        let textImage = renderTextToImage(
            text: text,
            fontSize: fontSize,
            colorHex: color
        )

        guard let imageData = textImage.pngData() else {
            errorMessage = "Failed to create text layer"
            showError = true
            return
        }

        let newLayer = CompositionLayer(
            name: text.isEmpty ? "Text \(project.layers.count + 1)" : text,
            order: project.layers.count,
            imageData: imageData,
            type: .text,
            project: project,
            textContent: text,
            textFontSize: fontSize,
            textColor: color
        )

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

    func generateObjectLayer(prompt: String, service: String) async {
        guard let context = modelContext, let project = activeProject else { return }

        // TODO: Integrate with nano bannanna API
        // For now, create a placeholder layer
        // This will need to be replaced with actual API integration

        // Create a placeholder image
        let placeholderSize = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: placeholderSize)
        let placeholderImage = renderer.image { context in
            context.cgContext.setFillColor(UIColor.systemGray5.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: placeholderSize))

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.systemGray
            ]
            let string = NSAttributedString(string: "Object: \(prompt)", attributes: attributes)
            let textSize = string.size()
            let textRect = CGRect(
                x: (placeholderSize.width - textSize.width) / 2,
                y: (placeholderSize.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            string.draw(in: textRect)
        }

        guard let imageData = placeholderImage.pngData() else {
            errorMessage = "Failed to create object layer"
            showError = true
            return
        }

        let newLayer = CompositionLayer(
            name: "Object: \(prompt.prefix(20))",
            order: project.layers.count,
            imageData: imageData,
            type: .object,
            project: project,
            objectPrompt: prompt,
            objectGenerationService: service
        )

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

    private func renderTextToImage(text: String, fontSize: Double, colorHex: String) -> UIImage {
        let font = UIFont.systemFont(ofSize: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: colorFromHex(colorHex) ?? .black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        // Add padding
        let padding: CGFloat = 20
        let imageSize = CGSize(
            width: size.width + padding * 2,
            height: size.height + padding * 2
        )

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.clear.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: imageSize))

            let textRect = CGRect(
                x: padding,
                y: padding,
                width: size.width,
                height: size.height
            )
            attributedString.draw(in: textRect)
        }
    }

    private func colorFromHex(_ hex: String) -> UIColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        return UIColor(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    func cleanLayer(_ layer: CompositionLayer) {
        guard let image = UIImage(data: layer.imageData) else {
            errorMessage = CameraError.backgroundRemovalFailed.localizedDescription
            showError = true
            return
        }

        let layerID = layer.id

        Task.detached(priority: .userInitiated) { [weak self, backgroundRemovalService] in
            guard let self else { return }

            await MainActor.run {
                self.cleaningLayerIDs.insert(layerID)
            }

            do {
                let cleaned = try await backgroundRemovalService.removeBackground(from: image)
                guard let cleanedData = cleaned.pngData() else {
                    throw CameraError.backgroundRemovalFailed
                }

                await MainActor.run {
                    layer.imageData = cleanedData
                    layer.project?.touch()
                    self.cleaningLayerIDs.remove(layerID)
                    if let processedImageID = layer.processedImageID {
                        self.updateProcessedImage(id: processedImageID, data: cleanedData)
                    }
                    self.saveAsync()
                }
            } catch {
                await MainActor.run {
                    self.cleaningLayerIDs.remove(layerID)
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }

    func canClean(layer: CompositionLayer) -> Bool {
        layer.type == .subject || layer.type == .upload
    }

    private func updateProcessedImage(id: UUID, data: Data) {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<ProcessedImage>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1

        do {
            if let processedImage = try context.fetch(descriptor).first {
                processedImage.imageData = data
                processedImage.captureDate = Date()
                processedImage.session?.touch()
            }
        } catch {
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

    private func loadBackgroundLibrary(excluding session: CaptureSession) {
        guard let modelContext else {
            backgroundLibrary = [:]
            return
        }

        let descriptor = FetchDescriptor<GeneratedBackground>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        do {
            let backgrounds = try modelContext.fetch(descriptor)
            let excludedIDs = Set(session.generatedBackgrounds.map(\.id))
            var grouped: [BackgroundCategory: [GeneratedBackground]] = [:]

            for background in backgrounds where excludedIDs.contains(background.id) == false {
                var entries = grouped[background.category] ?? []
                entries.append(background)
                entries.sort { $0.createdAt > $1.createdAt }
                grouped[background.category] = entries
            }

            backgroundLibrary = grouped
        } catch {
            backgroundLibrary = [:]
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func importBackgroundFromLibrary(_ background: GeneratedBackground, into session: CaptureSession) {
        guard let context = modelContext else { return }

        let copy = GeneratedBackground(
            prompt: background.prompt,
            category: background.category,
            aspectRatio: background.aspectRatio,
            isCommunityShared: background.isCommunityShared,
            session: session,
            imageData: background.imageData
        )

        activeProject?.background = copy
        activeProject?.touch()
        session.generatedBackgrounds.append(copy)
        generatedBackgrounds.insert(copy, at: 0)

        context.insert(copy)

        do {
            try context.save()
            loadBackgroundLibrary(excluding: session)
        } catch {
            context.delete(copy)
            generatedBackgrounds.removeAll { $0.id == copy.id }
            errorMessage = error.localizedDescription
            showError = true
        }
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

    func renderCompositeImage(size: CGSize) -> UIImage? {
        guard let project = activeProject else { return nil }
        logger.debug("renderCompositeImage requested. canvasSize=\(String(describing: size), privacy: .public) layerCount=\(project.layers.count, privacy: .public)")
        let image = CompositionRenderer.render(project: project, canvasSize: size)
        if let image {
            logger.debug("renderCompositeImage success. renderedSize=\(image.size.debugDescription, privacy: .public)")
        } else {
            logger.error("renderCompositeImage failed to produce output.")
        }
        return image
    }

    var hasBackgroundLibrary: Bool {
        backgroundLibrary.values.contains { $0.isEmpty == false }
    }
}

// swiftlint:enable type_body_length function_body_length file_length
