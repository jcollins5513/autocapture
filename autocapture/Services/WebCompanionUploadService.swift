//
//  WebCompanionUploadService.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 12/08/25.
//

import Foundation
import OSLog
import UIKit

struct WebCompanionUploadService {
    struct UploadRecord: Decodable {
        let id: String
        let stockNumber: String
        let originalUrl: String?
        let processedUrl: String?
        let status: String?
        let originalFilename: String?
        let imageIndex: Int?
    }

    private struct UploadResponse: Decodable {
        let success: Bool
        let upload: UploadRecord?
        let error: String?
    }

    private let logger = Logger(subsystem: "com.autocapture", category: "WebCompanionUploadService")
    private let urlSession: URLSession
    private let baseURL: URL

    init(baseURL: URL? = nil, urlSession: URLSession = .shared) {
        if let baseURL {
            self.baseURL = baseURL
        } else if
            let raw = Bundle.main.object(forInfoDictionaryKey: "WEB_COMPANION_BASE_URL") as? String,
            let url = URL(string: raw.hasSuffix("/") ? String(raw.dropLast()) : raw)
        {
            self.baseURL = url
        } else {
            // Fail closed to production, not localhost: a missing Info.plist key
            // must never silently point real-device uploads at a dev machine.
            self.baseURL = URL(string: "https://www.supercenter.cc")!
        }

        self.urlSession = urlSession
    }

    func upload(image: UIImage, stockNumber: String, filename: String) async throws -> UploadRecord {
        // Label the part with the type we actually encoded — the server stores
        // this Content-Type verbatim, so a PNG mislabeled as JPEG gets cached
        // with the wrong type for a year.
        let imageData: Data
        let mimeType: String
        if let jpeg = image.jpegData(compressionQuality: 0.9) {
            imageData = jpeg
            mimeType = "image/jpeg"
        } else if let png = image.pngData() {
            imageData = png
            mimeType = "image/png"
        } else {
            throw UploadError.encodingFailed
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: baseURL.appendingPathComponent("api/web-companion/uploads"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = makeFormData(
            boundary: boundary,
            stockNumber: stockNumber,
            filename: filename,
            data: imageData,
            mimeType: mimeType
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            // Prefer the server's `{ error }` message over the raw JSON body so
            // users don't see a literal blob.
            let message = Self.serverErrorMessage(from: data) ?? "Server error (\(httpResponse.statusCode))"
            logger.error("Upload failed with status \(httpResponse.statusCode, privacy: .public) message: \(message, privacy: .public)")
            throw UploadError.serverError(message)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let parsed = try decoder.decode(UploadResponse.self, from: data)

        if parsed.success, let upload = parsed.upload {
            return upload
        } else {
            throw UploadError.serverError(parsed.error ?? "Upload failed")
        }
    }

    private struct ServerErrorBody: Decodable { let error: String? }

    /// Extracts a human-readable message from a `{ "error": "..." }` response,
    /// falling back to nil when the body isn't that shape.
    private static func serverErrorMessage(from data: Data) -> String? {
        if let parsed = try? JSONDecoder().decode(ServerErrorBody.self, from: data),
           let error = parsed.error, error.isEmpty == false {
            return error
        }
        return nil
    }

    private func makeFormData(
        boundary: String,
        stockNumber: String,
        filename: String,
        data: Data,
        mimeType: String
    ) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        let boundaryPrefix = "--\(boundary)\r\n"

        if let stockField = "--\(boundary)\r\n".data(using: .utf8) {
            body.append(stockField)
        }
        body.append("Content-Disposition: form-data; name=\"stockNumber\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(stockNumber)\r\n".data(using: .utf8)!)

        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append(lineBreak.data(using: .utf8)!)
        body.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return body
    }

    enum UploadError: LocalizedError {
        case encodingFailed
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .encodingFailed:
                return "Could not encode image for upload."
            case .invalidResponse:
                return "Server response was invalid."
            case .serverError(let message):
                return message
            }
        }
    }
}

