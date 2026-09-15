//
//  MovieTransferable.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 9/15/26.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// PhotosPicker hands back a sandboxed file that disappears once the transfer
/// completes, so the movie is copied somewhere we control first.
struct MovieTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let destination = VideoFileStore.makeTemporaryURL(
                extension: received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            )
            try FileManager.default.copyItem(at: received.file, to: destination)
            return MovieTransferable(url: destination)
        }
    }
}
