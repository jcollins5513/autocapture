//
//  AutoCaptureApp.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftData
import SwiftUI

@main
struct AutoCaptureApp: App {
    static let sharedModelContainer: ModelContainer = {
        do {
            let schema = Schema([
                ProcessedImage.self,
                CaptureSession.self,
                GeneratedBackground.self,
                CompositionProject.self,
                CompositionLayer.self
            ])

            let supportDirectory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let storeURL = supportDirectory.appending(path: "AutoCapture.store")
            let configuration = ModelConfiguration(url: storeURL, allowsSave: true)

            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to set up model container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
