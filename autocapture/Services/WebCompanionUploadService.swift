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
            let url = URL(string: raw)
        {
            self.baseURL = url
        } else {
            // Fallback to localhost for development; override with WEB_COMPANION_BASE_URL in Info.plist
            self.baseURL = URL(string: "http://localhost:3000")!
        }

        self.urlSession = urlSession
    }

    func upload(image: UIImage, stockNumber: String, filename: String) async throws -> UploadRecord {
        guard let imageData = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else {
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
            mimeType: "image/jpeg"
        )

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
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

