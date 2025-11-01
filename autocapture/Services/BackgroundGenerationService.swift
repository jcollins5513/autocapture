//
//  BackgroundGenerationService.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Foundation
import UIKit

private struct BackgroundGenerationAPIResponse: Decodable {
    struct Item: Decodable {
        struct Content: Decodable {
            let type: String?
            let base64JSON: String?
            let url: String?
            let imageBase64: String?
            let revisedPrompt: String?

            enum CodingKeys: String, CodingKey {
                case type
                case base64JSON = "b64_json"
                case url
                case imageBase64 = "image_base64"
                case revisedPrompt = "revised_prompt"
            }
        }

        let base64JSON: String?
        let url: String?
        let content: [Content]?
        let revisedPrompt: String?

        enum CodingKeys: String, CodingKey {
            case base64JSON = "b64_json"
            case url
            case content
            case revisedPrompt = "revised_prompt"
        }
    }

    let data: [Item]
    
    // Allow additional fields that might be present but not used
    let outputFormat: String?
    let quality: String?
    let size: String?
    
    enum CodingKeys: String, CodingKey {
        case data
        case outputFormat = "output_format"
        case quality
        case size
        // Note: usage field is intentionally omitted as it's not needed
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode([Item].self, forKey: .data)
        outputFormat = try? container.decode(String.self, forKey: .outputFormat)
        quality = try? container.decode(String.self, forKey: .quality)
        size = try? container.decode(String.self, forKey: .size)
        // usage field is ignored - decoder will skip unknown keys when using custom init
    }
}

@MainActor
final class BackgroundGenerationService {
    private enum GenerationError: LocalizedError {
        case missingAPIKey
        case requestFailed
        case invalidResponse
        case service(message: String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key. Please configure the OPENAI_API_KEY environment variable."
            case .requestFailed:
                return "The background generation request failed."
            case .invalidResponse:
                return "Received an invalid response from the generation service."
            case .service(let message):
                return message
            }
        }
    }

    private let urlSession: URLSession
    private let apiKeyProvider: () -> String?
    private let organizationProvider: () -> String?
    private let promptBuilder = BackgroundPromptBuilder()

    init(
        urlSession: URLSession = .shared,
        apiKeyProvider: @escaping () -> String? = { ProcessInfo.processInfo.environment["OPENAI_API_KEY"] },
        organizationProvider: @escaping () -> String? = { ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] }
    ) {
        self.urlSession = urlSession
        self.apiKeyProvider = apiKeyProvider
        self.organizationProvider = organizationProvider
    }

// swiftlint:disable function_body_length
    func generateBackground(for request: BackgroundGenerationRequest) async throws -> BackgroundGenerationResult {
        let prompt = promptBuilder.prompt(for: request.category, customSubject: request.subjectDescription)
        let aspectRatio = request.aspectRatio

        guard let apiKey = apiKeyProvider(), apiKey.isEmpty == false else {
            throw GenerationError.missingAPIKey
        }

        guard let endpoint = URL(string: "https://api.openai.com/v1/images/generations") else {
            throw GenerationError.requestFailed
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organization = organizationProvider(), organization.isEmpty == false {
            urlRequest.addValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }

        let payload: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "size": size(for: aspectRatio)
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)

        print("[BackgroundGeneration] Payload:", payload)

        let (data, response) = try await urlSession.data(for: urlRequest)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[BackgroundGeneration] Status:", statusCode)
        if let rawBody = String(data: data, encoding: .utf8), rawBody.isEmpty == false {
            print("[BackgroundGeneration] Response Body:", rawBody)
        } else {
            print("[BackgroundGeneration] Response Body: <empty or binary>")
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let message = try? decodeServiceError(from: data) {
                throw GenerationError.service(message: message)
            } else {
                throw GenerationError.requestFailed
            }
        }

        // Log raw JSON structure for debugging
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("[BackgroundGeneration] Response keys:", jsonObject.keys.joined(separator: ", "))
            if let dataArray = jsonObject["data"] as? [[String: Any]], let firstItem = dataArray.first {
                print("[BackgroundGeneration] First data item keys:", firstItem.keys.joined(separator: ", "))
            }
        }

        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase as we have explicit CodingKeys mappings
        // decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Try to decode with flexible parsing
        let apiResponse: BackgroundGenerationAPIResponse
        do {
            apiResponse = try decoder.decode(BackgroundGenerationAPIResponse.self, from: data)
        } catch {
            print("[BackgroundGeneration] Decode error: \(error)")
            print("[BackgroundGeneration] Decode error details: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[BackgroundGeneration] Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("[BackgroundGeneration] Type mismatch for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("[BackgroundGeneration] Value not found for \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("[BackgroundGeneration] Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("[BackgroundGeneration] Unknown decoding error")
                }
            }
            print("[BackgroundGeneration] Raw response (first 500 chars): \(String(data: data.prefix(500), encoding: .utf8) ?? "invalid")")
            throw GenerationError.invalidResponse
        }

        guard let item = apiResponse.data.first else {
            print("[BackgroundGeneration] Invalid response: data array empty")
            if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("[BackgroundGeneration] Full response structure: \(jsonObject)")
            }
            throw GenerationError.invalidResponse
        }

        print(
            "[BackgroundGeneration] Parsed item: hasBase64=\(item.base64JSON != nil), hasURL=\(item.url != nil), hasContent=\(item.content != nil)"
        )
        
        // Debug: Check raw base64 value
        if let base64 = item.base64JSON {
            print("[BackgroundGeneration] Found base64 JSON: length=\(base64.count), preview=\(base64.prefix(50))...")
        } else {
            print("[BackgroundGeneration] base64JSON is nil")
        }
        
        // Debug: Check if we need to look at raw JSON directly
        if item.base64JSON == nil, let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = jsonObject["data"] as? [[String: Any]], let firstItem = dataArray.first {
            print("[BackgroundGeneration] Found data array in raw JSON but decoded item missing base64 - trying raw JSON extraction")
            if let imageDataResult = try? await imageDataFromRawJSON(rawJSON: firstItem, fallbackItem: item) {
                print("[BackgroundGeneration] Successfully extracted image data from raw JSON")
                let generatedBackground = GeneratedBackground(
                    prompt: prompt,
                    category: request.category,
                    aspectRatio: aspectRatio,
                    isCommunityShared: request.shareWithCommunity,
                    session: request.session,
                    imageData: imageDataResult
                )
                let image = UIImage(data: imageDataResult)
                return BackgroundGenerationResult(background: generatedBackground, image: image)
            }
        }
        
        if let content = item.content {
            print("[BackgroundGeneration] Content array count: \(content.count)")
            for (index, contentItem) in content.enumerated() {
                print("[BackgroundGeneration] Content[\(index)]: type=\(contentItem.type ?? "nil"), hasBase64=\(contentItem.base64JSON != nil), hasURL=\(contentItem.url != nil)")
            }
        }

        let imageData = try await imageData(from: item)
        print("[BackgroundGeneration] Decoded image bytes:", imageData.count)

        let generatedBackground = GeneratedBackground(
            prompt: prompt,
            category: request.category,
            aspectRatio: aspectRatio,
            isCommunityShared: request.shareWithCommunity,
            session: request.session,
            imageData: imageData
        )

        let image = UIImage(data: imageData)

        return BackgroundGenerationResult(background: generatedBackground, image: image)
    }
// swiftlint:enable function_body_length

    private func size(for aspectRatio: String) -> String {
        switch aspectRatio {
        case "1:1":
            return "1024x1024"
        case "3:2":
            return "1280x853"
        case "4:5":
            return "1024x1280"
        case "9:16":
            return "1024x1792"
        case "16:9":
            return "1792x1024"
        default:
            return "1792x1024"
        }
    }

    private func imageDataFromRawJSON(rawJSON: [String: Any], fallbackItem: BackgroundGenerationAPIResponse.Item) async throws -> Data? {
        // Try to extract base64 from raw JSON first
        if let b64Value = rawJSON["b64_json"] as? String, !b64Value.isEmpty {
            print("[BackgroundGeneration] Extracting from raw JSON b64_json field, length=\(b64Value.count)")
            if let data = decodeBase64Image(from: b64Value) {
                print("[BackgroundGeneration] Successfully decoded base64 from raw JSON, data size=\(data.count)")
                return data
            } else {
                print("[BackgroundGeneration] Failed to decode base64 from raw JSON")
            }
        } else {
            print("[BackgroundGeneration] No b64_json found in raw JSON")
        }
        
        if let urlString = rawJSON["url"] as? String, !urlString.isEmpty, let url = URL(string: urlString) {
            print("[BackgroundGeneration] Extracting from raw JSON url field: \(urlString)")
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[BackgroundGeneration] URL fetch failed with status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                throw GenerationError.invalidResponse
            }
            print("[BackgroundGeneration] Successfully fetched image from URL, size=\(data.count)")
            return data
        } else {
            print("[BackgroundGeneration] No valid url found in raw JSON")
        }
        
        // Fallback to standard parsing
        print("[BackgroundGeneration] Falling back to standard item parsing")
        return try await imageData(from: fallbackItem)
    }
    
    private func imageData(from item: BackgroundGenerationAPIResponse.Item) async throws -> Data {
        let inlineBase64 = item.base64JSON
            ?? item.content?.first(where: { content in
                guard let payload = content.base64JSON else { return false }
                return payload.isEmpty == false
            })?.base64JSON
            ?? item.content?.first(where: { content in
                guard let payload = content.imageBase64 else { return false }
                return payload.isEmpty == false
            })?.imageBase64

        if let base64 = inlineBase64 {
            print("[BackgroundGeneration] Inline base64 located:", summarizePayload(base64))
        } else {
            print("[BackgroundGeneration] No inline base64 present on response item.")
        }

        if let base64 = inlineBase64 {
            print("[BackgroundGeneration] Found inline base64 payload length:", base64.count)
            if let data = decodeBase64Image(from: base64) {
                return data
            } else {
                print("[BackgroundGeneration] Failed to decode base64 payload; falling back to URL if provided.")
            }
        }

        let inlineURL = item.url ?? item.content?.first(where: { content in
            guard let value = content.url else { return false }
            return value.isEmpty == false
        })?.url

        if let inlineURL {
            print("[BackgroundGeneration] Inline URL candidate located:", inlineURL)
        } else {
            print("[BackgroundGeneration] No URL candidate present on response item.")
        }

        if let urlString = inlineURL, let url = URL(string: urlString) {
            print("[BackgroundGeneration] Found URL payload:", urlString)
            print("[BackgroundGeneration] Fetching image from URL fallback.")
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[BackgroundGeneration] URL fallback produced no HTTP response")
                throw GenerationError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                print("[BackgroundGeneration] URL fallback failed with status:", httpResponse.statusCode)
                throw GenerationError.invalidResponse
            }
            return data
        }

        print("[BackgroundGeneration] Invalid response: no usable base64 or URL")
        throw GenerationError.invalidResponse
    }

    private func decodeBase64Image(from rawValue: String) -> Data? {
        print("[BackgroundGeneration] Raw base64 length:", rawValue.count)

        let sanitized = rawValue
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        print("[BackgroundGeneration] Sanitized base64 length:", sanitized.count)
        if sanitized.count > 16 {
            let previewStart = sanitized.prefix(12)
            let previewEnd = sanitized.suffix(12)
            print("[BackgroundGeneration] Base64 preview:", "\(previewStart)...\(previewEnd)")
        }

        if sanitized.isEmpty == false,
           let data = Data(base64Encoded: sanitized, options: .ignoreUnknownCharacters) {
            print("[BackgroundGeneration] Standard base64 decode succeeded")
            return data
        }

        // Attempt URL-safe base64 decoding by normalizing characters and padding
        var normalized = sanitized
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized.append(String(repeating: "=", count: 4 - remainder))
        }

        if let data = Data(base64Encoded: normalized, options: .ignoreUnknownCharacters) {
            print("[BackgroundGeneration] URL-safe base64 decode succeeded after normalization")
            return data
        }

        let remainderAfterPadding = normalized.count % 4
        print("[BackgroundGeneration] Base64 decode failed after normalization; normalized length:", normalized.count, "remainder:", remainderAfterPadding)
        print("[BackgroundGeneration] Base64 decode failed after all attempts")
        return nil
    }

    private func summarizePayload(_ payload: String) -> String {
        let length = payload.count
        if length <= 24 {
            return "len=\(length) value=\(payload)"
        }
        let prefix = payload.prefix(12)
        let suffix = payload.suffix(12)
        return "len=\(length) \(prefix)...\(suffix)"
    }

    private func decodeServiceError(from data: Data) throws -> String? {
        struct APIErrorResponse: Decodable {
            struct APIError: Decodable {
                let message: String
            }

            let error: APIError
        }

        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return errorResponse.error.message
        }

        if let rawMessage = String(data: data, encoding: .utf8), rawMessage.isEmpty == false {
            return rawMessage
        }

        return nil
    }
}
