//
//  VideoDetailView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import AVKit
import SwiftData
import SwiftUI

struct VideoDetailView: View {
    @Environment(\.dismiss)
    private var dismiss
    @Environment(\.modelContext)
    private var modelContext
    let video: ProcessedVideo

    @State private var player: AVPlayer?
    @State private var showingOriginal = false
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            detailLayout
        }
    }

    private var detailLayout: some View {
        ZStack {
            // A checkerboard reads as "transparent" the way it does in the
            // still editor, so lifted clips are obviously cut out.
            TransparencyCheckerboard()
                .ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ContentUnavailableView(
                    "Video Unavailable",
                    systemImage: "video.slash",
                    description: Text("The media for this clip is missing.")
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if video.originalURL != nil, video.isSubjectLifted {
                    Button {
                        showingOriginal.toggle()
                        loadPlayer()
                    } label: {
                        Image(systemName: showingOriginal ? "person.crop.square" : "square.dashed")
                    }
                }

                Button {
                    showShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    deleteVideo()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            metadataBar
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [currentURL].compactMap { $0 })
        }
        .onAppear { loadPlayer() }
        .onDisappear { player?.pause() }
    }

    private var metadataBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(showingOriginal ? "Original recording" : liftedLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("\(video.formattedDuration) · \(video.captureDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if video.isSubjectLifted, video.hasAlphaChannel == false, showingOriginal == false {
                Text("Transparency was unavailable on this device, so the subject was rendered on black.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
    }

    private var liftedLabel: String {
        video.isSubjectLifted ? "Lifted subject · \(video.captureMode.displayName)" : "Full scene"
    }

    private var currentURL: URL? {
        let url = showingOriginal ? (video.originalURL ?? video.processedURL) : video.processedURL
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func loadPlayer() {
        guard let url = currentURL else {
            player = nil
            return
        }
        let newPlayer = AVPlayer(url: url)
        newPlayer.actionAtItemEnd = .pause
        player = newPlayer
        newPlayer.play()
    }

    private func deleteVideo() {
        player?.pause()
        player = nil
        video.deleteMediaFiles()
        modelContext.delete(video)
        try? modelContext.save()
        dismiss()
    }
}

/// Simple two-tone grid used as the backdrop for transparent clips.
struct TransparencyCheckerboard: View {
    var squareSize: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.16)))

            for row in 0..<max(rows, 1) {
                for column in 0..<max(columns, 1) where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(Color(white: 0.24)))
                }
            }
        }
    }
}
