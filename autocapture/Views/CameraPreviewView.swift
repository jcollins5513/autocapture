//
//  CameraPreviewView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        view.previewLayer = previewLayer
        context.coordinator.previewLayer = previewLayer
        context.coordinator.containerView = view
        context.coordinator.updateVideoOrientation()
        context.coordinator.startObservingOrientationChanges()

        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
        context.coordinator.containerView = uiView
        context.coordinator.updateVideoOrientation()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
        weak var containerView: PreviewContainerView?

        private var orientationObserver: NSObjectProtocol?
        private var didBeginOrientationUpdates = false

        deinit {
            stopObservingOrientationChanges()
        }

        func startObservingOrientationChanges() {
            stopObservingOrientationChanges()

            if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                didBeginOrientationUpdates = true
            }

            orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateVideoOrientation()
            }
        }

        func stopObservingOrientationChanges() {
            if let observer = orientationObserver {
                NotificationCenter.default.removeObserver(observer)
                orientationObserver = nil
            }

            if didBeginOrientationUpdates, UIDevice.current.isGeneratingDeviceOrientationNotifications {
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
                didBeginOrientationUpdates = false
            }
        }

        func updateVideoOrientation() {
            guard let connection = previewLayer?.connection else { return }

            if let interfaceOrientation = containerView?.window?.windowScene?.interfaceOrientation,
               let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: interfaceOrientation) {
                connection.videoOrientation = videoOrientation
                return
            }

            let deviceOrientation = UIDevice.current.orientation
            if let videoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation) {
                connection.videoOrientation = videoOrientation
            }
        }
    }
}

private final class PreviewContainerView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            oldValue?.removeFromSuperlayer()

            if let previewLayer {
                layer.addSublayer(previewLayer)
                setNeedsLayout()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

private extension AVCaptureVideoOrientation {
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeLeft
        case .landscapeRight:
            self = .landscapeRight
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait:
            self = .portrait
        case .portraitUpsideDown:
            self = .portraitUpsideDown
        case .landscapeLeft:
            self = .landscapeRight
        case .landscapeRight:
            self = .landscapeLeft
        default:
            return nil
        }
    }
}
