//
//  BatchManagerViewModel.swift
//  AutoCapture
//
//  Created by OpenAI Assistant on 10/15/25.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class BatchManagerViewModel: ObservableObject {
    @Published var stockNumber: String = ""
    @Published var title: String = ""
    @Published var notes: String = ""
    @Published var selectedCategories: Set<BackgroundCategory> = [.automotive]
    @Published var errorMessage: String?
    @Published var showError = false

    @discardableResult
    func createSession(with context: ModelContext) -> CaptureSession? {
        let trimmedStockNumber = stockNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedStockNumber.isEmpty == false else {
            errorMessage = "Stock number is required."
            showError = true
            return nil
        }

        let categories = selectedCategories.isEmpty ? [.custom] : Array(selectedCategories)
        let session = CaptureSession(
            stockNumber: trimmedStockNumber,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title,
            notes: notes,
            categories: categories
        )
        session.status = .capturing

        context.insert(session)

        do {
            try context.save()
            resetFormState()
            return session
        } catch {
            context.delete(session)
            errorMessage = "Failed to create session: \(error.localizedDescription)"
            showError = true
            return nil
        }
    }

    private func resetFormState() {
        stockNumber = ""
        title = ""
        notes = ""
        selectedCategories = [.automotive]
    }
}
