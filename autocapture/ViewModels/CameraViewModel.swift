//
//  CameraViewModel.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftUI
import AVFoundation
import SwiftData
import Combine

@MainActor
class CameraViewModel: ObservableObject {
    let cameraService = CameraService()
    private let backgroundRemovalService = BackgroundRemovalService()
    
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    
    private var modelContext: ModelContext?
    
    init() {
        setupBindings()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    private func setupBindings() {
        // Bind flash mode
        cameraService.$flashMode
            .assign(to: &$flashMode)
        
        // Bind zoom factor
        cameraService.$currentZoomFactor
            .assign(to: &$currentZoomFactor)
    }
    
    func setupCamera() async {
        do {
            try await cameraService.setupSession()
            cameraService.startSession()
        } catch {
            handleError(error)
        }
    }
    
    func capturePhoto() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        do {
            // Capture photo
            let photo = try await cameraService.capturePhoto()
            
            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // Remove background
            let processedImage = try await backgroundRemovalService.removeBackground(from: photo)
            
            // Save to data store
            saveProcessedImage(processedImage)
            
            isProcessing = false
        } catch let error as CameraError {
            isProcessing = false
            handleError(error)
        } catch {
            isProcessing = false
            handleError(CameraError.photoCaptureFailed)
        }
    }
    
    func toggleFlash() {
        switch flashMode {
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        case .off:
            flashMode = .auto
        @unknown default:
            flashMode = .auto
        }
        cameraService.flashMode = flashMode
    }
    
    func flipCamera() {
        do {
            try cameraService.flipCamera()
        } catch {
            handleError(error)
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        cameraService.setZoom(factor)
    }
    
    func focus(at point: CGPoint, in bounds: CGRect) {
        cameraService.focus(at: point, in: bounds)
    }
    
    func stopCamera() {
        cameraService.stopSession()
    }
    
    private func saveProcessedImage(_ image: UIImage) {
        guard let context = modelContext else { return }
        
        let processedImage = ProcessedImage(image: image)
        context.insert(processedImage)
        
        do {
            try context.save()
        } catch {
            print("Failed to save image: \(error)")
        }
    }
    
    private func handleError(_ error: Error) {
        if let cameraError = error as? CameraError {
            errorMessage = cameraError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}

