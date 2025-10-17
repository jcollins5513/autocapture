//
//  GeneratedBackgroundCard.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI
import UIKit

struct GeneratedBackgroundCard: View {
    let background: GeneratedBackground

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = background.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 120)
                    .clipped()
                    .cornerRadius(12)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 180, height: 120)
                    Label("Prompt", systemImage: "text.quote")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(background.category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(background.prompt)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
