//
//  CaptureSelectionView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import SwiftUI
import UIKit

struct CaptureSelectionView: View {
    let images: [ProcessedImage]
    @Binding var selectedIDs: Set<UUID>
    let onConfirm: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(images) { image in
                    SelectableCapturedImageCard(
                        processedImage: image,
                        isSelected: selectedIDs.contains(image.id)
                    )
                    .onTapGesture {
                        toggleSelection(for: image.id)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Select Subjects")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") {
                    onConfirm()
                    dismiss()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}

private struct SelectableCapturedImageCard: View {
    let processedImage: ProcessedImage
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                if let image = processedImage.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .cornerRadius(14)
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 160)
                }

                Text(processedImage.captureDate, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(10)
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selection: Set<UUID> = []
        let images: [ProcessedImage]

        init() {
            let image = UIImage(systemName: "car") ?? UIImage()
            images = (0..<6).map { index in
                ProcessedImage(image: image, captureDate: Date().addingTimeInterval(Double(index) * -3600))
            }
        }

        var body: some View {
            NavigationStack {
                CaptureSelectionView(images: images, selectedIDs: $selection) {}
            }
        }
    }

    return PreviewWrapper()
}
