//
//  CompositionCard.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import SwiftUI
import UIKit

struct CompositionCard: View {
    let composition: CompositionProject
    let canvasSize: CGSize
    @State private var renderedImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 160)
                    ProgressView()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(composition.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Text("\(composition.layers.count) layer\(composition.layers.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .onAppear {
            renderComposition()
        }
    }

    private func renderComposition() {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return }

        // Use a smaller size for the card preview
        let previewSize = CGSize(
            width: min(400, canvasSize.width),
            height: min(400, canvasSize.height) * (canvasSize.height / canvasSize.width)
        )

        renderedImage = CompositionRenderer.render(project: composition, canvasSize: previewSize)
    }
}

