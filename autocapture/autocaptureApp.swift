//
//  AutoCaptureApp.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import CoreData
import SwiftData
import SwiftUI

@main
struct AutoCaptureApp: App {
    static let sharedModelContainer: ModelContainer = makeModelContainer()

    private static func makeModelContainer() -> ModelContainer {
        let currentStoreName = "AutoCapture_v2.store"
        let legacyStoreNames = [
            "AutoCapture.store"
        ]

        let schema = Schema(
            [
                ProcessedImage.self,
                CaptureSession.self,
                GeneratedBackground.self,
                CompositionProject.self,
                CompositionLayer.self
            ]
        )

        let supportDirectory: URL
        do {
            supportDirectory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            fatalError("Unable to locate application support directory: \(error.localizedDescription)")
        }

        legacyStoreNames.forEach { resetStoreFiles(in: supportDirectory, baseName: $0) }

        let storeURL = supportDirectory.appending(path: currentStoreName)
        let configuration = ModelConfiguration(url: storeURL, allowsSave: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            if shouldResetStore(for: error) {
                do {
                    resetStoreFiles(in: supportDirectory, baseName: "AutoCapture.store")
                    resetStoreFiles(in: supportDirectory, baseName: "AutoCapture_v2.store")

                    return try ModelContainer(for: schema, configurations: [configuration])
                } catch {
                    fatalError("Failed to reset persistent store: \(error.localizedDescription)")
                }
            }
            fatalError("Failed to set up model container: \(error.localizedDescription)")
        }
    }

    private static func shouldResetStore(for error: Error) -> Bool {
        let nsError = error as NSError
        let migrationCodes = Set(
            [
                NSPersistentStoreIncompatibleVersionHashError,
                NSMigrationMissingSourceModelError,
                NSMigrationError,
                NSPersistentStoreIncompatibleSchemaError,
                134_110
            ]
        )
        return nsError.domain == NSCocoaErrorDomain && migrationCodes.contains(nsError.code)
    }

    private static func resetStoreFiles(in directory: URL, baseName: String) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in contents where file.lastPathComponent.hasPrefix(baseName) {
            try? fileManager.removeItem(at: file)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
