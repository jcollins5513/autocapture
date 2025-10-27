//
//  EdgeCleanupView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import Combine
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
    @Published var maskImage: UIImage
    let originalImage: UIImage
    private let backgroundRemovalService = BackgroundRemovalService()
    private let processedImage: ProcessedImage
    private var maskHistory: [UIImage] = []
    private let maxUndoStates = 15
    @Published private(set) var canUndo = false

    init?(image: ProcessedImage) {
        guard let original = image.originalImage, let mask = image.maskImage, let foreground = image.image else {
            return nil
        }
        self.originalImage = original
        self.maskImage = mask
        self.previewImage = foreground
        self.processedImage = image
    }

    func beginEditingSession() {
        if maskHistory.count >= maxUndoStates {
            maskHistory.removeFirst()
        }
        maskHistory.append(maskImage)
        canUndo = true
    }

    func cancelEditingSession() {
        guard !maskHistory.isEmpty else { return }
        maskHistory.removeLast()
        canUndo = !maskHistory.isEmpty
    }

    fileprivate func applyStroke(at point: CGPoint, brushSize: CGFloat, mode: MaskEditingMode) {
        guard mode != .lasso else { return }
        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = maskImage.scale
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: maskImage.size, format: rendererFormat)
        let radius = brushSize / 2
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: brushSize,
            height: brushSize
        )

        let updatedMask = renderer.image { ctx in
            maskImage.draw(in: CGRect(origin: .zero, size: maskImage.size))
            ctx.cgContext.setFillColor(mode == .add ? UIColor.white.cgColor : UIColor.black.cgColor)
            ctx.cgContext.setBlendMode(.normal)
            ctx.cgContext.fillEllipse(in: rect)
        }

        maskImage = updatedMask
        updatePreview()
        canUndo = !maskHistory.isEmpty
    }

    func applyLasso(with points: [CGPoint]) {
        guard points.count > 2 else { return }

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = maskImage.scale
        rendererFormat.opaque = false

        let renderer = UIGraphicsImageRenderer(size: maskImage.size, format: rendererFormat)

        let updatedMask = renderer.image { ctx in
            maskImage.draw(in: CGRect(origin: .zero, size: maskImage.size))

            ctx.cgContext.setShouldAntialias(true)
            ctx.cgContext.setFillColor(UIColor.black.cgColor)

            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            ctx.cgContext.addPath(path)
            ctx.cgContext.fillPath()
        }

        maskImage = updatedMask
        updatePreview()
        canUndo = !maskHistory.isEmpty
    }

    func undoLastChange() {
        guard let previousMask = maskHistory.popLast() else { return }
        maskImage = previousMask
        canUndo = !maskHistory.isEmpty
        updatePreview()
    }

    private func updatePreview() {
        do {
            let updated = try backgroundRemovalService.apply(mask: maskImage, to: originalImage)
            previewImage = updated
        } catch {
            // If applying the mask fails, we keep the previous preview to avoid user disruption.
        }
    }

    func commitChanges(context: ModelContext) throws {
        processedImage.imageData = previewImage.pngData() ?? processedImage.imageData
        processedImage.maskImageData = maskImage.pngData()
        processedImage.originalImageData = originalImage.pngData()
        try context.save()
    }
}

struct EdgeCleanupView: View {
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
    @State private var lassoViewPoints: [CGPoint] = []

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
                if newMode != .lasso {
                    lassoImagePoints = []
                    lassoViewPoints = []
                }
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
                    .gesture(drawingGesture(in: geometry))
                    .overlay(lassoOverlay())
            }
        }
        .aspectRatio(previewAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func lassoOverlay() -> some View {
        if editingMode == .lasso && lassoViewPoints.count > 1 {
            let path = Path { path in
                path.addLines(lassoViewPoints)
                if let first = lassoViewPoints.first {
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

    private struct ImageCoordinate {
        let point: CGPoint
        let scale: CGFloat
        let origin: CGPoint
    }

    private func drawingGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // Only process gestures that are within the image bounds
                guard let mapping = imageCoordinate(from: value.location, in: geometry) else { return }
                
                if !isDrawing {
                    viewModel.beginEditingSession()
                    isDrawing = true
                    if editingMode == .lasso {
                        lassoImagePoints = []
                        lassoViewPoints = []
                    }
                }

                switch editingMode {
                case .add, .erase:
                    viewModel.applyStroke(
                        at: mapping.point,
                        brushSize: brushSizeInImageSpace(for: mapping.scale),
                        mode: editingMode
                    )
                case .lasso:
                    lassoImagePoints.append(mapping.point)
                    let viewPoint = CGPoint(
                        x: mapping.origin.x + (mapping.point.x * mapping.scale),
                        y: mapping.origin.y + (mapping.point.y * mapping.scale)
                    )
                    lassoViewPoints.append(viewPoint)
                }
            }
            .onEnded { value in
                guard isDrawing else { return }
                
                // Only process end gestures that are within the image bounds
                guard let mapping = imageCoordinate(from: value.location, in: geometry) else {
                    // If gesture ended outside image bounds, just clean up state
                    isDrawing = false
                    lassoImagePoints = []
                    lassoViewPoints = []
                    return
                }

                switch editingMode {
                case .add, .erase:
                    viewModel.applyStroke(
                        at: mapping.point,
                        brushSize: brushSizeInImageSpace(for: mapping.scale),
                        mode: editingMode
                    )
                case .lasso:
                    let finalViewPoint = CGPoint(
                        x: mapping.origin.x + (mapping.point.x * mapping.scale),
                        y: mapping.origin.y + (mapping.point.y * mapping.scale)
                    )
                    lassoImagePoints.append(mapping.point)
                    lassoViewPoints.append(finalViewPoint)

                    if lassoImagePoints.count > 2 {
                        viewModel.applyLasso(with: lassoImagePoints)
                    } else {
                        viewModel.cancelEditingSession()
                    }
                }
                
                // Clean up drawing state
                isDrawing = false
                lassoImagePoints = []
                lassoViewPoints = []
            }
    }

    private func imageCoordinate(from location: CGPoint, in geometry: GeometryProxy) -> ImageCoordinate? {
        let imageSize = viewModel.previewImage.size
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let scale = min(geometry.size.width / imageSize.width, geometry.size.height / imageSize.height)
        let renderedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (geometry.size.width - renderedSize.width) / 2,
            y: (geometry.size.height - renderedSize.height) / 2
        )

        let frame = CGRect(origin: origin, size: renderedSize)
        guard frame.contains(location) else { return nil }

        let normalizedX = (location.x - origin.x) / scale
        let normalizedY = (location.y - origin.y) / scale

        return ImageCoordinate(point: CGPoint(x: normalizedX, y: normalizedY), scale: scale, origin: origin)
    }

    private func brushSizeInImageSpace(for scale: CGFloat) -> CGFloat {
        guard scale > 0 else { return brushSize }
        let adjusted = brushSize / scale
        return max(adjusted, 1)
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
        do {
            try viewModel.commitChanges(context: modelContext)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
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
