//
//  CameraView.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftUI
import AVFoundation
import SwiftData

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showGallery = false
    @State private var baseZoomFactor: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.cameraService.session)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / baseZoomFactor
                            baseZoomFactor = value
                            let newZoom = viewModel.currentZoomFactor * delta
                            viewModel.setZoom(newZoom)
                        }
                        .onEnded { _ in
                            baseZoomFactor = 1.0
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            viewModel.focus(at: value.location, in: UIScreen.main.bounds)
                        }
                )
            
            // Controls overlay
            VStack {
                // Top controls
                HStack {
                    Spacer()
                    
                    // Gallery button
                    Button(action: { showGallery = true }) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    .padding()
                }
                
                Spacer()
                
                // Bottom controls
                HStack(spacing: 60) {
                    // Flash toggle
                    Button(action: { viewModel.toggleFlash() }) {
                        VStack(spacing: 4) {
                            Image(systemName: flashIcon)
                                .font(.system(size: 28))
                            Text(flashText)
                                .font(.caption2)
                        }
                        .foregroundColor(.white)
                    }
                    
                    // Capture button
                    Button(action: {
                        Task {
                            await viewModel.capturePhoto()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 75, height: 75)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 65, height: 65)
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    
                    // Flip camera
                    Button(action: { viewModel.flipCamera() }) {
                        Image(systemName: "camera.rotate")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 40)
            }
            
            // Processing overlay
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Processing...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
        .sheet(isPresented: $showGallery) {
            GalleryView()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Retake", role: .cancel) {
                Task {
                    await viewModel.capturePhoto()
                }
            }
            Button("Cancel", role: .destructive) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            viewModel.setModelContext(modelContext)
            await viewModel.setupCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
    }
    
    private var flashIcon: String {
        switch viewModel.flashMode {
        case .auto:
            return "bolt.badge.automatic"
        case .on:
            return "bolt.fill"
        case .off:
            return "bolt.slash.fill"
        @unknown default:
            return "bolt.badge.automatic"
        }
    }
    
    private var flashText: String {
        switch viewModel.flashMode {
        case .auto:
            return "Auto"
        case .on:
            return "On"
        case .off:
            return "Off"
        @unknown default:
            return "Auto"
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

#Preview {
    CameraView()
        .modelContainer(for: ProcessedImage.self, inMemory: true)
}

