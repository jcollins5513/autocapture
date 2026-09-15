//
//  GalleryView.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftData
import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    @Query(sort: \ProcessedImage.captureDate, order: .reverse)
    private var images: [ProcessedImage]
    @Query(sort: \ProcessedVideo.captureDate, order: .reverse)
    private var videos: [ProcessedVideo]

    @State private var selectedImage: ProcessedImage?
    @State private var selectedVideo: ProcessedVideo?
    @State private var selectedTab: MediaTab = .photos
    @State private var gridItemSize: CGFloat = 0

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private enum MediaTab: String, CaseIterable, Identifiable {
        case photos
        case videos

        var id: String { rawValue }
        var title: String { self == .photos ? "Photos" : "Videos" }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Media", selection: $selectedTab) {
                    ForEach(MediaTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                Group {
                    switch selectedTab {
                    case .photos:
                        photoContent
                    case .videos:
                        videoContent
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedImage) { image in
                ImageDetailView(image: image)
            }
            .sheet(item: $selectedVideo) { video in
                VideoDetailView(video: video)
            }
        }
    }

    @ViewBuilder private var photoContent: some View {
        if images.isEmpty {
            ContentUnavailableView(
                "No Photos",
                systemImage: "photo.on.rectangle.angled",
                description: Text("Capture photos to see them here")
            )
        } else {
            GeometryReader { geometry in
                ScrollView {
                    grid(for: geometry.size.width)
                }
            }
        }
    }

    @ViewBuilder private var videoContent: some View {
        if videos.isEmpty {
            ContentUnavailableView(
                "No Videos",
                systemImage: "video.badge.plus",
                description: Text("Record in Video mode to see clips here")
            )
        } else {
            GeometryReader { geometry in
                ScrollView {
                    videoGrid(for: geometry.size.width)
                }
            }
        }
    }

    @ViewBuilder
    private func videoGrid(for width: CGFloat) -> some View {
        let size = calculateGridItemSize(from: width)

        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(videos) { video in
                Button {
                    selectedVideo = video
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        if let thumbnail = video.thumbnail {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: max(size, 1), height: max(size, 1))
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: max(size, 1), height: max(size, 1))
                                .overlay(Image(systemName: "video"))
                        }

                        Text(video.formattedDuration)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .padding(4)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }

    private func calculateGridItemSize(from width: CGFloat) -> CGFloat {
        (width - 4) / 3
    }

    @ViewBuilder
    private func grid(for width: CGFloat) -> some View {
        let size = gridItemSize > 0 ? gridItemSize : calculateGridItemSize(from: width)

        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(images) { image in
                if let uiImage = image.image {
                    Button {
                        selectedImage = image
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: max(size, 1), height: max(size, 1))
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .onAppear {
            gridItemSize = size
        }
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: [ProcessedImage.self, ProcessedVideo.self], inMemory: true)
}
