//
//  SessionDetailView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct SessionDetailView: View {
    @Environment(\.modelContext)
    private var modelContext
    @Bindable var session: CaptureSession

    @State private var showCamera = false
    @State private var showCaptureSelection = false
    @State private var pendingProject: CompositionProject?
    @State private var editorPresentation: EditorPresentation?
    @State private var captureSelection: Set<UUID> = []
    @State private var selectedStatus: CaptureSession.Status
    @State private var overlayPickerItem: PhotosPickerItem?
    @State private var isUpdatingOverlay = false
    @State private var overlayError: String?
    @State private var showOverlayError = false

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
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                capturedImagesSection
                generatedBackgroundSection
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
        .onChange(of: overlayPickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                await loadOverlay(from: item)
            }
        }
        .alert("Overlay Update Failed", isPresented: $showOverlayError) {
            Button("OK", role: .cancel) {
                overlayError = nil
            }
        } message: {
            if let overlayError {
                Text(overlayError)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSummary
            headerCategories
            headerOverlayControls
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

    private var headerOverlayControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Marketing Overlay")
                    .font(.headline)
                Spacer()
                if session.overlayImage != nil {
                    Button(role: .destructive) {
                        removeOverlay()
                    } label: {
                        Label("Remove Overlay", systemImage: "trash")
                    }
                    .disabled(isUpdatingOverlay)
                }
            }

            overlayPreview

            PhotosPicker(selection: $overlayPickerItem, matching: .images) {
                Label(
                    session.overlayImage == nil ? "Select Overlay" : "Replace Overlay",
                    systemImage: "photo.on.rectangle"
                )
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            }
            .disabled(isUpdatingOverlay)
        }
    }

    @ViewBuilder
    private var overlayPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.gray.opacity(0.12))

            if let overlay = session.overlayImage {
                Image(uiImage: overlay)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                    Text("Add a logo or marketing frame to apply to lifted captures in this session.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .foregroundStyle(.secondary)
            }

            if isUpdatingOverlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.3))
                ProgressView()
                    .tint(.white)
            }
        }
        .frame(height: 160)
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

    private func removeOverlay() {
        guard session.overlayImage != nil else { return }
        isUpdatingOverlay = true
        defer { isUpdatingOverlay = false }
        applyOverlay(nil)
    }

    private func applyOverlay(_ overlay: UIImage?) {
        let previousOverlay = session.overlayImage
        let previousUpdatedAt = session.updatedAt
        let previousImages = session.images.map { image in
            (image, image.imageData, image.liftedImageData)
        }

        applyOverlayToCaptures(using: overlay)
        session.overlayImage = overlay
        session.touch()

        do {
            try modelContext.save()
        } catch {
            session.overlayImage = previousOverlay
            session.updatedAt = previousUpdatedAt
            for (image, imageData, liftedData) in previousImages {
                image.imageData = imageData
                image.liftedImageData = liftedData
            }
            presentOverlayError(error.localizedDescription)
        }
    }

    private func applyOverlayToCaptures(using overlay: UIImage?) {
        let compositor = OverlayCompositor()

        for processedImage in session.images where processedImage.isSubjectLifted {
            let subjectImage = processedImage.liftedImage ?? processedImage.image

            if processedImage.liftedImageData == nil,
               let subjectImage,
               let subjectData = subjectImage.pngData() {
                processedImage.liftedImageData = subjectData
            }

            guard let subjectImage else { continue }

            if let overlay,
               let composited = compositor.composite(subject: subjectImage, onto: overlay),
               let compositedData = composited.pngData() {
                processedImage.imageData = compositedData
            } else if let liftedData = processedImage.liftedImageData {
                processedImage.imageData = liftedData
            } else if let subjectData = subjectImage.pngData() {
                processedImage.imageData = subjectData
            }
        }
    }

    private func presentOverlayError(_ message: String) {
        overlayError = message
        showOverlayError = true
    }

    private func loadOverlay(from item: PhotosPickerItem) async {
        await MainActor.run {
            isUpdatingOverlay = true
        }

        defer {
            Task { @MainActor in
                isUpdatingOverlay = false
            }
        }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    overlayPickerItem = nil
                    applyOverlay(image)
                }
            } else {
                await MainActor.run {
                    overlayPickerItem = nil
                    presentOverlayError("Unable to load the selected overlay image.")
                }
            }
        } catch {
            await MainActor.run {
                overlayPickerItem = nil
                presentOverlayError(error.localizedDescription)
            }
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
