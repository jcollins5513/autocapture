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

    private var canvasAspectRatio: CGFloat {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return 16.0 / 9.0 }
        return canvasSize.width / canvasSize.height
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let renderedImage {
                // Fit (don't fill) so the whole composite is visible — filling a
                // fixed-height box crops most of a wide showroom shot away and
                // makes the result look zoomed-in.
                Image(uiImage: renderedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .aspectRatio(canvasAspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity)
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

