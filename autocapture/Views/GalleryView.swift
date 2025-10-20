//
//  GalleryView.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftData
import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @Query(sort: \ProcessedImage.captureDate, order: .reverse)
    private var images: [ProcessedImage]

    @State private var selectedImage: ProcessedImage?
    @State private var gridItemSize: CGFloat = 0

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if images.isEmpty {
                    ContentUnavailableView(
                        "No Photos",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Capture photos to see them here")
                    )
                } else {
                    GeometryReader { geometry in
                        ScrollView {
                            grid(for: geometry.size.width)
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedImage) { image in
                ImageDetailView(image: image)
            }
        }
    }

    private func calculateGridItemSize(from width: CGFloat) -> CGFloat {
        (width - 4) / 3
    }

    @ViewBuilder
    private func grid(for width: CGFloat) -> some View {
        let size = gridItemSize > 0 ? gridItemSize : calculateGridItemSize(from: width)

        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(images) { image in
                if let uiImage = image.image {
                    Button {
                        selectedImage = image
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .onAppear {
            gridItemSize = size
        }
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: ProcessedImage.self, inMemory: true)
}
