import Foundation
import SwiftUI
import AppKit
import Carbon
import Combine
import SQLite3

enum HistoryStoreError: LocalizedError {
    case openFailed
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed

    var errorDescription: String? {
        switch self {
        case .openFailed: "Unable to open the ClipBook history database."
        case .prepareFailed(let message): "Unable to prepare the history database statement: \(message)"
        case .stepFailed(let message): "Unable to write to the history database: \(message)"
        case .bindFailed: "Unable to bind a history database value."
        }
    }
}
