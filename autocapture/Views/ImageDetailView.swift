//
//  ImageDetailView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftData
import SwiftUI

struct ImageDetailView: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
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
