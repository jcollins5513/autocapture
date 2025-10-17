//
//  VisualEditorView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct VisualEditorView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Environment(\.dismiss)
    private var dismiss
    @StateObject private var viewModel = VisualEditorViewModel()

    @Bindable var project: CompositionProject
    let session: CaptureSession

    @State private var selectedLayer: CompositionLayer?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showDocumentPicker = false
    @State private var canvasSize: CGSize = .zero

    init(project: CompositionProject, session: CaptureSession) {
        self._project = Bindable(project)
        self.session = session
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                backgroundGeneratorSection
                canvasSection
                layerControlsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
                Button {
                    showDocumentPicker = true
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                }
            }
        }
        .onAppear {
            viewModel.configure(context: modelContext, project: project, session: session)
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task { await importPhoto(item: newValue) }
        }
        .alert("Editor Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { result in
                switch result {
                case .success(let image):
                    if let image { viewModel.addLayer(from: image, name: "Imported Layer", type: .upload) }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            }
        }
    }

    private var backgroundGeneratorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Generate Background")
                .font(.title3)
                .fontWeight(.semibold)
            backgroundGenerationForm
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
        ZStack {
            Color(.secondarySystemBackground)
                .cornerRadius(24)

            if let data = project.background?.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .cornerRadius(24)
            }

            ForEach(project.layers.sorted(by: { $0.order < $1.order })) { layer in
                if layer.isVisible, let image = UIImage(data: layer.imageData) {
                    DraggableLayerView(
                        image: image,
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
        .onAppear { canvasSize = geometry.size }
    }

    private var layerControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Layers")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }
            layerList
        }
    }

    @ViewBuilder private var layerList: some View {
        if project.layers.isEmpty {
            Text("Add subject or uploaded layers to begin composing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            }
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.bottom, 8)
    }

    private func importPhoto(item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        await MainActor.run {
            viewModel.addLayer(from: image, name: "Imported Layer", type: .upload)
            selectedPhoto = nil
        }
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
    let project = CompositionProject(name: "Composition ABC123", session: session)
    return NavigationStack {
        VisualEditorView(project: project, session: session)
    }
    .modelContainer(container)
}
