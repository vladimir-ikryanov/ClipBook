import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

final class PreferencesStore {
    static let kernelBootTimeKey = "ClipBookLastKnownKernelBootTime"
    static let legacyUptimeBootTimeKey = "ClipBookLastKnownBootTime"

    let userDefaults: UserDefaults
    private let key = "ClipBookPreferencesV2"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> AppPreferences {
        guard let data = userDefaults.data(forKey: key),
              let preferences = try? decoder.decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return preferences
    }

    func save(_ preferences: AppPreferences) {
        if let data = try? encoder.encode(preferences) {
            userDefaults.set(data, forKey: key)
        }
    }

    func lastKnownKernelBootTime() -> Double? {
        userDefaults.object(forKey: Self.kernelBootTimeKey) as? Double
    }

    /// The boot time earlier builds stored, estimated as `Date() - systemUptime`.
    /// Uptime pauses while the Mac sleeps, so the estimate is never earlier than
    /// the real boot time.
    func lastKnownUptimeRelativeBootTime() -> Double? {
        userDefaults.object(forKey: Self.legacyUptimeBootTimeKey) as? Double
    }

    func recordBootTimes(kernelBootTime: TimeInterval, uptimeRelativeBootTime: TimeInterval) {
        userDefaults.set(kernelBootTime, forKey: Self.kernelBootTimeKey)
        userDefaults.set(uptimeRelativeBootTime, forKey: Self.legacyUptimeBootTimeKey)
    }
}
