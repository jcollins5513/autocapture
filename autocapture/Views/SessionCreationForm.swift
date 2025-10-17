//
//  SessionCreationForm.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftData
import SwiftUI

struct SessionCreationForm: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @ObservedObject var viewModel: BatchManagerViewModel
    let onCreate: (CaptureSession) -> Void

    var body: some View {
        Form {
            Section("Stock Information") {
                TextField("Stock Number", text: $viewModel.stockNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("Title", text: $viewModel.title)
                TextField("Notes", text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Background Categories") {
                ForEach(BackgroundCategory.allCases, id: \.self) { category in
                    MultipleSelectionRow(
                        title: category.displayName,
                        isSelected: viewModel.selectedCategories.contains(category),
                        action: {
                            toggleCategory(category)
                        }
                    )
                }
            }
        }
        .navigationTitle("New Session")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    if let session = viewModel.createSession(with: modelContext) {
                        onCreate(session)
                        dismiss()
                    }
                }
                .disabled(viewModel.stockNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func toggleCategory(_ category: BackgroundCategory) {
        if viewModel.selectedCategories.contains(category) {
            viewModel.selectedCategories.remove(category)
        } else {
            viewModel.selectedCategories.insert(category)
        }
    }
}
