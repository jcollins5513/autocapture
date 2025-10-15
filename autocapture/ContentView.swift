//
//  ContentView.swift
//  autocapture
//
//  Created by Justin Collins on 10/14/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        CameraView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ProcessedImage.self, inMemory: true)
}
