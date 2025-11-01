//
//  PostGenerationView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/18/25.
//

import SwiftUI

struct PostGenerationView: View {
    @StateObject private var viewModel = PostGenerationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    let composition: CompositionProject?
    let session: CaptureSession?
    
    @State private var showShareSheet = false
    @State private var shareText: String = ""
    
    init(composition: CompositionProject? = nil, session: CaptureSession? = nil) {
        self.composition = composition
        self.session = session
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let post = viewModel.generatedPost {
                        generatedPostSection(post: post)
                    } else {
                        postGenerationForm
                    }
                }
                .padding()
            }
            .navigationTitle("Generate Social Media Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if viewModel.generatedPost != nil {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("New Post") {
                            viewModel.reset()
                        }
                        Button("Share") {
                            sharePost()
                        }
                    }
                }
            }
            .onAppear {
                loadInitialData()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityView(activityItems: [shareText])
            }
        }
    }
    
    private var postGenerationForm: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Post Type Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Post Type")
                    .font(.headline)
                
                Picker("Post Type", selection: $viewModel.selectedPostType) {
                    ForEach(PostType.allCases) { type in
                        Label(type.displayName, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Vehicle Information
            VStack(alignment: .leading, spacing: 12) {
                Text("Vehicle Information")
                    .font(.headline)
                
                TextField("Stock Number", text: $viewModel.stockNumber)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Vehicle Details (optional)", text: $viewModel.vehicleInfo, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            }
            
            // Price and Location (for marketplace)
            if viewModel.selectedPostType == .marketplace {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Include Price", isOn: $viewModel.includePrice)
                    
                    if viewModel.includePrice {
                        TextField("Price", text: $viewModel.price)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                    }
                    
                    TextField("Location (optional)", text: $viewModel.location)
                        .textFieldStyle(.roundedBorder)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Include Price", isOn: $viewModel.includePrice)
                    
                    if viewModel.includePrice {
                        TextField("Price", text: $viewModel.price)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.headline)
                
                Picker("Category", selection: $viewModel.category) {
                    ForEach(BackgroundCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Generate Button
            Button {
                Task {
                    await viewModel.generatePost()
                }
            } label: {
                HStack {
                    if viewModel.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.isGenerating ? "Generating..." : "Generate Post")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isGenerating || viewModel.stockNumber.isEmpty)
        }
    }
    
    private func generatedPostSection(post: SocialMediaPost) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Post Preview
            VStack(alignment: .leading, spacing: 16) {
                Text("Generated Post")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(post.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Divider()
                    
                    // Description
                    Text(post.description)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Price if available
                    if let price = post.price {
                        Divider()
                        Text("Price: \(price)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    // Location if available
                    if let location = post.location {
                        Text("Location: \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Hashtags
                    if !post.hashtags.isEmpty {
                        Divider()
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(post.hashtags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                Button {
                    sharePost()
                } label: {
                    Label("Share Post", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private func loadInitialData() {
        if let session = session {
            viewModel.stockNumber = session.stockNumber
            if let primaryCategory = session.primaryCategory {
                viewModel.category = primaryCategory
            }
            // Try to get vehicle info from first image
            if let firstImage = session.images.first, !firstImage.subjectDescription.isEmpty {
                viewModel.vehicleInfo = firstImage.subjectDescription
            }
        } else if let composition = composition {
            // Extract info from composition
            if let session = composition.session {
                viewModel.stockNumber = session.stockNumber
                if let primaryCategory = session.primaryCategory {
                    viewModel.category = primaryCategory
                }
                if let firstImage = session.images.first, !firstImage.subjectDescription.isEmpty {
                    viewModel.vehicleInfo = firstImage.subjectDescription
                }
            } else {
                // Extract from composition name if available
                let nameParts = composition.name.components(separatedBy: " - ")
                if nameParts.count >= 2 {
                    viewModel.vehicleInfo = nameParts[0]
                    viewModel.stockNumber = nameParts[1]
                } else {
                    viewModel.stockNumber = composition.name
                }
            }
            
            // Try to get vehicle info from layers
            if viewModel.vehicleInfo.isEmpty {
                if let subjectLayer = composition.layers.first(where: { $0.type == .subject }),
                   !subjectLayer.name.isEmpty {
                    viewModel.vehicleInfo = subjectLayer.name
                }
            }
        }
    }
    
    private func sharePost() {
        guard let post = viewModel.generatedPost else { return }
        
        var shareText = "\(post.title)\n\n\(post.description)\n"
        
        if let price = post.price {
            shareText += "\nPrice: \(price)\n"
        }
        
        if let location = post.location {
            shareText += "Location: \(location)\n"
        }
        
        if !post.hashtags.isEmpty {
            shareText += "\n\(post.hashtags.joined(separator: " "))"
        }
        
        self.shareText = shareText
        showShareSheet = true
    }
    
    private func copyToClipboard() {
        guard let post = viewModel.generatedPost else { return }
        
        var clipboardText = "\(post.title)\n\n\(post.description)\n"
        
        if let price = post.price {
            clipboardText += "\nPrice: \(price)\n"
        }
        
        if let location = post.location {
            clipboardText += "Location: \(location)\n"
        }
        
        if !post.hashtags.isEmpty {
            clipboardText += "\n\(post.hashtags.joined(separator: " "))"
        }
        
        UIPasteboard.general.string = clipboardText
    }
}

