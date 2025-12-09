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
    @State private var selectedStatus: CaptureSession.Status

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(session: CaptureSession) {
        self._session = Bindable(session)
        self._selectedStatus = State(initialValue: session.status)
        self._viewModel = StateObject(wrappedValue: SessionDetailViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                uploadSection
                capturedImagesSection
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
                    Task {
                        await viewModel.uploadSession(session, context: modelContext)
                    }
                } label: {
                    Label("Complete & Upload", systemImage: "icloud.and.arrow.up")
                }
                .disabled(session.images.isEmpty || viewModel.isUploading)
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
        .onChange(of: selectedStatus) { _, newValue in
            session.status = newValue
            session.touch()
            try? modelContext.save()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
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
                Text("Captured Photos")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
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

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Send Captures to Web Companion")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Uploads are sent to /api/web-companion/uploads and background removal runs in the browser session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.isUploading {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: viewModel.uploadProgress)
                    Text("\(Int(viewModel.uploadProgress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await viewModel.uploadSession(session, context: modelContext)
                }
            } label: {
                HStack {
                    if viewModel.isUploading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isUploading ? "Uploading..." : "Complete & Upload")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.images.isEmpty || viewModel.isUploading)

            if session.images.isEmpty {
                Text("Capture at least one photo before uploading.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if viewModel.uploadResults.isEmpty == false {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.uploadResults) { result in
                        HStack {
                            Image(systemName: result.status == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                .foregroundStyle(result.status == .success ? .green : .red)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.filename)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let processedUrl = result.processedUrl {
                                    Text(processedUrl)
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
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
