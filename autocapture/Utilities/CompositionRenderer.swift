//
//  CompositionRenderer.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import CoreGraphics
import OSLog
import SwiftUI
import UIKit

enum CompositionRenderer {
    private static let logger = Logger(subsystem: "com.autocapture", category: "CompositionRenderer")

    static func render(project: CompositionProject, canvasSize: CGSize) -> UIImage? {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let layers = project.layers
            .filter { $0.isVisible }
            .sorted { $0.order < $1.order }
        logger.debug("Rendering composition. canvasSize=\(String(describing: canvasSize), privacy: .public) visibleLayerCount=\(layers.count, privacy: .public) hasBackground=\(project.background != nil, privacy: .public)")

        let backgroundImage = project.background?.imageData.flatMap { UIImage(data: $0) }

        // Relight subjects toward the background's floor tone so they don't look
        // pasted on. Skipped entirely when the user has disabled it or there's
        // no background to sample.
        let matchStrength = project.colorMatchEnabled ? CGFloat(project.colorMatchStrength) : 0
        let backgroundTone: SubjectColorMatch.Tone? = (matchStrength > 0)
            ? backgroundImage.flatMap { SubjectColorMatch.backgroundTone(of: $0) }
            : nil

        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: canvasSize)
            context.cgContext.setFillColor(UIColor.systemBackground.cgColor)
            context.cgContext.fill(rect)

            if let backgroundImage {
                drawBackground(backgroundImage, in: context.cgContext, canvasSize: canvasSize)
            }

            for layer in layers {
                guard let image = UIImage(data: layer.imageData) else { continue }
                drawLayer(
                    image: image,
                    layer: layer,
                    context: context.cgContext,
                    canvasSize: canvasSize,
                    backgroundTone: backgroundTone,
                    matchStrength: matchStrength
                )
            }
        }

        return image
    }

    private static func drawBackground(_ image: UIImage, in context: CGContext, canvasSize: CGSize) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let scale = max(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (canvasSize.width - scaledSize.width) / 2,
            y: (canvasSize.height - scaledSize.height) / 2
        )
        let drawRect = CGRect(origin: origin, size: scaledSize)
        logger.debug("Drawing background. imageSize=\(imageSize.debugDescription, privacy: .public) scale=\(scale, privacy: .public) drawRect=\(drawRect.debugDescription, privacy: .public)")

        context.saveGState()
        context.addRect(CGRect(origin: .zero, size: canvasSize))
        context.clip()
        image.draw(in: drawRect)
        context.restoreGState()
    }

    private static func drawLayer(
        image: UIImage,
        layer: CompositionLayer,
        context: CGContext,
        canvasSize: CGSize,
        backgroundTone: SubjectColorMatch.Tone? = nil,
        matchStrength: CGFloat = 0
    ) {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let offset = CGPoint(x: center.x + CGFloat(layer.offsetX), y: center.y + CGFloat(layer.offsetY))
        let rotation = CGFloat(layer.rotation) * .pi / 180
        let scale = CGFloat(layer.scale)

        context.saveGState()
        context.translateBy(x: offset.x, y: offset.y)
        context.rotate(by: rotation)
        context.scaleBy(x: scale, y: scale)
        context.setAlpha(layer.opacity)

        let imageSize = image.size
        let drawRect = CGRect(
            x: -imageSize.width / 2,
            y: -imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        )
        logger.debug("Drawing layer. name=\(layer.name, privacy: .public) order=\(layer.order, privacy: .public) imageSize=\(imageSize.debugDescription, privacy: .public) offset=(\(offset.x, privacy: .public), \(offset.y, privacy: .public)) rotationDegrees=\(layer.rotation, privacy: .public) scale=\(layer.scale, privacy: .public) opacity=\(layer.opacity, privacy: .public)")

        // Relight the subject toward the background before drawing so the
        // grounding effects (reflection/shadow) and the subject itself all share
        // the corrected tone. Non-subject layers are drawn as-is.
        var drawImage = image
        if layer.type == .subject {
            if let backgroundTone, matchStrength > 0 {
                drawImage = SubjectColorMatch.matched(
                    subject: image,
                    toward: backgroundTone,
                    strength: matchStrength
                )
            }

            // Ground the subject with a soft contact shadow so it doesn't look
            // like it's floating on the background. Drawn before the subject so
            // the subject sits on top of it, and anchored to the subject's actual
            // (non-transparent) footprint rather than the transparent image frame.
            let contentBounds = SubjectGeometry.opaqueBounds(of: drawImage)
                ?? CGRect(origin: .zero, size: imageSize)
            // Faint mirrored reflection first, then the contact shadow on top of
            // it near the tires, then the subject over both.
            drawReflection(
                image: drawImage,
                contentBounds: contentBounds,
                imageSize: imageSize,
                context: context,
                opacity: layer.opacity
            )
            drawContactShadow(
                contentBounds: contentBounds,
                imageSize: imageSize,
                context: context,
                opacity: layer.opacity
            )
        }

        drawImage.draw(in: drawRect)
        context.restoreGState()
    }

    /// Draws a faint, downward-fading mirror of the subject under its base to
    /// suggest a reflective showroom floor. Subtle so it reads as sheen on
    /// matte floors and as a reflection on glossy ones.
    private static func drawReflection(
        image: UIImage,
        contentBounds: CGRect,
        imageSize: CGSize,
        context: CGContext,
        opacity: Double
    ) {
        guard contentBounds.height > 0, imageSize.height > 0 else { return }
        let localBaseY = contentBounds.maxY - imageSize.height / 2
        let reflectionOpacity = 0.16 * opacity
        guard reflectionOpacity > 0 else { return }

        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)

        // Mirror the subject across its base line and draw it going downward.
        context.saveGState()
        context.translateBy(x: 0, y: 2 * localBaseY)
        context.scaleBy(x: 1, y: -1)
        context.setAlpha(reflectionOpacity)
        image.draw(in: CGRect(
            x: -imageSize.width / 2,
            y: -imageSize.height / 2,
            width: imageSize.width,
            height: imageSize.height
        ))
        context.restoreGState()

        // Fade the reflection out with distance from the base.
        context.setBlendMode(.destinationOut)
        let fadeColors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(1.0).cgColor
        ] as CFArray
        if let fade = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: fadeColors,
            locations: [0.0, 1.0]
        ) {
            context.drawLinearGradient(
                fade,
                start: CGPoint(x: 0, y: localBaseY),
                end: CGPoint(x: 0, y: localBaseY + contentBounds.height * 0.5),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// Draws a soft elliptical shadow pooled under the subject's footprint, in
    /// the layer's already-transformed (centered) coordinate space so it tracks
    /// the subject's position, scale, and rotation.
    private static func drawContactShadow(
        contentBounds: CGRect,
        imageSize: CGSize,
        context: CGContext,
        opacity: Double
    ) {
        guard contentBounds.width > 0, contentBounds.height > 0 else { return }

        let shadowWidth = contentBounds.width * 0.95
        let shadowHeight = shadowWidth * 0.14
        let radius = shadowWidth / 2
        guard radius > 0, shadowHeight > 0 else { return }

        // Local space is centered on the image, so convert the footprint's
        // horizontal center and bottom edge into that space, then tuck the
        // shadow just under the subject's base so it reads as contact.
        let centerX = contentBounds.midX - imageSize.width / 2
        let baseY = contentBounds.maxY - imageSize.height / 2
        let centerY = baseY - shadowHeight * 0.25

        let colors = [
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ] as CFArray
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0.0, 1.0]
        ) else { return }

        context.saveGState()
        context.setAlpha(opacity)
        // Center on the footprint base, then squash vertically so the radial
        // gradient becomes a soft ellipse.
        context.translateBy(x: centerX, y: centerY)
        context.scaleBy(x: 1.0, y: shadowHeight / shadowWidth)
        context.drawRadialGradient(
            gradient,
            startCenter: .zero,
            startRadius: 0,
            endCenter: .zero,
            endRadius: radius,
            options: []
        )
        context.restoreGState()
    }
}
