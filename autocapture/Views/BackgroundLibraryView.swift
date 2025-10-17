//
//  BackgroundLibraryView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import SwiftUI

struct BackgroundLibraryView: View {
    let categories: [BackgroundCategory]
    let backgroundsByCategory: [BackgroundCategory: [GeneratedBackground]]
    let onSelect: (GeneratedBackground) -> Void

    @Environment(\.dismiss)
    private var dismiss
    @State private var selectedCategory: BackgroundCategory?

    private var displayedBackgrounds: [GeneratedBackground] {
        guard let category = selectedCategory ?? categories.first else { return [] }
        return backgroundsByCategory[category]?.sorted(by: { $0.createdAt > $1.createdAt }) ?? []
    }

    private let gridColumns = [
        GridItem(.adaptive(minimum: 200), spacing: 16)
    ]

    var body: some View {
        Group {
            if categories.isEmpty {
                ContentUnavailableView(
                    "No Backgrounds",
                    systemImage: "square.grid.2x2",
                    description: Text("Backgrounds you generate in other sessions will be available here.")
                )
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Category", selection: Binding(
                        get: { selectedCategory ?? categories.first ?? categories[0] },
                        set: { selectedCategory = $0 }
                    )) {
                        ForEach(categories) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)

                    if displayedBackgrounds.isEmpty {
                        ContentUnavailableView(
                            "No Backgrounds",
                            systemImage: "photo",
                            description: Text("Generate backgrounds in this category to reuse them here.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(displayedBackgrounds) { background in
                                    Button {
                                        onSelect(background)
                                        dismiss()
                                    } label: {
                                        GeneratedBackgroundCard(background: background)
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Background Library")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = categories.first
            }
        }
    }
}

#Preview {
    let backgrounds = BackgroundCategory.allCases.reduce(into: [BackgroundCategory: [GeneratedBackground]]()) { partialResult, category in
        let background = GeneratedBackground(
            prompt: "Sample prompt for \(category.displayName)",
            category: category
        )
        partialResult[category] = [background]
    }
    return NavigationStack {
        BackgroundLibraryView(categories: Array(backgrounds.keys), backgroundsByCategory: backgrounds) { _ in }
    }
}
