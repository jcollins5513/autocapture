//
//  DocumentPickerView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    enum PickerError: Error {
        case importFailed
    }

    typealias UIViewControllerType = UIDocumentPickerViewController

    let completion: (Result<UIImage?, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .png, .jpeg, .heic, .heif, .svg]
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<UIImage?, Error>) -> Void

        init(completion: @escaping (Result<UIImage?, Error>) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                completion(.failure(PickerError.importFailed))
                return
            }

            do {
                let data = try Data(contentsOf: url)
                if url.pathExtension.lowercased() == "svg" {
                    Task { @MainActor in
                        do {
                            let renderer = SVGSnapshotRenderer()
                            let image = try await renderer.render(from: data)
                            completion(.success(image))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                    return
                } else if let image = UIImage(data: data) {
                    completion(.success(image))
                } else {
                    completion(.failure(PickerError.importFailed))
                }
            } catch {
                completion(.failure(error))
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(.success(nil))
        }
    }
}
