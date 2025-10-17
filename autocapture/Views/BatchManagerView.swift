//
//  BatchManagerView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import SwiftData
import SwiftUI

struct BatchManagerView: View {
    @Environment(\.modelContext)
    private var modelContext
    @StateObject private var viewModel = BatchManagerViewModel()
    @Query(sort: \CaptureSession.updatedAt, order: .reverse)
    private var sessions: [CaptureSession]

    @State private var navigationPath = NavigationPath()
    @State private var presentCreationForm = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                newSessionSection
                sessionsSection
            }
            .navigationDestination(for: CaptureSession.self) { session in
                SessionDetailView(session: session)
            }
            .navigationTitle("Capture Sessions")
            .toolbar { EditButton() }
            .sheet(isPresented: $presentCreationForm) {
                NavigationStack {
                    SessionCreationForm(
                        viewModel: viewModel,
                        onCreate: { session in
                            handleSessionCreation(session)
                        }
                    )
                        .environment(\.modelContext, modelContext)
                }
            }
            .alert("Unable to Create Session", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var newSessionSection: some View {
        Section {
            Button {
                presentCreationForm = true
            } label: {
                Label("New Capture Session", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder private var sessionsSection: some View {
        if sessions.isEmpty {
            Section {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "camera.on.rectangle",
                    description: Text("Create a session to start capturing batches by stock number.")
                )
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(sessions) { session in
                NavigationLink(value: session) {
                    SessionRowView(session: session)
                }
            }
            .onDelete(perform: delete)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    private func handleSessionCreation(_ session: CaptureSession) {
        navigationPath.append(session)
    }
}

#Preview {
    BatchManagerView()
        .modelContainer(for: [CaptureSession.self, ProcessedImage.self], inMemory: true)
}
