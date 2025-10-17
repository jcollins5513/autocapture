//
//  SessionRowView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI

struct SessionRowView: View {
    let session: CaptureSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.headline)
                Spacer()
                Text(session.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
                    .foregroundStyle(statusColor)
            }
            HStack(spacing: 12) {
                Label(session.stockNumber, systemImage: "number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let category = session.primaryCategory {
                    Label(category.displayName, systemImage: "rectangle.3.group")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Label("\(session.images.count)", systemImage: "photo")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch session.status {
        case .planning:
            return .gray
        case .capturing:
            return .blue
        case .editing:
            return .orange
        case .completed:
            return .green
        }
    }
}
