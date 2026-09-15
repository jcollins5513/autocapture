//
//  CapturedVideoCard.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import SwiftUI

struct CapturedVideoCard: View {
    let video: ProcessedVideo
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                if let thumbnail = video.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 160)
                        .overlay(Image(systemName: "video").font(.title))
                }

                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                    Text(video.formattedDuration)
                }
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.black.opacity(0.55)))
                .padding(8)
            }

            Text(video.isSubjectLifted ? "Lifted · \(video.captureMode.displayName)" : "Full scene")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            VideoDetailView(video: video)
        }
    }
}
