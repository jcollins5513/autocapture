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
    let onCleanup: (() -> Void)?
    let isProcessing: Bool

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
            cleanupControl
            moveUpButton
            moveDownButton
            visibilityButton
            lockButton
            deleteButton
        }
    }

    @ViewBuilder private var cleanupControl: some View {
        if let onCleanup {
            if isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 20, height: 20)
            } else {
                Button(action: onCleanup) {
                    Image(systemName: "wand.and.stars")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clean up subject edges")
            }
        }
    }

    private var moveUpButton: some View {
        Button(action: onMoveUp) {
            Image(systemName: "arrow.up")
        }
        .disabled(isProcessing || canMoveUp == false)
        .buttonStyle(.borderless)
    }

    private var moveDownButton: some View {
        Button(action: onMoveDown) {
            Image(systemName: "arrow.down")
        }
        .disabled(isProcessing || canMoveDown == false)
        .buttonStyle(.borderless)
    }

    private var visibilityButton: some View {
        Button(action: onVisibility) {
            Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
        }
        .disabled(isProcessing)
        .buttonStyle(.borderless)
    }

    private var lockButton: some View {
        Button(action: onLock) {
            Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
        }
        .disabled(isProcessing)
        .buttonStyle(.borderless)
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Image(systemName: "trash")
        }
        .disabled(isProcessing)
        .buttonStyle(.borderless)
    }
}
