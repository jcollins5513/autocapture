//
//  BackgroundPromptBuilder.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/16/25.
//

import Foundation

struct BackgroundPromptBuilder {
    func prompt(for category: BackgroundCategory, customSubject: String) -> String {
        let components = category.defaultPromptComponents
        let trimmed = customSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        return components.renderPrompt(with: trimmed.isEmpty ? nil : trimmed)
    }
}
