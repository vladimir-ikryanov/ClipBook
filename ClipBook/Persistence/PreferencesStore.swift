import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

final class PreferencesStore {
    private let key = "ClipBookPreferencesV2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> AppPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let preferences = try? decoder.decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        if let data = try? encoder.encode(preferences) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
