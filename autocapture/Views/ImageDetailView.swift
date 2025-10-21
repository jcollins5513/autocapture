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
    @State private var showCleanupSheet = false

    var body: some View {
        NavigationStack {
            detailLayout
        }
    }

    private var detailLayout: some View {
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

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if image.maskImage != nil, image.originalImage != nil {
                    Button {
                        showCleanupSheet = true
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.white)
                    }
                }

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
        .sheet(isPresented: $showCleanupSheet) {
            EdgeCleanupView(image: image)
        }
    }

    private func deleteImage() {
        modelContext.delete(image)
        try? modelContext.save()
        dismiss()
    }
}
