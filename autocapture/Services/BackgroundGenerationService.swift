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
        let base64JSON: String?
        let url: String?
    }

    let data: [Item]
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiResponse = try decoder.decode(BackgroundGenerationAPIResponse.self, from: data)

        guard let item = apiResponse.data.first else {
            throw GenerationError.invalidResponse
        }

        let imageData = try await imageData(from: item)

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

    private func imageData(from item: BackgroundGenerationAPIResponse.Item) async throws -> Data {
        if let base64 = item.base64JSON, let data = Data(base64Encoded: base64) {
            return data
        }

        if let urlString = item.url, let url = URL(string: urlString) {
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw GenerationError.invalidResponse
            }
            return data
        }

        throw GenerationError.invalidResponse
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
