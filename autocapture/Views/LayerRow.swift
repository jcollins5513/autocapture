//
//  LayerRow.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI

struct LayerRow: View {
    let layer: CompositionLayer
    let isActive: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onSelect: () -> Void
    let onVisibility: () -> Void
    let onLock: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            layerSummary
            Spacer()
            actionButtons
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .padding(.vertical, 8)
    }

    private var layerSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(layer.name)
                .font(.subheadline)
                .fontWeight(isActive ? .bold : .regular)
            Text(layer.type.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
            }
            .disabled(canMoveUp == false)
            .buttonStyle(.borderless)

            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
            }
            .disabled(canMoveDown == false)
            .buttonStyle(.borderless)

            Button(action: onVisibility) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
            }
            .buttonStyle(.borderless)

            Button(action: onLock) {
                Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
            }
            .buttonStyle(.borderless)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }
}
