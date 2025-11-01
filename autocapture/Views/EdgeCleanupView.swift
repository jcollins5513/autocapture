//
//  EdgeCleanupView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import Combine
import CoreImage
import ImageIO
import OSLog
import SwiftData
import SwiftUI
import UIKit

private enum MaskEditingMode: String, CaseIterable, Identifiable {
    case add
    case erase
    case lasso

    var id: String { rawValue }

    var label: String {
        switch self {
        case .add:
            return "Restore"
        case .erase:
            return "Erase"
        case .lasso:
            return "Lasso Erase"
        }
    }

    var systemImage: String {
        switch self {
        case .add:
            return "paintbrush.pointed"
        case .erase:
            return "eraser"
        case .lasso:
            return "lasso"
        }
    }
}

final class EdgeCleanupViewModel: ObservableObject {
    @Published var previewImage: UIImage
    private var workingMask: UIImage
    private var workingPreview: UIImage
    private let workingOriginal: UIImage
    private let originalOrientation: UIImage.Orientation
    private let backgroundRemovalService = BackgroundRemovalService()
    private let processedImage: ProcessedImage
    private var maskHistory: [UIImage] = []
    private let maxUndoStates = 15
    @Published private(set) var canUndo = false
    private let logger = Logger(subsystem: "com.autocapture", category: "EdgeCleanupViewModel")
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init?(image: ProcessedImage) {
        guard let original = image.originalImage, let mask = image.maskImage, let foreground = image.image else {
            return nil
        }
        originalOrientation = original.imageOrientation
        workingOriginal = EdgeCleanupViewModel.normalizedToUp(original)
        workingMask = EdgeCleanupViewModel.normalizedToUp(mask)
        workingPreview = EdgeCleanupViewModel.normalizedToUp(foreground)
        previewImage = EdgeCleanupViewModel.reorientedImage(workingPreview, to: originalOrientation)
        self.processedImage = image
        let originalDesc = self.describe(image: original)
        let workingOriginalDesc = self.describe(image: self.workingOriginal)
        let maskDesc = self.describe(image: mask)
        logger.debug("EdgeCleanupViewModel initialized. original=\(originalDesc, privacy: .public) workingOriginal=\(workingOriginalDesc, privacy: .public) mask=\(maskDesc, privacy: .public)")
    }

    func beginEditingSession() {
        if maskHistory.count >= maxUndoStates {
            maskHistory.removeFirst()
        }
        maskHistory.append(workingMask)
        canUndo = true
        logger.debug("Begin editing session. historyCount=\(self.maskHistory.count, privacy: .public)")
        logMaskSnapshot(context: "beginEditingSession")
    }

    func cancelEditingSession() {
        guard !maskHistory.isEmpty else { return }
        maskHistory.removeLast()
        canUndo = !maskHistory.isEmpty
        logger.debug("Cancel editing session. historyCount=\(self.maskHistory.count, privacy: .public)")
        logMaskSnapshot(context: "cancelEditingSession")
    }

    fileprivate func applyStroke(at point: CGPoint, previousPoint: CGPoint?, brushSize: CGFloat, mode: MaskEditingMode) {
        guard mode != .lasso else { return }
        logger.debug("Apply stroke. mode=\(mode.rawValue, privacy: .public) point=\(point.debugDescription, privacy: .public) previous=\(String(describing: previousPoint?.debugDescription), privacy: .public) brushSize=\(brushSize, privacy: .public)")
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = workingMask.scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: workingMask.size, format: rendererFormat)

        let updatedMask = renderer.image { ctx in
            workingMask.draw(in: CGRect(origin: .zero, size: workingMask.size))
            let context = ctx.cgContext
            context.setBlendMode(.normal)
            let color = mode == .add ? UIColor.white.cgColor : UIColor.black.cgColor
            context.setStrokeColor(color)
            context.setFillColor(color)
            context.setLineWidth(brushSize)
            context.setLineCap(.round)

            if let previousPoint {
                context.move(to: previousPoint)
                context.addLine(to: point)
                context.strokePath()
            } else {
                let radius = brushSize / 2
                let rect = CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: brushSize,
                    height: brushSize
                )
                context.fillEllipse(in: rect)
            }
        }

        workingMask = updatedMask
        updatePreview()
        canUndo = !maskHistory.isEmpty
        logger.debug("Stroke applied. canUndo=\(self.canUndo, privacy: .public)")
        logMaskSnapshot(context: "postStroke", samplePoint: point)
    }

    func applyLasso(with points: [CGPoint]) {
        guard points.count > 2 else { return }
        logger.debug("Apply lasso. pointsCount=\(points.count, privacy: .public)")
        if let bounding = boundingRect(for: points) {
            let normalizedArea = (bounding.width * bounding.height) / max(workingMask.size.width * workingMask.size.height, 1)
            logger.debug("Lasso bounds=\(String(describing: bounding), privacy: .public) normalizedArea=\(normalizedArea, privacy: .public)")
        }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = workingMask.scale
        rendererFormat.opaque = false

        let renderer = UIGraphicsImageRenderer(size: workingMask.size, format: rendererFormat)

        let updatedMask = renderer.image { ctx in
            workingMask.draw(in: CGRect(origin: .zero, size: workingMask.size))

            ctx.cgContext.setShouldAntialias(true)
            ctx.cgContext.setFillColor(UIColor.black.cgColor)

            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            ctx.cgContext.addPath(path)
            ctx.cgContext.fillPath()
        }

        workingMask = updatedMask
        updatePreview()
        canUndo = !maskHistory.isEmpty
        logger.debug("Lasso applied. canUndo=\(self.canUndo, privacy: .public)")
        logMaskSnapshot(context: "postLasso", samplePoint: points.first)
    }

    func undoLastChange() {
        guard let previousMask = maskHistory.popLast() else { return }
        workingMask = previousMask
        canUndo = !maskHistory.isEmpty
        updatePreview()
        logger.debug("Undo executed. historyCount=\(self.maskHistory.count, privacy: .public) canUndo=\(self.canUndo, privacy: .public)")
        logMaskSnapshot(context: "undoLastChange")
    }

    private func updatePreview() {
        logger.debug("Updating preview with workingMask=\(self.describe(image: self.workingMask), privacy: .public)")
        do {
            let updated = try backgroundRemovalService.apply(mask: workingMask, to: workingOriginal)
            workingPreview = EdgeCleanupViewModel.normalizedToUp(updated)
            let displayPreview = EdgeCleanupViewModel.reorientedImage(workingPreview, to: originalOrientation)
            previewImage = displayPreview
            logger.debug("Preview updated successfully. preview=\(self.describe(image: displayPreview), privacy: .public)")
            logMaskSnapshot(context: "afterPreviewUpdate")
        } catch {
            // If applying the mask fails, we keep the previous preview to avoid user disruption.
            logger.error("Failed to update preview. error=\(String(describing: error), privacy: .public)")
        }
    }

    func commitChanges(context: ModelContext) throws {
        let finalPreview = EdgeCleanupViewModel.reorientedImage(workingPreview, to: originalOrientation)
        let finalMask = EdgeCleanupViewModel.reorientedImage(workingMask, to: originalOrientation)
        let finalOriginal = EdgeCleanupViewModel.reorientedImage(workingOriginal, to: originalOrientation)

        processedImage.imageData = finalPreview.pngData() ?? processedImage.imageData
        processedImage.maskImageData = finalMask.pngData()
        processedImage.originalImageData = finalOriginal.pngData()
        try context.save()
        logger.debug("Changes committed to storage.")
        logMaskSnapshot(context: "commitChanges")
    }

    private func logMaskSnapshot(context: String, samplePoint: CGPoint? = nil) {
        guard let cgImage = workingMask.cgImage else {
            logger.debug("\(context): mask cgImage unavailable.")
            return
        }
        let dimensions = "\(cgImage.width)x\(cgImage.height)"
        let alphaInfo = cgImage.alphaInfo.rawValue
        var sampleDescription = "n/a"
        if let samplePoint,
           let sample = samplePixelDescription(in: cgImage, at: samplePoint) {
            sampleDescription = sample
        }
        logger.debug("\(context): maskDimensions=\(dimensions, privacy: .public) orientation=\(self.workingMask.imageOrientation.rawValue, privacy: .public) alphaInfo=\(alphaInfo, privacy: .public) bytesPerRow=\(cgImage.bytesPerRow, privacy: .public) sample=\(sampleDescription, privacy: .public)")
    }

    private func samplePixelDescription(in cgImage: CGImage, at point: CGPoint) -> String? {
        let x = max(0, min(Int(point.x.rounded()), cgImage.width - 1))
        let y = max(0, min(Int(point.y.rounded()), cgImage.height - 1))
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data else {
            return nil
        }

        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        let bytesPerRow = cgImage.bytesPerRow
        let offset = y * bytesPerRow + x * bytesPerPixel

        guard offset >= 0,
              offset + bytesPerPixel <= CFDataGetLength(data) else {
            return nil
        }

        guard let buffer = CFDataGetBytePtr(data) else {
            return nil
        }
        var components = [String]()
        for index in 0..<bytesPerPixel {
            components.append(String(buffer[offset + index]))
        }
        return "(\(components.joined(separator: ",")))@(\(x),\(y))"
    }
    private func boundingRect(for points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func convertToWorking(point: CGPoint, in displaySize: CGSize) -> CGPoint {
        guard displaySize.width > 0, displaySize.height > 0 else { return point }
        let normalizedX = point.x / displaySize.width
        let normalizedY = point.y / displaySize.height
        let width = workingMask.size.width
        let height = workingMask.size.height

        switch originalOrientation {
        case .up:
            return CGPoint(x: normalizedX * width, y: normalizedY * height)
        case .down:
            return CGPoint(x: (1 - normalizedX) * width, y: (1 - normalizedY) * height)
        case .left:
            return CGPoint(x: (1 - normalizedY) * width, y: normalizedX * height)
        case .right:
            return CGPoint(x: normalizedY * width, y: (1 - normalizedX) * height)
        case .upMirrored:
            return CGPoint(x: (1 - normalizedX) * width, y: normalizedY * height)
        case .downMirrored:
            return CGPoint(x: normalizedX * width, y: (1 - normalizedY) * height)
        case .leftMirrored:
            return CGPoint(x: normalizedY * width, y: normalizedX * height)
        case .rightMirrored:
            return CGPoint(x: (1 - normalizedY) * width, y: (1 - normalizedX) * height)
        @unknown default:
            return CGPoint(x: normalizedX * width, y: normalizedY * height)
        }
    }

    func convertToDisplay(point: CGPoint, in displaySize: CGSize) -> CGPoint {
        let width = workingMask.size.width
        let height = workingMask.size.height
        guard width > 0, height > 0 else { return point }

        let normalizedX: CGFloat
        let normalizedY: CGFloat

        switch originalOrientation {
        case .up:
            normalizedX = point.x / width
            normalizedY = point.y / height
        case .down:
            normalizedX = 1 - (point.x / width)
            normalizedY = 1 - (point.y / height)
        case .left:
            normalizedX = point.y / height
            normalizedY = 1 - (point.x / width)
        case .right:
            normalizedX = 1 - (point.y / height)
            normalizedY = point.x / width
        case .upMirrored:
            normalizedX = 1 - (point.x / width)
            normalizedY = point.y / height
        case .downMirrored:
            normalizedX = point.x / width
            normalizedY = 1 - (point.y / height)
        case .leftMirrored:
            normalizedX = point.y / height
            normalizedY = point.x / width
        case .rightMirrored:
            normalizedX = 1 - (point.y / height)
            normalizedY = 1 - (point.x / width)
        @unknown default:
            normalizedX = point.x / width
            normalizedY = point.y / height
        }

        return CGPoint(
            x: normalizedX * displaySize.width,
            y: normalizedY * displaySize.height
        )
    }

    private func describe(image: UIImage) -> String {
        let orientation = image.imageOrientation.rawValue
        let scale = image.scale
        let sizeString = image.size.debugDescription
        let cgInfo: String
        if let cgImage = image.cgImage {
            cgInfo = "\(cgImage.width)x\(cgImage.height)"
        } else {
            cgInfo = "nil"
        }
        return "size=\(sizeString) orientation=\(orientation) scale=\(scale) cg=\(cgInfo)"
    }

    private static func normalizedToUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up, let ciImage = CIImage(image: image) else {
            return image
        }

        let oriented = ciImage.oriented(.up)
        guard let cgImage = ciContext.createCGImage(oriented, from: oriented.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private static func reorientedImage(_ image: UIImage, to orientation: UIImage.Orientation) -> UIImage {
        let base = normalizedToUp(image)
        guard orientation != .up, let ciImage = CIImage(image: base) else {
            return base
        }

        let oriented = ciImage.oriented(cgOrientation(for: orientation))
        guard let cgImage = ciContext.createCGImage(oriented, from: oriented.extent) else {
            return base
        }

        return UIImage(cgImage: cgImage, scale: base.scale, orientation: .up)
    }

    private static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

private struct MagnifyingGlassView: View {
    let image: UIImage
    let touchLocation: CGPoint
    let imageOrigin: CGPoint
    let imageScale: CGFloat
    let position: CGPoint
    let magnification: CGFloat
    let diameter: CGFloat

    var body: some View {
        // Calculate the region of the image to show (in image coordinate space)
        // touchLocation is in display image coordinates (already normalized to display size)
        let zoomedRegionSize = diameter / magnification
        let sourceRect = CGRect(
            x: max(0, min(image.size.width - zoomedRegionSize, touchLocation.x - zoomedRegionSize / 2)),
            y: max(0, min(image.size.height - zoomedRegionSize, touchLocation.y - zoomedRegionSize / 2)),
            width: zoomedRegionSize,
            height: zoomedRegionSize
        )

        // Create a cropped and magnified version of the image
        if let cgImage = image.cgImage,
           let croppedCGImage = cgImage.cropping(to: CGRect(
               x: sourceRect.origin.x * image.scale,
               y: sourceRect.origin.y * image.scale,
               width: sourceRect.width * image.scale,
               height: sourceRect.height * image.scale
           )) {
            Image(uiImage: UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation))
                .resizable()
                .scaledToFill()
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .position(position)
                .allowsHitTesting(false)
        }
    }
}

struct EdgeCleanupView: View {
    private static let logger = Logger(subsystem: "com.autocapture", category: "EdgeCleanupView")
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @StateObject private var viewModel: EdgeCleanupViewModel
    @State private var brushSize: CGFloat = 40
    @State private var editingMode: MaskEditingMode = .add
    @State private var errorMessage: String?
    @State private var isShowingError = false
    @State private var isDrawing = false
    @State private var lassoImagePoints: [CGPoint] = []
    @State private var magnifierState: MagnifierState?
    @State private var fingerLocation: CGPoint?
    @State private var zoomScale: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var isZooming = false
    private let magnifierDiameter: CGFloat = 140
    private let magnificationAmount: CGFloat = 2.5
    @State private var lastBrushImagePoint: CGPoint?
    @State private var magnifierTouchLocation: CGPoint?
    private let lassoPointSpacing: CGFloat = 18
    private let lassoSnapRatio: CGFloat = 1.8

    init(image: ProcessedImage) {
        guard let viewModel = EdgeCleanupViewModel(image: image) else {
            fatalError("EdgeCleanupView requires a ProcessedImage with original and mask data.")
        }
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    cleanupCanvas
                    editingControls
                }
                .padding()
            }
            .navigationTitle("Clean Edges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyChanges()
                    }
                }
            }
            .alert("Unable to save", isPresented: $isShowingError) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
            .onChange(of: editingMode) { _, newMode in
                lastBrushImagePoint = nil
                magnifierTouchLocation = nil
                if newMode != .lasso {
                    lassoImagePoints = []
                }
                magnifierState = nil
                fingerLocation = nil
            }
        }
    }

    private var cleanupCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                checkerboardBackground(in: geometry.size)
                Image(uiImage: viewModel.previewImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(zoomScale)
                    .gesture(drawingGesture(in: geometry))
                    .overlay(lassoOverlay(in: geometry))

                if let magnifierState {
                    MagnifierLens(
                        image: viewModel.previewImage,
                        state: magnifierState,
                        diameter: magnifierDiameter,
                        magnification: magnificationAmount
                    )
                    .transition(.opacity)
                }

                if let fingerLocation {
                    fingerIndicator(at: fingerLocation)
                }
            }
            .simultaneousGesture(magnificationGesture())
        }
        .aspectRatio(previewAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func lassoOverlay(in geometry: GeometryProxy) -> some View {
        if editingMode == .lasso {
            let viewPoints = lassoViewPoints(in: geometry)
            if viewPoints.count > 1 {
                let path = Path { path in
                    path.addLines(viewPoints)
                    if let first = viewPoints.first {
                        path.addLine(to: first)
                    }
                }

                path
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .overlay(
                        path
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
        }
    }

    private func lassoViewPoints(in geometry: GeometryProxy) -> [CGPoint] {
        guard !lassoImagePoints.isEmpty else { return [] }
        let imageSize = viewModel.previewImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return [] }
        let frame = imageFrame(in: geometry)
        guard !frame.isEmpty else { return [] }
        let scale = frame.size.width / imageSize.width
        return lassoImagePoints.map { point in
            CGPoint(
                x: frame.origin.x + point.x * scale,
                y: frame.origin.y + point.y * scale
            )
        }
    }

    private func fingerIndicator(at location: CGPoint) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.18))
            .frame(width: 34, height: 34)
            .overlay(
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 0.5)
            )
            .position(location)
            .allowsHitTesting(false)
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                isZooming = true
                let proposed = accumulatedZoom * value
                zoomScale = clampedZoom(proposed)
                magnifierState = nil
                fingerLocation = nil
            }
            .onEnded { value in
                let proposed = accumulatedZoom * value
                accumulatedZoom = clampedZoom(proposed)
                zoomScale = accumulatedZoom
                DispatchQueue.main.async {
                    isZooming = false
                }
            }
    }

    private func imageFrame(in geometry: GeometryProxy) -> CGRect {
        let imageSize = viewModel.previewImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let baseScale = min(geometry.size.width / imageSize.width, geometry.size.height / imageSize.height)
        let scale = baseScale * zoomScale
        let renderedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (geometry.size.width - renderedSize.width) / 2,
            y: (geometry.size.height - renderedSize.height) / 2
        )
        return CGRect(origin: origin, size: renderedSize)
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        max(1, min(value, 4))
    }

    private func makeMagnifierState(for mapping: ImageCoordinate, viewLocation: CGPoint, geometry: GeometryProxy) -> MagnifierState? {
        guard !mapping.frame.isEmpty else { return nil }
        let center = magnifierPosition(for: viewLocation, magnifierDiameter: magnifierDiameter, in: geometry.size)
        return MagnifierState(
            focusLocation: viewLocation,
            imageFrame: mapping.frame,
            magnifierCenter: center
        )
    }

    private func magnifierPosition(for location: CGPoint, magnifierDiameter: CGFloat, in availableSize: CGSize) -> CGPoint {
        let offset = magnifierDiameter * 0.75
        let half = magnifierDiameter / 2
        var proposed = CGPoint(x: location.x + offset, y: location.y - offset)

        if proposed.x + half > availableSize.width {
            proposed.x = location.x - offset
        }

        if proposed.x - half < 0 {
            proposed.x = half
        }

        if proposed.y - half < 0 {
            proposed.y = location.y + offset
        }

        if proposed.y + half > availableSize.height {
            proposed.y = max(location.y - offset, half)
        }

        proposed.x = min(max(proposed.x, half), max(availableSize.width - half, half))
        proposed.y = min(max(proposed.y, half), max(availableSize.height - half, half))

        return proposed
    }

    private struct MagnifierLens: View {
        let image: UIImage
        let state: MagnifierState
        let diameter: CGFloat
        let magnification: CGFloat

        private var anchorPoint: UnitPoint {
            guard state.imageFrame.width > 0, state.imageFrame.height > 0 else {
                return .center
            }

            let normalizedX = (state.focusLocation.x - state.imageFrame.minX) / state.imageFrame.width
            let normalizedY = (state.focusLocation.y - state.imageFrame.minY) / state.imageFrame.height

            return UnitPoint(x: normalizedX, y: normalizedY)
        }

        var body: some View {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: state.imageFrame.width, height: state.imageFrame.height)
                .scaleEffect(magnification, anchor: anchorPoint)
                .offset(
                    x: (state.imageFrame.midX - state.focusLocation.x) * (magnification - 1),
                    y: (state.imageFrame.midY - state.focusLocation.y) * (magnification - 1)
                )
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    crosshair
                )
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.25))
                )
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                .position(state.magnifierCenter)
                .allowsHitTesting(false)
        }

        private var crosshair: some View {
            let lineWidth: CGFloat = 1
            return ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: diameter, height: lineWidth)
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: lineWidth, height: diameter)
            }
            .blendMode(.plusLighter)
        }
    }

    private struct ImageCoordinate {
        let point: CGPoint
        let scale: CGFloat
        let frame: CGRect
    }

    private struct MagnifierState: Equatable {
        let focusLocation: CGPoint
        let imageFrame: CGRect
        let magnifierCenter: CGPoint
    }

    private func drawingGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isZooming else { return }
                // Only process gestures that are within the image bounds
                guard let mapping = imageCoordinate(from: value.location, in: geometry) else { return }

                if !isDrawing {
                    viewModel.beginEditingSession()
                    isDrawing = true
                    Self.logger.debug("Drawing session started. mode=\(self.editingMode.rawValue, privacy: .public)")
                    lastBrushImagePoint = nil
                    if editingMode == .lasso {
                        lassoImagePoints = []
                    }
                }

                switch editingMode {
                case .add, .erase:
                    let displaySize = viewModel.previewImage.size
                    let workingPoint = viewModel.convertToWorking(point: mapping.point, in: displaySize)
                    let previous = lastBrushImagePoint
                    let brushSizeImageSpace = brushSizeInImageSpace(for: mapping.scale)
                    viewModel.applyStroke(
                        at: workingPoint,
                        previousPoint: previous,
                        brushSize: brushSizeImageSpace,
                        mode: editingMode
                    )
                    lastBrushImagePoint = workingPoint
                    Self.logger.debug("Stroke applied via drag. brushSizeImageSpace=\(brushSizeImageSpace, privacy: .public)")
                case .lasso:
                    lassoImagePoints.append(mapping.point)
                }

                let viewPoint = CGPoint(
                    x: mapping.frame.origin.x + (mapping.point.x * mapping.scale),
                    y: mapping.frame.origin.y + (mapping.point.y * mapping.scale)
                )
                fingerLocation = viewPoint
                magnifierState = makeMagnifierState(for: mapping, viewLocation: viewPoint, geometry: geometry)
            }
            .onEnded { value in
                guard isDrawing else { return }

                // Only process end gestures that are within the image bounds
                guard let mapping = imageCoordinate(from: value.location, in: geometry) else {
                    // If gesture ended outside image bounds, just clean up state
                    isDrawing = false
                    lassoImagePoints = []
                    magnifierState = nil
                    fingerLocation = nil
                    return
                }

                switch editingMode {
                case .add, .erase:
                    Self.logger.debug("Stroke completed.")
                case .lasso:
                    lassoImagePoints.append(mapping.point)

                    if lassoImagePoints.count > 2 {
                        viewModel.applyLasso(with: lassoImagePoints)
                        Self.logger.debug("Lasso action executed.")
                    } else {
                        viewModel.cancelEditingSession()
                        Self.logger.debug("Lasso cancelled due to insufficient points.")
                    }
                }

                // Clean up drawing state
                isDrawing = false
                lassoImagePoints = []
                magnifierState = nil
                fingerLocation = nil
                lastBrushImagePoint = nil
                magnifierTouchLocation = nil
                Self.logger.debug("Drawing session finished.")
            }
    }

    private func imageCoordinate(from location: CGPoint, in geometry: GeometryProxy) -> ImageCoordinate? {
        let imageSize = viewModel.previewImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let frame = imageFrame(in: geometry)
        guard frame.contains(location) else { return nil }

        let normalizedX = (location.x - frame.origin.x) / frame.size.width
        let normalizedY = (location.y - frame.origin.y) / frame.size.height

        let point = CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )

        let viewToImageScale = frame.size.width / imageSize.width

        return ImageCoordinate(point: point, scale: viewToImageScale, frame: frame)
    }

    private func brushSizeInImageSpace(for scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return brushSize }
        let adjusted = brushSize / scale
        return max(adjusted, 1)
    }

    private func shouldAppendLassoPoint(_ point: CGPoint) -> Bool {
        guard let last = lassoImagePoints.last else { return true }
        let distance = hypot(point.x - last.x, point.y - last.y)
        return distance >= lassoPointSpacing
    }

    private func adjustedLassoPoint(for point: CGPoint) -> CGPoint {
        guard let last = lassoImagePoints.last else { return point }
        let dx = point.x - last.x
        let dy = point.y - last.y
        let absDx = abs(dx)
        let absDy = abs(dy)
        if absDx > absDy * lassoSnapRatio {
            return CGPoint(x: point.x, y: last.y)
        } else if absDy > absDx * lassoSnapRatio {
            return CGPoint(x: last.x, y: point.y)
        } else {
            return point
        }
    }

    private func makeViewPoint(from imagePoint: CGPoint, origin: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: origin.x + (imagePoint.x * scale),
            y: origin.y + (imagePoint.y * scale)
        )
    }

    private var editingControls: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    viewModel.undoLastChange()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canUndo || isDrawing)

                Spacer()
            }

            Picker("Mode", selection: $editingMode) {
                ForEach(MaskEditingMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Brush Size", systemImage: "circle.bottomhalf.fill")
                    Spacer()
                    Text("\(Int(brushSize)) px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $brushSize, in: 10...120)
                    .disabled(editingMode == .lasso)
            }

            Text("Drag directly on the preview to restore or erase edges around your subject.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .frame(maxWidth: .infinity)

            if editingMode == .lasso {
                Text("Draw a loop around the area to remove. The enclosed region will be erased once you lift your finger.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func checkerboardBackground(in size: CGSize) -> some View {
        let tileSize: CGFloat = 20
        Canvas { context, canvasSize in
            drawCheckerboard(context: context, canvasSize: canvasSize, tileSize: tileSize)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func drawCheckerboard(context: GraphicsContext, canvasSize: CGSize, tileSize: CGFloat) {
        let columns = Int(ceil(canvasSize.width / tileSize))
        let rows = Int(ceil(canvasSize.height / tileSize))

        for row in 0..<rows {
            for column in 0..<columns where (row + column).isMultiple(of: 2) {
                let origin = CGPoint(
                    x: CGFloat(column) * tileSize,
                    y: CGFloat(row) * tileSize
                )
                let rect = CGRect(origin: origin, size: CGSize(width: tileSize, height: tileSize))
                context.fill(Path(rect), with: .color(Color(.systemGray5)))
            }
        }
    }

    private func applyChanges() {
        EdgeCleanupView.logger.debug("applyChanges triggered.")
        do {
            try viewModel.commitChanges(context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
            EdgeCleanupView.logger.error("Failed to apply cleanup changes. error=\(String(describing: error), privacy: .public)")
        }
    }

    private var previewAspectRatio: CGFloat {
        let size = viewModel.previewImage.size
        guard size.height != 0 else { return 1 }
        return max(size.width / size.height, 0.1)
    }
}

#Preview {
    do {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: ProcessedImage.self, configurations: configuration)
        let context = container.mainContext
        let sampleImage = UIImage(systemName: "car.fill") ?? UIImage()
        let maskRenderer = UIGraphicsImageRenderer(size: sampleImage.size)
        let whiteMask = maskRenderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: sampleImage.size))
        }
        let processed = ProcessedImage(
            image: sampleImage,
            captureDate: Date(),
            subjectDescription: "Sample",
            isSubjectLifted: true,
            captureMode: .singleSubject,
            originalImage: sampleImage,
            maskImage: whiteMask
        )
        context.insert(processed)
        try context.save()
        return EdgeCleanupView(image: processed)
            .modelContainer(container)
    } catch {
        return NavigationStack {
            Text("Preview unavailable")
        }
    }
}
