//
//  GalleryView.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftUI
import SwiftData

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProcessedImage.captureDate, order: .reverse) private var images: [ProcessedImage]
    
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
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(images) { image in
                                    if let uiImage = image.image {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: gridItemSize > 0 ? gridItemSize : calculateGridItemSize(from: geometry.size.width), 
                                                   height: gridItemSize > 0 ? gridItemSize : calculateGridItemSize(from: geometry.size.width))
                                            .clipped()
                                            .onTapGesture {
                                                selectedImage = image
                                            }
                                    }
                                }
                            }
                            .onAppear {
                                gridItemSize = calculateGridItemSize(from: geometry.size.width)
                            }
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
}

// MARK: - Image Detail View
struct ImageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let image: ProcessedImage
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let uiImage = image.image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        deleteImage()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                    }
                }
            }
            .toolbarBackground(.black.opacity(0.5), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
    
    private func deleteImage() {
        modelContext.delete(image)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: ProcessedImage.self, inMemory: true)
}

