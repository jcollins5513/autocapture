//
//  CameraView.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import AVFoundation
import SwiftData
import SwiftUI

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.modelContext)
    private var modelContext
    @AppStorage("capture.subjectMode")
    private var storedSubjectModeRawValue = CaptureSubjectMode.singleSubject.rawValue
    @State private var showGallery = false
    @State private var baseZoomFactor: CGFloat = 1.0
    private let session: CaptureSession?
    @State private var subjectDescription: String = ""
    @State private var selectedSubjectMode: CaptureSubjectMode = .singleSubject
    @AppStorage("capture.mediaMode")
    private var storedMediaModeRawValue = CaptureMediaMode.photo.rawValue
    @State private var selectedMediaMode: CaptureMediaMode = .photo

    init(session: CaptureSession? = nil) {
        self._viewModel = StateObject(wrappedValue: CameraViewModel())
        self.session = session
    }

    var body: some View {
        ZStack {
            cameraPreview
            controlsOverlay
            processingOverlay
        }
        .sheet(isPresented: $showGallery) {
            GalleryView()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            if selectedMediaMode == .photo {
                Button("Retake", role: .cancel) {
                    Task {
                        await viewModel.capturePhoto()
                    }
                }
                Button("Cancel", role: .destructive) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .task {
            viewModel.setModelContext(modelContext)
            viewModel.setActiveSession(session)
            let initialMode = CaptureSubjectMode(rawValue: storedSubjectModeRawValue) ?? .singleSubject
            selectedSubjectMode = initialMode
            viewModel.subjectMode = initialMode
            let initialMediaMode = CaptureMediaMode(rawValue: storedMediaModeRawValue) ?? .photo
            selectedMediaMode = initialMediaMode
            viewModel.captureMediaMode = initialMediaMode
            await viewModel.setupCamera()
            subjectDescription = viewModel.subjectDescription
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .onChange(of: subjectDescription) { _, newValue in
            viewModel.subjectDescription = newValue
        }
        .onChange(of: selectedSubjectMode) { _, newValue in
            storedSubjectModeRawValue = newValue.rawValue
            viewModel.subjectMode = newValue
        }
        .onChange(of: selectedMediaMode) { _, newValue in
            storedMediaModeRawValue = newValue.rawValue
            viewModel.captureMediaMode = newValue
        }
    }

    private var cameraPreview: some View {
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
    }

    private var controlsOverlay: some View {
        VStack {
            topControls
            Spacer()
            bottomControls
        }
    }

    private var topControls: some View {
        HStack(alignment: .top) {
            if let session {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stock: \(session.stockNumber)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.35))
                        .clipShape(Capsule())
                    TextField("Subject description", text: $subjectDescription)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .padding(6)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundColor(.white)
                        .frame(maxWidth: 240)
                        .onSubmit {
                            viewModel.subjectDescription = subjectDescription
                        }
                }
                .padding(.leading)
                .transition(.opacity)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 12) {
                subjectModePicker
                galleryButton
            }
            .padding(.trailing)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            if viewModel.isRecording {
                recordingIndicator
            } else {
                mediaModePicker
            }

            HStack(spacing: 60) {
                flashButton
                captureButton
                flipCameraButton
            }
        }
        .padding(.bottom, 40)
    }

    private var mediaModePicker: some View {
        Picker("Capture Mode", selection: $selectedMediaMode) {
            ForEach(CaptureMediaMode.allCases) { mode in
                Label(mode.displayName, systemImage: mode.iconName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .disabled(viewModel.isProcessing)
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)
            Text(formattedRecordingDuration)
                .font(.callout.monospacedDigit())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.45)))
    }

    private var formattedRecordingDuration: String {
        let total = Int(viewModel.recordingDuration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    @ViewBuilder private var processingOverlay: some View {
        if viewModel.isProcessing {
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    if viewModel.processingProgress > 0 {
                        ProgressView(value: viewModel.processingProgress)
                            .progressViewStyle(.linear)
                            .tint(.white)
                            .frame(width: 220)
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }

                    Text(viewModel.processingMessage)
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
    }

    private var galleryButton: some View {
        Button(
            action: {
                showGallery = true
            },
            label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
        )
    }

    private var subjectModePicker: some View {
        Menu {
            ForEach(CaptureSubjectMode.allCases) { mode in
                Button {
                    selectedSubjectMode = mode
                } label: {
                    Label(mode.subtitle, systemImage: mode.iconName)
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedSubjectMode.iconName)
                    .font(.system(size: 16, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedSubjectMode.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(selectedSubjectMode.description)
                        .font(.caption2)
                        .opacity(0.85)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .foregroundColor(.white)
        }
    }

    private var flashButton: some View {
        Button(
            action: {
                viewModel.toggleFlash()
            },
            label: {
                VStack(spacing: 4) {
                    Image(systemName: flashIcon)
                        .font(.system(size: 28))
                    Text(flashText)
                        .font(.caption2)
                }
                .foregroundColor(.white)
            }
        )
    }

    private var captureButton: some View {
        Button(
            action: {
                Task {
                    switch selectedMediaMode {
                    case .photo:
                        await viewModel.capturePhoto()
                    case .video:
                        await viewModel.toggleRecording()
                    }
                }
            },
            label: {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 75, height: 75)

                    if selectedMediaMode == .video, viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 32, height: 32)
                    } else {
                        Circle()
                            .fill(selectedMediaMode == .video ? .red : .white)
                            .frame(width: 65, height: 65)
                    }
                }
            }
        )
        .disabled(viewModel.isProcessing)
    }

    private var flipCameraButton: some View {
        Button(
            action: {
                viewModel.flipCamera()
            },
            label: {
                Image(systemName: "camera.rotate")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
        )
        .disabled(viewModel.isRecording)
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

#Preview {
    CameraView()
        .modelContainer(for: [CaptureSession.self, ProcessedImage.self, ProcessedVideo.self], inMemory: true)
}
