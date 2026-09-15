//
//  VideoFileStore.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import AVFoundation
import Foundation
import OSLog
import UIKit

/// Videos are far too large to live inside SwiftData, so they are kept as files
/// on disk and referenced by filename from `ProcessedVideo`.
enum VideoFileStore {
    private static let logger = Logger(subsystem: "com.autocapture", category: "VideoFileStore")
    private static let directoryName = "AutoCaptureVideos"

    static var directory: URL {
        let base: URL
        do {
            base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            base = URL.temporaryDirectory
        }

        let directory = base.appending(path: directoryName, directoryHint: .isDirectory)
        if FileManager.default.fileExists(atPath: directory.path) == false {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func url(forFilename filename: String) -> URL {
        directory.appending(path: filename, directoryHint: .notDirectory)
    }

    static func fileExists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(forFilename: filename).path)
    }

    /// Creates a unique destination inside the store without creating the file.
    static func makeDestinationURL(extension pathExtension: String = "mov") -> URL {
        url(forFilename: "\(UUID().uuidString).\(pathExtension)")
    }

    /// Creates a unique destination in the temporary directory, used for raw
    /// recordings before they are processed.
    static func makeTemporaryURL(extension pathExtension: String = "mov") -> URL {
        URL.temporaryDirectory.appending(path: "\(UUID().uuidString).\(pathExtension)", directoryHint: .notDirectory)
    }

    /// Copies an external video (camera recording, Photos import) into the store
    /// and returns the stored filename.
    @discardableResult
    static func importFile(at sourceURL: URL) throws -> String {
        let destination = makeDestinationURL(extension: sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination.lastPathComponent
    }

    /// Moves a file that was written directly (for example by the lift service)
    /// into the store and returns the stored filename.
    @discardableResult
    static func adopt(fileAt sourceURL: URL) throws -> String {
        if sourceURL.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL {
            return sourceURL.lastPathComponent
        }
        let destination = makeDestinationURL(extension: sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension)
        try FileManager.default.moveItem(at: sourceURL, to: destination)
        return destination.lastPathComponent
    }

    static func delete(filename: String?) {
        guard let filename, filename.isEmpty == false else { return }
        let target = url(forFilename: filename)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
        } catch {
            logger.error("Failed to delete video \(filename, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Renders a poster frame, used for grid thumbnails so playback is not
    /// needed just to show a card.
    static func thumbnail(for url: URL, maximumDimension: CGFloat = 600) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumDimension, height: maximumDimension)

        do {
            let (cgImage, _) = try await generator.image(at: CMTime(seconds: 0.1, preferredTimescale: 600))
            return UIImage(cgImage: cgImage)
        } catch {
            logger.error("Thumbnail generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func duration(for url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        return duration.map(CMTimeGetSeconds) ?? 0
    }
}
