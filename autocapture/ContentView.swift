//
//  ContentView.swift
//  AutoCapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        BatchManagerView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [CaptureSession.self, ProcessedImage.self, GeneratedBackground.self, CompositionProject.self, CompositionLayer.self], inMemory: true)
}
