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

    @State private var showCamera = false
    @State private var selectedProject: CompositionProject?
    @State private var selectedStatus: CaptureSession.Status

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

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
        .sheet(item: $selectedProject) { project in
            NavigationStack {
                VisualEditorView(project: project, session: session)
            }
        }
        .onChange(of: selectedStatus) { _, newValue in
            session.status = newValue
            session.touch()
            try? modelContext.save()
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

    private func openEditor() {
        guard let project = ensureProject() else { return }
        selectedProject = project
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
