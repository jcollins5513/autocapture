//
//  AddObjectView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import SwiftUI

struct AddObjectView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var objectPrompt: String = ""
    @State private var isGenerating = false

    let onGenerate: (String) async -> Void

    var body: some View {
        Form {
            Section("Object Description") {
                Text("Describe the object you want to generate")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $objectPrompt)
                    .frame(minHeight: 120)
            }

            Section {
                Button {
                    Task {
                        isGenerating = true
                        await onGenerate(objectPrompt)
                        isGenerating = false
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                        }
                        Text(isGenerating ? "Generating..." : "Generate Object")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(objectPrompt.isEmpty || isGenerating)
            }
        }
        .navigationTitle("Add Object (Nano Bannanna)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddObjectView { _ in }
    }
}
