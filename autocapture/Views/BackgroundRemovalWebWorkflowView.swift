//
//  BackgroundRemovalWebWorkflowView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/25/25.
//

import PhotosUI
import SwiftUI
import UIKit
import WebKit

struct BackgroundRemovalWebWorkflowView: View {
    @Environment(\.dismiss)
    private var dismiss

    @StateObject private var webController = BackgroundRemovalWebInterfaceController()
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundRemovalWebView(webController: webController)
                    .ignoresSafeArea(.container, edges: .bottom)

                if webController.isLoading {
                    ProgressView("Loading web workspace…")
                        .progressViewStyle(.circular)
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                if isImporting {
                    VStack(spacing: 12) {
                        ProgressView("Preparing images…")
                            .progressViewStyle(.circular)
                        Text("Optimizing files for the WebGPU background remover.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(radius: 12)
                }
            }
            .navigationTitle("Web Background Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Import Photos", systemImage: "photo.on.rectangle")
                    }
                    .disabled(isImporting || webController.isLoading)

                    Button {
                        webController.reloadInterface()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .disabled(webController.isLoading)
                }
            }
            .task {
                await webController.loadInterfaceIfNeeded()
            }
            .onChange(of: selectedItems) { _, newValue in
                guard newValue.isEmpty == false else { return }
                Task { await importSelected(items: newValue) }
            }
            .onChange(of: webController.errorMessage) { _, newValue in
                importErrorMessage = newValue
                showImportError = newValue != nil
            }
            .alert("Web Workspace Error", isPresented: $showImportError) {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            } message: {
                Text(importErrorMessage ?? "An unknown error occurred while loading the interface.")
            }
        }
    }

    private func importSelected(items: [PhotosPickerItem]) async {
        await MainActor.run { isImporting = true }
        defer { Task { await MainActor.run { isImporting = false } } }

        var prepared: [BackgroundRemovalWebInterfaceController.ImagePayload] = []
        for (index, item) in items.enumerated() {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let (payload, fallbackMessage) = await preparePayload(from: data, index: index)
                    if let payload {
                        prepared.append(payload)
                    } else if let fallbackMessage {
                        await presentError(fallbackMessage)
                    }
                }
            } catch {
                await presentError("Failed to access one of the selected images. \(error.localizedDescription)")
            }
        }

        guard prepared.isEmpty == false else { return }
        await webController.enqueueImages(prepared)
        await MainActor.run { selectedItems.removeAll() }
    }

    private func preparePayload(from data: Data, index: Int) async -> (BackgroundRemovalWebInterfaceController.ImagePayload?, String?) {
        guard let image = UIImage(data: data) else {
            return (nil, "One of the selected files is not a supported image format.")
        }

        guard let pngData = await MainActor.run(body: { image.pngData() }) else {
            return (nil, "Unable to convert an image to PNG for processing.")
        }

        let base64 = pngData.base64EncodedString()
        let name = "AutoCapture-\(index + 1).png"
        let payload = BackgroundRemovalWebInterfaceController.ImagePayload(
            name: name,
            dataUrl: "data:image/png;base64,\(base64)"
        )
        return (payload, nil)
    }

    @MainActor
    private func presentError(_ message: String) async {
        importErrorMessage = message
        showImportError = true
    }
}

private struct BackgroundRemovalWebView: UIViewRepresentable {
    @ObservedObject var webController: BackgroundRemovalWebInterfaceController

    func makeUIView(context: Context) -> WKWebView {
        webController.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

@MainActor
final class BackgroundRemovalWebInterfaceController: NSObject, ObservableObject, WKNavigationDelegate {
    struct ImagePayload: Codable {
        let name: String
        let dataUrl: String
    }

    @Published var isLoading = true
    @Published var errorMessage: String?

    let webView: WKWebView

    private var hasLoaded = false
    private var pendingPayloads: [[ImagePayload]] = []

    private static let interfaceURL = URL(string: "https://jcollins5513.github.io/bg-remover/")
    private static let bridgeScriptSource = #"""
(function () {
  function log(message, context) {
    if (typeof console !== "undefined" && console.debug) {
      console.debug(`[AutoCaptureBridge] ${message}`, context ?? "");
    }
  }

  async function createFileFromDataUrl(entry) {
    try {
      const response = await fetch(entry.dataUrl);
      const blob = await response.blob();
      const filename = entry.name || `autocapture-${crypto.randomUUID()}.png`;
      const type = blob.type || entry.mimeType || "image/png";
      return new File([blob], filename, { type });
    } catch (error) {
      console.error("[AutoCaptureBridge] Failed to create file", error);
      throw error;
    }
  }

  async function attachFilesToInput(entries) {
    const input = document.querySelector('input[type="file"]');
    if (!input) {
      log("File input not found");
      return;
    }

    const dataTransfer = new DataTransfer();
    for (const entry of entries) {
      try {
        const file = await createFileFromDataUrl(entry);
        dataTransfer.items.add(file);
      } catch (error) {
        console.error("[AutoCaptureBridge] Unable to add file", error);
      }
    }

    const descriptor = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      "files"
    );

    if (descriptor && descriptor.set) {
      descriptor.set.call(input, dataTransfer.files);
    } else {
      input.files = dataTransfer.files;
    }

    input.dispatchEvent(new Event("change", { bubbles: true }));
  }

  window.autoCaptureLoadImages = async function (entries) {
    if (!Array.isArray(entries) || entries.length === 0) {
      return;
    }

    await attachFilesToInput(entries);
  };
})();
"""#

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        let bridgeScript = WKUserScript(
            source: Self.bridgeScriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )

        controller.addUserScript(bridgeScript)
        configuration.userContentController = controller

        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
    }

    func loadInterfaceIfNeeded() async {
        guard hasLoaded == false else { return }
        loadInterface()
    }

    func loadInterface() {
        guard let url = Self.interfaceURL else {
            errorMessage = "Unable to resolve the background remover workspace URL."
            return
        }

        isLoading = true
        hasLoaded = true
        errorMessage = nil
        webView.load(URLRequest(url: url))
    }

    func reloadInterface() {
        webView.stopLoading()
        hasLoaded = false
        pendingPayloads.removeAll()
        loadInterface()
    }

    func enqueueImages(_ images: [ImagePayload]) async {
        guard images.isEmpty == false else { return }
        if isLoading {
            pendingPayloads.append(images)
            return
        }

        await inject(images: images)
    }

    private func inject(images: [ImagePayload]) async {
        guard let jsonData = try? JSONEncoder().encode(images),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let script = "window.autoCaptureLoadImages(\(jsonString));"
        do {
            _ = try await webView.callAsyncJavaScript(script)
        } catch {
            errorMessage = "Failed to send images to the web workspace. \(error.localizedDescription)"
        }
    }

    private func flushPending() {
        guard pendingPayloads.isEmpty == false else { return }
        let payloads = pendingPayloads
        pendingPayloads.removeAll()
        for payload in payloads {
            Task { await inject(images: payload) }
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        flushPending()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasLoaded = false
        errorMessage = error.localizedDescription
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        hasLoaded = false
        errorMessage = error.localizedDescription
    }
}
