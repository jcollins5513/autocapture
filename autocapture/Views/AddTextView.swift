//
//  AddTextView.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/17/25.
//

import SwiftUI

struct AddTextView: View {
    @Environment(\.dismiss)
    private var dismiss

    @State private var textContent: String = ""
    @State private var fontSize: Double = 48.0
    @State private var selectedColor: Color = .black

    let onAdd: (String, Double, String) -> Void

    var body: some View {
        Form {
            Section("Text Content") {
                TextField("Enter text", text: $textContent)
            }

            Section("Font Size") {
                VStack(alignment: .leading) {
                    Slider(value: $fontSize, in: 12...120, step: 4)
                    Text("\(Int(fontSize))pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Color") {
                ColorPicker("Text Color", selection: $selectedColor)
            }

            Section {
                Button {
                    let hexColor = hexString(from: selectedColor)
                    onAdd(textContent, fontSize, hexColor)
                } label: {
                    Text("Add Text")
                        .frame(maxWidth: .infinity)
                }
                .disabled(textContent.isEmpty)
            }
        }
        .navigationTitle("Add Text")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let redValue = Int(red * 255)
        let greenValue = Int(green * 255)
        let blueValue = Int(blue * 255)

        return String(format: "#%02X%02X%02X", redValue, greenValue, blueValue)
    }
}

#Preview {
    NavigationStack {
        AddTextView { _, _, _ in }
    }
}
