//
//  DraggableLayerView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI
import UIKit

struct DraggableLayerView: View {
    let image: UIImage
    let layer: CompositionLayer
    let isSelected: Bool
    let onUpdate: (CGSize, CGFloat, Angle) -> Void

    @State private var currentOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var currentRotation: Angle = .zero
    @State private var baseOffset: CGSize = .zero
    @State private var baseScale: CGFloat = 1.0
    @State private var baseRotation: Angle = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(currentScale)
            .rotationEffect(currentRotation)
            .offset(currentOffset)
            .shadow(color: isSelected ? .accentColor.opacity(0.4) : .clear, radius: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            guard layer.isLocked == false else { return }
                            currentOffset = CGSize(
                                width: baseOffset.width + value.translation.width,
                                height: baseOffset.height + value.translation.height
                            )
                        }
                        .onEnded { value in
                            guard layer.isLocked == false else { return }
                            currentOffset = CGSize(
                                width: baseOffset.width + value.translation.width,
                                height: baseOffset.height + value.translation.height
                            )
                            baseOffset = currentOffset
                            onUpdate(currentOffset, currentScale, currentRotation)
                        },
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { scale in
                                guard layer.isLocked == false else { return }
                                currentScale = baseScale * scale
                            }
                            .onEnded { scale in
                                guard layer.isLocked == false else { return }
                                currentScale = baseScale * scale
                                baseScale = currentScale
                                onUpdate(currentOffset, currentScale, currentRotation)
                            },
                        RotationGesture()
                            .onChanged { angle in
                                guard layer.isLocked == false else { return }
                                currentRotation = baseRotation + angle
                            }
                            .onEnded { angle in
                                guard layer.isLocked == false else { return }
                                currentRotation = baseRotation + angle
                                baseRotation = currentRotation
                                onUpdate(currentOffset, currentScale, currentRotation)
                            }
                    )
                )
            )
            .onAppear {
                baseOffset = CGSize(width: layer.offsetX, height: layer.offsetY)
                baseScale = layer.scale
                baseRotation = Angle(degrees: layer.rotation)
                currentOffset = baseOffset
                currentScale = baseScale
                currentRotation = baseRotation
            }
            .onChange(of: layer.offsetX) { _, newValue in
                baseOffset.width = newValue
                currentOffset.width = newValue
            }
            .onChange(of: layer.offsetY) { _, newValue in
                baseOffset.height = newValue
                currentOffset.height = newValue
            }
            .onChange(of: layer.scale) { _, newValue in
                baseScale = newValue
                currentScale = newValue
            }
            .onChange(of: layer.rotation) { _, newValue in
                let angle = Angle(degrees: newValue)
                baseRotation = angle
                currentRotation = angle
            }
    }
}
