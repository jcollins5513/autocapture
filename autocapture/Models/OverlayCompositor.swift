//
//  OverlayCompositor.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/19/25.
//
import UIKit
struct OverlayCompositor {
    func composite(subject: UIImage, onto overlay: UIImage) -> UIImage? {
        let targetSize = subject.size
        guard targetSize.width > 0, targetSize.height > 0 else {
            return nil
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = subject.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let image = renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            let overlayRect = aspectFillRect(for: overlay.size, in: CGRect(origin: .zero, size: targetSize))
            overlay.draw(in: overlayRect, blendMode: .normal, alpha: 1.0)
            subject.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return image
    }
    private func aspectFillRect(for contentSize: CGSize, in bounds: CGRect) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0 else { return bounds }
        let scale = max(bounds.width / contentSize.width, bounds.height / contentSize.height)
        let scaledSize = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
        let origin = CGPoint(
            x: bounds.midX - scaledSize.width / 2,
            y: bounds.midY - scaledSize.height / 2
        )
        return CGRect(origin: origin, size: scaledSize)
    }
}