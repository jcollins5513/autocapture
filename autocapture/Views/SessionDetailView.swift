//
//  SessionDetailView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import SwiftData
import SwiftUI
import UIKit

struct SessionDetailView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Bindable var session: CaptureSession
    @StateObject private var viewModel: SessionDetailViewModel

    @State private var showCamera = false
    @State private var showCaptureSelection = false
    @State private var pendingProject: CompositionProject?
    @State private var editorPresentation: EditorPresentation?
    @State private var captureSelection: Set<UUID> = []
    @State private var selectedStatus: CaptureSession.Status
    @State private var showPostGeneration = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private struct EditorPresentation: Identifiable {
        let id = UUID()
        let project: CompositionProject
        let selectedImageIDs: Set<UUID>
    }

    init(session: CaptureSession) {
        self._session = Bindable(session)
        self._selectedStatus = State(initialValue: session.status)
        self._viewModel = StateObject(wrappedValue: SessionDetailViewModel(session: session))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                batchOperationsSection
                capturedImagesSection
                generatedBackgroundSection
                compositionsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showCamera = true
                } label: {
                    Label("Capture", systemImage: "camera")
                }

                Button {
                    openEditor()
                } label: {
                    Label("Edit", systemImage: "paintbrush.pointed")
                }
                .disabled(session.images.isEmpty)

                Menu {
                    Button {
                        viewModel.exportAllCompositions(session: session)
                    } label: {
                        Label("Export All", systemImage: "square.and.arrow.up")
                    }
                    .disabled(session.compositions.isEmpty)
                    
                    Divider()
                    
                    Button {
                        showPostGeneration = true
                    } label: {
                        Label("Generate Social Media Post", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            NavigationStack {
                CameraView(session: session)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showCamera = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showCaptureSelection) {
            NavigationStack {
                if let project = pendingProject {
                    CaptureSelectionView(
                        images: session.images.sorted(by: { $0.captureDate > $1.captureDate }),
                        selectedIDs: $captureSelection
                    ) {
                        let selection = captureSelection
                        editorPresentation = EditorPresentation(project: project, selectedImageIDs: selection)
                        showCaptureSelection = false
                        pendingProject = nil
                    }
                } else {
                    ContentUnavailableView("No Project", systemImage: "exclamationmark.triangle")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showCaptureSelection = false }
                            }
                        }
                }
            }
        }
        .sheet(item: $editorPresentation) { presentation in
            NavigationStack {
                VisualEditorView(
                    project: presentation.project,
                    session: session,
                    selectedImageIDs: presentation.selectedImageIDs
                )
            }
        }
        .onChange(of: selectedStatus) { _, newValue in
            session.status = newValue
            session.touch()
            try? modelContext.save()
        }
        .onChange(of: showCaptureSelection) { _, isPresented in
            if isPresented == false {
                pendingProject = nil
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            if viewModel.exportImages.isEmpty == false {
                ActivityView(activityItems: viewModel.exportImages)
            }
        }
        .sheet(isPresented: $showPostGeneration) {
            PostGenerationView(session: session)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSummary
            headerCategories
        }
        .padding(.top, 24)
    }

    private var headerSummary: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.stockNumber)
                    .font(.title2)
                    .fontWeight(.semibold)
                if session.notes.isEmpty == false {
                    Text(session.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Picker("Status", selection: $selectedStatus) {
                ForEach(CaptureSession.Status.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder private var headerCategories: some View {
        if session.categories.isEmpty == false {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.categories, id: \.self) { raw in
                        if let category = BackgroundCategory(rawValue: raw) {
                            Label(category.displayName, systemImage: "rectangle.3.group")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
                        }
                    }
                }
            }
        }
    }

    private var capturedImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Captured Subjects")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    openEditor()
                } label: {
                    Label("Open Editor", systemImage: "rectangle.stack.badge.plus")
                }
                .disabled(session.images.isEmpty)
            }

            if session.images.isEmpty {
                ContentUnavailableView(
                    "No Captures",
                    systemImage: "photo.badge.plus",
                    description: Text("Capture lifted subjects to populate this session.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(session.images.sorted(by: { $0.captureDate > $1.captureDate })) { image in
                        CapturedImageCard(processedImage: image)
                    }
                }
            }
        }
    }

    private var batchOperationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Batch Operations")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                // Background generation form
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
                        Text("9:16").tag("9:16")
                        Text("1:1").tag("1:1")
                    }
                    .pickerStyle(.menu)
                }

                // Generate and Apply button
                Button {
                    Task {
                        await viewModel.generateBackgroundAndApplyToAllVehicles(
                            session: session,
                            context: modelContext
                        )
                    }
                } label: {
                    HStack {
                        if viewModel.isGeneratingBackground || viewModel.isCreatingCompositions {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(
                            viewModel.isGeneratingBackground
                                ? "Generating Background..."
                                : viewModel.isCreatingCompositions
                                    ? "Applying to Vehicles..."
                                    : "Generate Background & Apply to All Vehicles"
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    session.images.isEmpty
                        || viewModel.isGeneratingBackground
                        || viewModel.isCreatingCompositions
                )

                // Apply existing background to all vehicles
                if session.generatedBackgrounds.isEmpty == false {
                    Menu {
                        ForEach(
                            session.generatedBackgrounds.sorted(by: { $0.createdAt > $1.createdAt })
                        ) { background in
                            Button {
                                Task {
                                    await viewModel.applyBackgroundToAllVehicles(
                                        session: session,
                                        background: background,
                                        context: modelContext
                                    )
                                }
                            } label: {
                                Label(
                                    "Apply \(background.category.displayName)",
                                    systemImage: "rectangle.3.group"
                                )
                            }
                            .disabled(viewModel.isCreatingCompositions)
                        }
                    } label: {
                        HStack {
                            if viewModel.isCreatingCompositions {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(
                                viewModel.isCreatingCompositions
                                    ? "Applying..."
                                    : "Apply Existing Background to All Vehicles"
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(
                        session.images.isEmpty || viewModel.isGeneratingBackground
                            || viewModel.isCreatingCompositions
                    )
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
    }

    private var generatedBackgroundSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Backgrounds")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    openEditor()
                } label: {
                    Label("Generate", systemImage: "sparkles")
                }
            }

            if session.generatedBackgrounds.isEmpty {
                Text("Generated backgrounds for this stock number will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(session.generatedBackgrounds.sorted(by: { $0.createdAt > $1.createdAt })) { background in
                            GeneratedBackgroundCard(background: background)
                                .onTapGesture {
                                    ensureProject()?.background = background
                                    openEditor()
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var compositionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Compositions")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                HStack {
                    if session.compositions.isEmpty == false {
                        Button {
                            viewModel.exportAllCompositions(session: session)
                        } label: {
                            Label("Export All", systemImage: "square.and.arrow.up")
                        }
                        .disabled(viewModel.isExporting)
                        
                        Button {
                            Task {
                                await viewModel.updateCompositionScales(session: session, context: modelContext)
                            }
                        } label: {
                            Label("Fix Scaling", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                        .disabled(viewModel.isCreatingCompositions || session.compositions.isEmpty)
                        
                        Button {
                            showPostGeneration = true
                        } label: {
                            Label("Generate Post", systemImage: "square.and.pencil")
                        }
                    }
                }
            }

            if session.compositions.isEmpty {
                Text("Compositions will appear here after applying backgrounds to vehicles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 12) {
                    ForEach(
                        session.compositions.sorted(by: { $0.createdAt > $1.createdAt })
                    ) { composition in
                        CompositionCard(composition: composition, canvasSize: defaultCanvasSize)
                    }
                }
            }
        }
    }

    private var defaultCanvasSize: CGSize {
        if let firstBackground = session.compositions.first?.background {
            return canvasSizeForAspectRatio(firstBackground.aspectRatio)
        }
        return CGSize(width: 3584, height: 2016) // Default 16:9
    }

    private func canvasSizeForAspectRatio(_ aspectRatio: String) -> CGSize {
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
            return CGSize(width: 3584, height: 2016)
        }
    }

    private func openEditor() {
        guard let project = ensureProject() else { return }
        pendingProject = project

        let sessionImageIDs = Set(session.images.map(\.id))
        let existingLayerIDs = Set(project.layers.compactMap { $0.processedImageID })
        if existingLayerIDs.isEmpty {
            captureSelection = sessionImageIDs
        } else {
            let intersection = existingLayerIDs.intersection(sessionImageIDs)
            captureSelection = intersection.isEmpty ? sessionImageIDs : intersection
        }

        showCaptureSelection = true
    }

    private func ensureProject() -> CompositionProject? {
        if let existing = session.compositions.max(by: { $0.createdAt < $1.createdAt }) {
            return existing
        }

        let project = CompositionProject(name: "Composition \(session.stockNumber)", session: session)
        modelContext.insert(project)
        session.compositions.append(project)
        do {
            try modelContext.save()
            return project
        } catch {
            modelContext.delete(project)
            return nil
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
    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(container)
}
