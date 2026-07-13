//
//  VisualEditorView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

// swiftlint:disable file_length type_body_length

import OSLog
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct VisualEditorView: View {
    private static let logger = Logger(subsystem: "com.autocapture", category: "VisualEditorView")
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss
    @StateObject private var viewModel = VisualEditorViewModel()

    private struct ExportShareItem: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    @Bindable var project: CompositionProject
    let session: CaptureSession
    let selectedImageIDs: Set<UUID>

    private enum ImportSource {
        case photos
        case files
    }

    @State private var selectedLayer: CompositionLayer?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var showBackgroundLibrary = false
    @State private var canvasSize: CGSize = .zero
    @State private var shareItem: ExportShareItem?
    @State private var pendingImportImage: UIImage?
    @State private var pendingImportSource: ImportSource?
    @State private var showImportOptions = false
    @State private var showCaptureSelection = false
    @State private var showAddText = false
    @State private var showAddObject = false
    @State private var selectedCaptureIDs: Set<UUID> = []
    @State private var showPostGeneration = false

    init(project: CompositionProject, session: CaptureSession, selectedImageIDs: Set<UUID>) {
        self._project = Bindable(project)
        self.session = session
        self.selectedImageIDs = selectedImageIDs
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    backgroundGeneratorSection
                    canvasSection
                    colorMatchSection
                    selectedLayerControls
                    layerControlsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }

            if viewModel.isImportingLayer {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView("Removing background…")
                        .progressViewStyle(.circular)
                    Text("Hang tight while we isolate the subject.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 10)
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(viewModel.canUndo == false)

                Button {
                    exportComposition()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(canvasSize == .zero)

                Menu {
                    Button {
                        showCaptureSelection = true
                    } label: {
                        Label("Add Captured Images", systemImage: "photo.on.rectangle")
                    }
                    .disabled(session.images.isEmpty)

                    Button {
                        showAddText = true
                    } label: {
                        Label("Add Text", systemImage: "textformat")
                    }

                    Button {
                        showAddObject = true
                    } label: {
                        Label("Add Object (Nano Bannanna)", systemImage: "sparkles.rectangle.stack")
                    }

                    Divider()

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Import Photo", systemImage: "photo.badge.plus")
                    }

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Import File", systemImage: "tray.and.arrow.down")
                    }
                    
                    Divider()
                    
                    Button {
                        showPostGeneration = true
                    } label: {
                        Label("Generate Social Media Post", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .onAppear {
            VisualEditorView.logger.debug("VisualEditorView appeared. projectID=\(project.id.uuidString, privacy: .public) sessionID=\(session.id.uuidString, privacy: .public)")
            viewModel.configure(
                context: modelContext,
                project: project,
                session: session,
                selectedImageIDs: selectedImageIDs
            )
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            VisualEditorView.logger.debug("PhotosPicker selection changed.")
            Task { await importPhoto(item: newValue) }
        }
        .confirmationDialog(
            "How should we import this image?",
            isPresented: $showImportOptions,
            titleVisibility: .visible
        ) {
            Button("Remove Background") {
                importPendingImage(applyBackgroundRemoval: true)
            }
            Button("Keep Original") {
                importPendingImage(applyBackgroundRemoval: false)
            }
            Button("Cancel", role: .cancel) {
                resetPendingImport()
            }
        } message: {
            Text("Choose whether to keep the background or automatically lift the subject.")
        }
        .alert("Editor Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .alert("Placement", isPresented: $viewModel.showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.infoMessage ?? "")
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { result in
                switch result {
                case .success(let image):
                    if let image {
                        Task { @MainActor in
                            handleImportedImage(image, source: .files)
                        }
                    } else {
                        Task { @MainActor in
                            resetPendingImport()
                        }
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
        .sheet(isPresented: $showBackgroundLibrary) {
            NavigationStack {
                let availableCategories = viewModel.backgroundLibrary
                    .filter { $0.value.isEmpty == false }
                    .map(\.key)
                    .sorted { $0.displayName < $1.displayName }
                BackgroundLibraryView(
                    categories: availableCategories,
                    backgroundsByCategory: viewModel.backgroundLibrary,
                    onSelect: { background in
                        viewModel.importBackgroundFromLibrary(background, into: session)
                        showBackgroundLibrary = false
                    }
                )
            }
        }
        .sheet(item: $shareItem, onDismiss: { shareItem = nil }, content: { item in
            ActivityView(activityItems: [item.image])
        })
        .sheet(isPresented: $showCaptureSelection) {
            NavigationStack {
                CaptureSelectionView(
                    images: session.images.sorted(by: { $0.captureDate > $1.captureDate }),
                    selectedIDs: $selectedCaptureIDs
                ) {
                    viewModel.addCapturedImages(from: session, selectedIDs: selectedCaptureIDs)
                    selectedCaptureIDs = []
                    showCaptureSelection = false
                }
            }
        }
        .sheet(isPresented: $showAddText) {
            NavigationStack {
                AddTextView(
                    onAdd: { text, fontSize, color in
                        viewModel.addTextLayer(text: text, fontSize: fontSize, color: color)
                        showAddText = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAddObject) {
            NavigationStack {
                AddObjectView(
                    onGenerate: { prompt in
                        Task {
                            await viewModel.generateObjectLayer(prompt: prompt, service: "nano_bannanna")
                            showAddObject = false
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showPostGeneration) {
            PostGenerationView(composition: project, session: session)
        }
    }

    private var backgroundGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Step 1: Setup Background")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if project.background == nil {
                    Label("Required", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            if project.background == nil {
                Text("Start by generating or selecting a background for your composition.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }

            backgroundGenerationForm
            if viewModel.hasBackgroundLibrary {
                Button {
                    showBackgroundLibrary = true
                } label: {
                    Label("Browse Background Library", systemImage: "square.grid.2x2")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            generatedBackgroundCarousel
        }
    }

    private var backgroundGenerationForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Category", selection: $viewModel.selectedCategory) {
                ForEach(BackgroundCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.menu)

            TextField("Describe the environment (optional)", text: $viewModel.subjectDescription)
                .textFieldStyle(.roundedBorder)

            Picker("Aspect Ratio", selection: $viewModel.aspectRatio) {
                Text("16:9").tag("16:9")
                Text("3:2").tag("3:2")
                Text("4:5").tag("4:5")
                Text("1:1").tag("1:1")
                Text("9:16").tag("9:16")
            }
            .pickerStyle(.segmented)

            Toggle("Share with community", isOn: $viewModel.shareWithCommunity)
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            Button {
                Task { await viewModel.generateBackground(for: session) }
            } label: {
                HStack {
                    if viewModel.isGenerating { ProgressView() }
                    Text(viewModel.isGenerating ? "Generating" : "Generate Background")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isGenerating)
        }
    }

    @ViewBuilder private var generatedBackgroundCarousel: some View {
        if viewModel.generatedBackgrounds.isEmpty == false {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.generatedBackgrounds) { background in
                        GeneratedBackgroundCard(background: background)
                            .frame(width: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(project.background?.id == background.id ? Color.accentColor : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                viewModel.select(background: background)
                            }
                    }
                }
            }
        }
    }

    private var hasBackgroundSiblings: Bool {
        guard let background = project.background else { return false }
        return session.compositions.contains {
            $0.id != project.id && $0.background?.id == background.id
        }
    }

    @ViewBuilder private var selectedLayerControls: some View {
        if let layer = selectedLayer, project.layers.contains(where: { $0.id == layer.id }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Adjust: \(layer.name)")
                        .font(.headline)
                    Spacer()
                    Button {
                        viewModel.resetTransform(for: layer)
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Size", systemImage: "arrow.up.left.and.arrow.down.right")
                        Spacer()
                        Text("\(Int(layer.scale * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { layer.scale },
                            set: { viewModel.setScaleLive($0, for: layer) }
                        ),
                        in: 0.1...3.0,
                        onEditingChanged: { editing in
                            if editing {
                                viewModel.beginTransformEdit(for: layer)
                            } else {
                                viewModel.endTransformEdit(for: layer)
                            }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Rotation", systemImage: "rotate.right")
                        Spacer()
                        Text("\(Int(layer.rotation))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { layer.rotation },
                            set: { viewModel.setRotationLive($0, for: layer) }
                        ),
                        in: -180...180,
                        onEditingChanged: { editing in
                            if editing {
                                viewModel.beginTransformEdit(for: layer)
                            } else {
                                viewModel.endTransformEdit(for: layer)
                            }
                        }
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Position", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                    positionPad(for: layer)
                }

                if hasBackgroundSiblings {
                    Button {
                        viewModel.applyPlacementToBackgroundSiblings(session: session)
                    } label: {
                        Label(
                            "Apply Placement to All Photos on This Background",
                            systemImage: "rectangle.on.rectangle.angled"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
    }

    private func positionPad(for layer: CompositionLayer) -> some View {
        let step = 8.0
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.frame(width: 44, height: 44)
                nudgeButton("chevron.up") { viewModel.nudge(layer, dx: 0, dy: -step) }
                Color.clear.frame(width: 44, height: 44)
            }
            GridRow {
                nudgeButton("chevron.left") { viewModel.nudge(layer, dx: -step, dy: 0) }
                nudgeButton("scope") { viewModel.nudge(layer, dx: -layer.offsetX, dy: -layer.offsetY) }
                nudgeButton("chevron.right") { viewModel.nudge(layer, dx: step, dy: 0) }
            }
            GridRow {
                Color.clear.frame(width: 44, height: 44)
                nudgeButton("chevron.down") { viewModel.nudge(layer, dx: 0, dy: step) }
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    private func nudgeButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Canvas")
                .font(.title3)
                .fontWeight(.semibold)

            GeometryReader { geometry in
                canvasContent(in: geometry)
            }
            .frame(height: 320)
        }
    }

    private func canvasContent(in geometry: GeometryProxy) -> some View {
        // Sample the background's floor tone once so subject previews can be
        // relit toward it, matching what the exported composite will look like.
        let backgroundImage = project.background?.imageData.flatMap { UIImage(data: $0) }
        let backgroundTone: SubjectColorMatch.Tone? = project.colorMatchEnabled
            ? backgroundImage.flatMap { SubjectColorMatch.backgroundTone(of: $0) }
            : nil

        return ZStack {
            Color(.secondarySystemBackground)
                .cornerRadius(24)

            if let backgroundImage {
                Image(uiImage: backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .cornerRadius(24)
            }

            // Tapping empty canvas clears the selection so the composite can be
            // previewed without the selection outline.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { selectedLayer = nil }

            ForEach(project.layers.sorted(by: { $0.order < $1.order })) { layer in
                if layer.isVisible, let image = UIImage(data: layer.imageData) {
                    DraggableLayerView(
                        image: previewImage(for: layer, image: image, backgroundTone: backgroundTone),
                        layer: layer,
                        isSelected: selectedLayer?.id == layer.id,
                        onUpdate: { offset, scale, rotation in
                            viewModel.update(layer: layer, offset: offset, scale: scale, rotation: rotation)
                        }
                    )
                    .onTapGesture {
                        selectedLayer = layer
                    }
                }
            }
        }
        .onAppear {
            canvasSize = geometry.size
            VisualEditorView.logger.debug("Canvas geometry onAppear. size=\(String(describing: geometry.size), privacy: .public)")
        }
    }

    @ViewBuilder private var colorMatchSection: some View {
        if project.background != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Relight to Background", systemImage: "wand.and.stars")
                        .font(.headline)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { project.colorMatchEnabled },
                        set: { viewModel.setColorMatchEnabled($0, on: project) }
                    ))
                    .labelsHidden()
                }

                Text("Nudges the subject's color and brightness toward the background so it blends into the scene instead of looking pasted on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if project.colorMatchEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Strength")
                            Spacer()
                            Text("\(Int(project.colorMatchStrength * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { project.colorMatchStrength },
                                set: { project.colorMatchStrength = $0 }
                            ),
                            in: 0...2,
                            onEditingChanged: { editing in
                                if editing == false {
                                    viewModel.setColorMatchStrength(project.colorMatchStrength, on: project)
                                }
                            }
                        )
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        }
    }

    /// Subject layers are relit toward the background tone so the canvas preview
    /// matches the exported composite; other layers pass through unchanged.
    private func previewImage(
        for layer: CompositionLayer,
        image: UIImage,
        backgroundTone: SubjectColorMatch.Tone?
    ) -> UIImage {
        guard layer.type == .subject, let backgroundTone, project.colorMatchEnabled else {
            return image
        }
        // Relight a downsampled copy for the on-canvas preview so scrubbing the
        // strength slider stays smooth; the exported composite (CompositionRenderer)
        // relights at full resolution.
        return SubjectColorMatch.matched(
            subject: previewDownsampled(image),
            toward: backgroundTone,
            strength: CGFloat(project.colorMatchStrength)
        )
    }

    /// A reduced-resolution copy for the live canvas only. The final render is
    /// unaffected. Preserves transparency so the cut-out stays clean.
    private func previewDownsampled(_ image: UIImage) -> UIImage {
        let maxEdge: CGFloat = 1280
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private var layerControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Step 2: Add Elements")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }

            if project.background == nil {
                Text("⚠️ Setup a background first (Step 1) before adding elements.")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            }

            if project.layers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add elements to your composition:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Add captured images from this session")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "textformat")
                            Text("Add text layers with custom styling")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "sparkles.rectangle.stack")
                            Text("Generate objects using Nano Bannanna")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 8)
                }
                .padding(.vertical, 8)
            } else {
                layerRows
            }
        }
    }

    @ViewBuilder private var layerList: some View {
        if project.layers.isEmpty {
            EmptyView()
        } else {
            layerRows
        }
    }

    private var layerRows: some View {
        let sortedLayers = project.layers.sorted(by: { $0.order < $1.order })

        return VStack(spacing: 0) {
            ForEach(Array(sortedLayers.enumerated()), id: \.offset) { index, element in
                makeLayerRow(for: element, index: index, totalCount: sortedLayers.count)
            }
        }
    }

    @ViewBuilder
    private func makeLayerRow(for layer: CompositionLayer, index: Int, totalCount: Int) -> some View {
        LayerRow(
            layer: layer,
            isActive: selectedLayer?.id == layer.id,
            canMoveUp: index > 0,
            canMoveDown: index < totalCount - 1,
            onSelect: {
                selectedLayer = layer
            },
            onVisibility: {
                viewModel.toggleVisibility(for: layer)
            },
            onLock: {
                viewModel.toggleLock(for: layer)
            },
            onMoveUp: {
                viewModel.moveLayerUp(layer)
            },
            onMoveDown: {
                viewModel.moveLayerDown(layer)
            },
            onDelete: {
                if selectedLayer?.id == layer.id {
                    selectedLayer = nil
                }
                viewModel.delete(layer: layer)
            },
            onCleanup: viewModel.canClean(layer: layer) ? {
                viewModel.cleanLayer(layer)
            } : nil,
            isProcessing: viewModel.cleaningLayerIDs.contains(layer.id)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }

    private func importPhoto(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        VisualEditorView.logger.debug("PhotosPicker item loaded. imageSize=\(image.size.debugDescription, privacy: .public)")
        await MainActor.run {
            handleImportedImage(image, source: .photos)
            selectedPhoto = nil
        }
    }

    private func exportComposition() {
        // Use the proper export canvas size based on background aspect ratio
        // This ensures the export matches what we see in SessionDetailView
        let exportCanvasSize: CGSize
        if let background = project.background {
            exportCanvasSize = canvasSizeForAspectRatio(background.aspectRatio)
        } else {
            // Fallback to default 16:9 if no background
            exportCanvasSize = canvasSizeForAspectRatio("16:9")
        }
        
        VisualEditorView.logger.debug("Export started. exportCanvasSize=\(String(describing: exportCanvasSize), privacy: .public)")
        guard let image = viewModel.renderCompositeImage(size: exportCanvasSize) else {
            viewModel.errorMessage = "Unable to export the current composition."
            viewModel.showError = true
            return
        }
        shareItem = ExportShareItem(image: image)
        VisualEditorView.logger.debug("Export finished. renderedSize=\(image.size.debugDescription, privacy: .public)")
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

    @MainActor
    private func handleImportedImage(_ image: UIImage, source: ImportSource) {
        pendingImportImage = image
        pendingImportSource = source
        showImportOptions = true
        VisualEditorView.logger.debug("Prepared imported image. source=\(String(describing: source), privacy: .public) size=\(image.size.debugDescription, privacy: .public)")
    }

    @MainActor
    private func importPendingImage(applyBackgroundRemoval: Bool) {
        guard let image = pendingImportImage else { return }

        let defaultName: String
        switch (applyBackgroundRemoval, pendingImportSource) {
        case (true, _):
            defaultName = "Imported Subject"
        case (false, .photos):
            defaultName = "Imported Photo"
        case (false, .files):
            defaultName = "Imported Asset"
        case (false, .none):
            defaultName = "Imported Layer"
        }

        viewModel.importLayer(
            from: image,
            removeBackground: applyBackgroundRemoval,
            name: defaultName,
            type: .upload
        )

        resetPendingImport()
    }

    @MainActor
    private func resetPendingImport() {
        pendingImportImage = nil
        pendingImportSource = nil
        showImportOptions = false
    }
}

#Preview {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    guard let container = try? ModelContainer(
        for: CaptureSession.self,
        ProcessedImage.self,
        GeneratedBackground.self,
        CompositionProject.self,
        CompositionLayer.self,
        configurations: configuration
    ) else {
        return NavigationStack {
            Text("Preview unavailable")
        }
    }

    let session = CaptureSession(stockNumber: "ABC123", title: "ABC123", notes: "Premium package")
    let sampleImage = ProcessedImage(image: UIImage(systemName: "car.fill") ?? UIImage(), session: session)
    session.images.append(sampleImage)
    let project = CompositionProject(name: "Composition ABC123", session: session)
    return NavigationStack {
        VisualEditorView(
            project: project,
            session: session,
            selectedImageIDs: Set(session.images.map(\.id))
        )
    }
    .modelContainer(container)
}

// swiftlint:enable file_length type_body_length
