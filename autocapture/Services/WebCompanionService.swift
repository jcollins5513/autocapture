//
//  WebCompanionService.swift
//  AutoCapture
//
//  Created for Web Companion Export
//

import Foundation
import OSLog
import UIKit

enum WebCompanionService {
  private static let logger = Logger(subsystem: "com.autocapture", category: "WebCompanionService")

  // Replace this with your computer's local IP address or the production URL
  // For local testing with simulator, use localhost but mapped.
  // However, on actual device, need IP.
  // For now, assume we use the known dev URL or configuration.
  // We will use a standard base URL variable.

  // Retrieve base URL from Info.plist
  private static var baseURL: String {
    if let url = Bundle.main.object(forInfoDictionaryKey: "WEB_COMPANION_BASE_URL") as? String {
      // Remove trailing slash if present
      return url.hasSuffix("/") ? String(url.dropLast()) : url
    }
    return "https://www.supercenter.cc"
  }

  enum UploadError: LocalizedError {
    case invalidURL
    case imageEncodingFailed
    case uploadFailed(String)
    case invalidResponse

    var errorDescription: String? {
      switch self {
      case .invalidURL: return "Invalid API URL"
      case .imageEncodingFailed: return "Failed to encode image"
      case .uploadFailed(let reason): return "Upload failed: \(reason)"
      case .invalidResponse: return "Invalid response from server"
      }
    }
  }

  static func uploadImage(
    imageData: Data, stockNumber: String, isProcessed: Bool = true, filename: String = "capture.png"
  ) async throws {
    let endpoint = "\(baseURL)/api/web-companion/uploads"

    guard let url = URL(string: endpoint) else {
      throw UploadError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()

    // Stock Number
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append("Content-Disposition: form-data; name=\"stockNumber\"\r\n\r\n".data(using: .utf8)!)
    body.append("\(stockNumber)\r\n".data(using: .utf8)!)

    // isProcessed flag
    if isProcessed {
      body.append("--\(boundary)\r\n".data(using: .utf8)!)
      body.append(
        "Content-Disposition: form-data; name=\"isProcessed\"\r\n\r\n".data(using: .utf8)!)
      body.append("true\r\n".data(using: .utf8)!)
    }

    // File
    body.append("--\(boundary)\r\n".data(using: .utf8)!)
    body.append(
      "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(
        using: .utf8)!)
    body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
    body.append(imageData)
    body.append("\r\n".data(using: .utf8)!)

    body.append("--\(boundary)--\r\n".data(using: .utf8)!)

    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw UploadError.invalidResponse
    }

    if !(200...299).contains(httpResponse.statusCode) {
      let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown server error"
      logger.error("Upload failed: \(httpResponse.statusCode) - \(errorMsg)")
      throw UploadError.uploadFailed(errorMsg)
    }

    logger.info("Successfully uploaded image for stock \(stockNumber)")
  }
}
