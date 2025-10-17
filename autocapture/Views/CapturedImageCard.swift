//
//  CapturedImageCard.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI

struct CapturedImageCard: View {
    let processedImage: ProcessedImage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = processedImage.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(12)
            }
            Text(processedImage.captureDate, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
