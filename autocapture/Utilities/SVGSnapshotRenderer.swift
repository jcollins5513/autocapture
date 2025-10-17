//
//  SVGSnapshotRenderer.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import UIKit
import WebKit

@MainActor
final class SVGSnapshotRenderer: NSObject, WKNavigationDelegate {
    private enum SnapshotError: Error {
        case snapshotFailed
    }

    private let webView: WKWebView
    private var continuation: CheckedContinuation<Void, Error>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        self.webView = WKWebView(
            frame: CGRect(origin: .zero, size: CGSize(width: 1_024, height: 1_024)),
            configuration: configuration
        )
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
    }

    func render(from data: Data, size: CGSize = CGSize(width: 1_024, height: 1_024)) async throws -> UIImage {
        continuation?.resume()
        continuation = nil

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        _ = webView.load(data, mimeType: "image/svg+xml", characterEncodingName: "utf-8", baseURL: baseURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
        }

        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        configuration.afterScreenUpdates = true

        return try await withCheckedThrowingContinuation { (snapshotContinuation: CheckedContinuation<UIImage, Error>) in
            webView.takeSnapshot(with: configuration) { image, error in
                if let image {
                    snapshotContinuation.resume(returning: image)
                } else {
                    snapshotContinuation.resume(throwing: error ?? SnapshotError.snapshotFailed)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume(returning: ())
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
