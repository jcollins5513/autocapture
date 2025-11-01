//
//  SocialMediaPostService.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import Foundation
import OSLog

enum PostType: String, CaseIterable, Identifiable {
    case facebook
    case marketplace
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .facebook:
            return "Facebook Post"
        case .marketplace:
            return "Marketplace Listing"
        }
    }
    
    var systemImage: String {
        switch self {
        case .facebook:
            return "square.and.pencil"
        case .marketplace:
            return "cart.badge.plus"
        }
    }
}

struct SocialMediaPost {
    let type: PostType
    let title: String
    let description: String
    let price: String?
    let location: String?
    let hashtags: [String]
    let createdAt: Date
}

@MainActor
final class SocialMediaPostService {
    private enum PostGenerationError: LocalizedError {
        case missingAPIKey
        case requestFailed
        case invalidResponse
        case service(message: String)
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Missing OpenAI API key. Please configure the OPENAI_API_KEY environment variable."
            case .requestFailed:
                return "The post generation request failed."
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
    private let logger = Logger(subsystem: "com.autocapture", category: "SocialMediaPostService")
    
    init(
        urlSession: URLSession = .shared,
        apiKeyProvider: @escaping () -> String? = { ProcessInfo.processInfo.environment["OPENAI_API_KEY"] },
        organizationProvider: @escaping () -> String? = { ProcessInfo.processInfo.environment["OPENAI_ORG_ID"] }
    ) {
        self.urlSession = urlSession
        self.apiKeyProvider = apiKeyProvider
        self.organizationProvider = organizationProvider
    }
    
    func generatePost(
        type: PostType,
        vehicleInfo: String,
        stockNumber: String,
        category: BackgroundCategory,
        includePrice: Bool = false,
        price: String? = nil,
        location: String? = nil
    ) async throws -> SocialMediaPost {
        guard let apiKey = apiKeyProvider(), apiKey.isEmpty == false else {
            throw PostGenerationError.missingAPIKey
        }
        
        guard let endpoint = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw PostGenerationError.requestFailed
        }
        
        let prompt = buildPrompt(
            type: type,
            vehicleInfo: vehicleInfo,
            stockNumber: stockNumber,
            category: category,
            includePrice: includePrice,
            price: price,
            location: location
        )
        
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let organization = organizationProvider(), organization.isEmpty == false {
            urlRequest.addValue(organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        
        let payload: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert social media marketer specializing in automotive sales. Create compelling, professional posts that highlight vehicle features and encourage engagement."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        logger.debug("Generating \(type.displayName) post for stock number: \(stockNumber)")
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let message = try? decodeServiceError(from: data) {
                throw PostGenerationError.service(message: message)
            } else {
                throw PostGenerationError.requestFailed
            }
        }
        
        let parsedPost = try parseResponse(data: data, type: type, price: price, location: location)
        
        logger.info("Successfully generated \(type.displayName) post")
        return parsedPost
    }
    
    private func buildPrompt(
        type: PostType,
        vehicleInfo: String,
        stockNumber: String,
        category: BackgroundCategory,
        includePrice: Bool,
        price: String?,
        location: String?
    ) -> String {
        var prompt = ""
        
        switch type {
        case .facebook:
            prompt = """
            Create a compelling Facebook post for a vehicle listing. Include:
            
            1. An engaging title/caption (keep it under 50 characters)
            2. A detailed description highlighting key features (3-4 sentences)
            3. Relevant hashtags (5-7 hashtags)
            
            Vehicle Information:
            Stock Number: \(stockNumber)
            Details: \(vehicleInfo)
            Category: \(category.displayName)
            """
            
            if includePrice, let price = price {
                prompt += "\nPrice: \(price)"
            }
            
            prompt += "\n\nMake the post friendly, professional, and compelling. Format the response as JSON with keys: 'title', 'description', 'hashtags' (as array)."
            
        case .marketplace:
            prompt = """
            Create a professional marketplace listing for a vehicle. Include:
            
            1. A clear, descriptive title (under 60 characters)
            2. A detailed description with key features, condition, and highlights (5-6 sentences)
            3. Relevant hashtags for searchability (3-5 hashtags)
            
            Vehicle Information:
            Stock Number: \(stockNumber)
            Details: \(vehicleInfo)
            Category: \(category.displayName)
            """
            
            if let price = price {
                prompt += "\nPrice: \(price)"
            }
            if let location = location {
                prompt += "\nLocation: \(location)"
            }
            
            prompt += "\n\nMake the listing professional and detailed. Format the response as JSON with keys: 'title', 'description', 'hashtags' (as array)."
        }
        
        return prompt
    }
    
    private func parseResponse(
        data: Data,
        type: PostType,
        price: String?,
        location: String?
    ) throws -> SocialMediaPost {
        struct ChatCompletionResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        struct PostResponse: Decodable {
            let title: String
            let description: String
            let hashtags: [String]
        }
        
        let decoder = JSONDecoder()
        let completionResponse = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard let content = completionResponse.choices.first?.message.content else {
            throw PostGenerationError.invalidResponse
        }
        
        // Extract JSON from the response (may be wrapped in markdown code blocks)
        let jsonString = extractJSON(from: content)
        
        guard let jsonData = jsonString.data(using: .utf8),
              let postResponse = try? decoder.decode(PostResponse.self, from: jsonData) else {
            // Fallback: create a basic post from the raw content
            logger.warning("Failed to parse structured response, using raw content")
            return SocialMediaPost(
                type: type,
                title: extractTitle(from: content),
                description: content,
                price: price,
                location: location,
                hashtags: extractHashtags(from: content),
                createdAt: Date()
            )
        }
        
        return SocialMediaPost(
            type: type,
            title: postResponse.title,
            description: postResponse.description,
            price: price,
            location: location,
            hashtags: postResponse.hashtags,
            createdAt: Date()
        )
    }
    
    private func extractJSON(from content: String) -> String {
        // Remove markdown code blocks if present
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractTitle(from content: String) -> String {
        // Try to find a title-like line (short line, possibly bolded)
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 10 && trimmed.count < 80 && !trimmed.hasPrefix("#") {
                return trimmed.replacingOccurrences(of: "**", with: "")
            }
        }
        return "Vehicle Listing"
    }
    
    private func extractHashtags(from content: String) -> [String] {
        let hashtagPattern = #"#[\w]+"#
        let regex = try? NSRegularExpression(pattern: hashtagPattern, options: [])
        let nsString = content as NSString
        let matches = regex?.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length)) ?? []
        
        return matches.compactMap { match in
            if match.range.location != NSNotFound {
                return nsString.substring(with: match.range)
            }
            return nil
        }
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

