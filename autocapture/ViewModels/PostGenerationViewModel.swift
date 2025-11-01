//
//  PostGenerationViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import Foundation
import OSLog
import SwiftUI
import Combine

@MainActor
final class PostGenerationViewModel: ObservableObject {
    @Published var selectedPostType: PostType = .facebook
    @Published var vehicleInfo: String = ""
    @Published var stockNumber: String = ""
    @Published var includePrice = false
    @Published var price: String = ""
    @Published var location: String = ""
    @Published var category: BackgroundCategory = .automotive
    
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    @Published var generatedPost: SocialMediaPost?
    
    private let postService: SocialMediaPostService
    private let logger = Logger(subsystem: "com.autocapture", category: "PostGenerationViewModel")
    
    init(postService: SocialMediaPostService? = nil) {
        self.postService = postService ?? SocialMediaPostService()
    }
    
    func generatePost() async {
        guard !stockNumber.isEmpty else {
            errorMessage = "Stock number is required"
            showError = true
            return
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let post = try await postService.generatePost(
                type: selectedPostType,
                vehicleInfo: vehicleInfo.isEmpty ? "Vehicle listing" : vehicleInfo,
                stockNumber: stockNumber,
                category: category,
                includePrice: includePrice && !price.isEmpty,
                price: price.isEmpty ? nil : price,
                location: location.isEmpty ? nil : location
            )
            
            generatedPost = post
            logger.info("Post generated successfully: \(post.type.displayName)")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            logger.error("Post generation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func reset() {
        generatedPost = nil
        selectedPostType = .facebook
        includePrice = false
        price = ""
        location = ""
        errorMessage = nil
    }
}

