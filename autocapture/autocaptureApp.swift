//
//  autocaptureApp.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftUI
import SwiftData

@main
struct autocaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ProcessedImage.self)
    }
}
