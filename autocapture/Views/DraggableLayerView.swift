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
    // Subject footprint as fractions of the image, so the contact shadow hugs
    // the subject instead of the transparent frame. Defaults to the full frame.
    @State private var contentFraction = CGRect(x: 0, y: 0, width: 1, height: 1)

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .background {
                if layer.type == .subject {
                    GeometryReader { geo in
                        let shadowWidth = geo.size.width * contentFraction.width * 0.95
                        let shadowHeight = shadowWidth * 0.14
                        let centerX = geo.size.width * contentFraction.midX
                        let baseY = geo.size.height * contentFraction.maxY
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [Color.black.opacity(0.4), Color.black.opacity(0)]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: max(shadowWidth, 1) * 0.5
                                )
                            )
                            .frame(width: max(shadowWidth, 1), height: max(shadowHeight, 1))
                            .position(x: centerX, y: baseY - shadowHeight * 0.25)
                            .blur(radius: 2)
                            .allowsHitTesting(false)
                    }
                }
            }
            .scaleEffect(currentScale)
            .rotationEffect(currentRotation)
            .offset(currentOffset)
            // Thin dashed outline marks selection without a glow that would
            // obscure how the composite actually looks. Tap empty canvas to
            // clear the selection for a fully clean preview.
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.9) : Color.clear,
                        style: StrokeStyle(lineWidth: isSelected ? 1.5 : 0, dash: [6, 4])
                    )
            )
            .highPriorityGesture(
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
                if layer.type == .subject,
                   let fraction = SubjectGeometry.normalizedOpaqueBounds(of: image) {
                    contentFraction = fraction
                }
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
