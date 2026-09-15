//
//  CameraService.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import AVFoundation
import Combine
import UIKit

class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var currentDevice: AVCaptureDevice?

    @Published var isSessionRunning = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var isRecording = false
    @Published var captureMode: CaptureMediaMode = .photo

    private var photoContinuation: CheckedContinuation<UIImage, Error>?
    private var movieContinuation: CheckedContinuation<URL, Error>?

    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    override init() {
        super.init()
    }

    func checkAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    func setupSession() async throws {
        guard await checkAuthorization() else {
            throw CameraError.unauthorized
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Setup video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.cameraUnavailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else {
            throw CameraError.cameraUnavailable
        }

        session.addInput(videoInput)
        videoDeviceInput = videoInput
        currentDevice = videoDevice

        // Setup photo output
        guard session.canAddOutput(photoOutput) else {
            throw CameraError.cameraUnavailable
        }

        session.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        photoOutput.maxPhotoQualityPrioritization = .quality

        // Movie output lives alongside the photo output so switching between
        // stills and video never has to tear the session down.
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        session.commitConfiguration()

        addAudioInputIfAuthorized()
    }

    /// Microphone access is optional: video still records (silently) if the
    /// user declines, so this never blocks the camera from starting.
    private func addAudioInputIfAuthorized() {
        guard audioDeviceInput == nil else { return }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard let audioDevice = AVCaptureDevice.default(for: .audio),
              let audioInput = try? AVCaptureDeviceInput(device: audioDevice) else { return }

        session.beginConfiguration()
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
            audioDeviceInput = audioInput
        }
        session.commitConfiguration()
    }

    @discardableResult
    func requestMicrophoneAccess() async -> Bool {
        let granted: Bool
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            granted = true
        case .notDetermined:
            granted = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            granted = false
        }

        if granted {
            addAudioInputIfAuthorized()
        }
        return granted
    }

    // MARK: - Video recording

    /// Stills want the `.photo` preset for maximum resolution while movies need
    /// a video preset, so the mode switch reconfigures the running session.
    func setCaptureMode(_ mode: CaptureMediaMode) {
        guard captureMode != mode else { return }
        guard movieOutput.isRecording == false else { return }

        let preset: AVCaptureSession.Preset = mode == .photo ? .photo : .high
        session.beginConfiguration()
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        }
        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            self?.captureMode = mode
        }
    }

    func startRecording() throws {
        guard movieOutput.isRecording == false else { return }
        guard session.outputs.contains(movieOutput) else {
            throw CameraError.videoCaptureFailed
        }

        if let connection = movieOutput.connection(with: .video) {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = .auto
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = videoDeviceInput?.device.position == .front
            }
        }

        let url = VideoFileStore.makeTemporaryURL()
        movieOutput.startRecording(to: url, recordingDelegate: self)
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
        }
    }

    /// Stops the current recording and resolves with the raw movie on disk.
    func stopRecording() async throws -> URL {
        guard movieOutput.isRecording else {
            throw CameraError.videoCaptureFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            movieContinuation = continuation
            movieOutput.stopRecording()
        }
    }

    func startSession() {
        guard !isSessionRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        guard isSessionRunning else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }

    func capturePhoto() async throws -> UIImage {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        settings.photoQualityPrioritization = .quality

        if let connection = photoOutput.connection(with: .video) {
            if let orientation = await fetchCurrentVideoOrientation() {
                connection.videoOrientation = orientation
            }

            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = videoDeviceInput?.device.position == .front
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            photoContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func fetchCurrentVideoOrientation() async -> AVCaptureVideoOrientation? {
        await MainActor.run {
            if let interfaceOrientation = UIApplication.shared
                .connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })?
                .interfaceOrientation,
               let orientation = AVCaptureVideoOrientation(interfaceOrientation: interfaceOrientation) {
                return orientation
            }

            return AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation)
        }
    }

    func flipCamera() throws {
        guard movieOutput.isRecording == false else { return }
        guard let currentInput = videoDeviceInput else { return }

        session.beginConfiguration()
        session.removeInput(currentInput)

        let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw CameraError.cameraUnavailable
        }

        session.addInput(newInput)
        videoDeviceInput = newInput
        currentDevice = newDevice
        currentZoomFactor = 1.0

        session.commitConfiguration()
    }

    func setZoom(_ factor: CGFloat) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            let clampedFactor = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }

    func focus(at point: CGPoint, in bounds: CGRect) {
        guard let device = currentDevice else { return }

        let focusPoint = CGPoint(
            x: point.y / bounds.height,
            y: 1.0 - point.x / bounds.width
        )

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
        } catch {
            print("Failed to focus: \(error)")
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }

        let continuation = movieContinuation
        movieContinuation = nil

        if let error {
            try? FileManager.default.removeItem(at: outputFileURL)
            continuation?.resume(throwing: error)
            return
        }

        continuation?.resume(returning: outputFileURL)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoContinuation?.resume(throwing: error)
            photoContinuation = nil
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoContinuation?.resume(throwing: CameraError.photoCaptureFailed)
            photoContinuation = nil
            return
        }

        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}
