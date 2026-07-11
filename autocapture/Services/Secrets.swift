//
//  Secrets.swift
//  AutoCapture
//

import Foundation

/// Reads local secrets (such as the OpenAI API key) from a gitignored
/// `Secrets.plist` bundled with the app, falling back to environment variables
/// so a run scheme or CI environment can still supply them.
///
/// To set up locally: copy `Secrets.example.plist` (repo root) to
/// `autocapture/Secrets.plist` and fill in your values. That file is
/// gitignored, so it never gets committed.
enum Secrets {
    private static let values: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
            let dictionary = plist as? [String: Any]
        else {
            return [:]
        }

        return dictionary.reduce(into: [String: String]()) { result, entry in
            if let string = entry.value as? String, string.isEmpty == false {
                result[entry.key] = string
            }
        }
    }()

    /// Returns the value for `key` from `Secrets.plist`, or the matching
    /// environment variable if the plist doesn't provide it.
    static func value(for key: String) -> String? {
        if let value = values[key] {
            return value
        }
        if let environment = ProcessInfo.processInfo.environment[key], environment.isEmpty == false {
            return environment
        }
        return nil
    }
}
