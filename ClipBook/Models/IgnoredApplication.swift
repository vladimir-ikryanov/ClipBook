import AppKit
import Foundation

/// An application bundle added to the ignore list, with what is needed to
/// find the history items that were copied from it.
struct IgnoredApplication {
    let path: String
    let name: String
    let bundleIdentifier: String?
    private let normalizedNames: Set<String>

    init(path: String) {
        self.path = path
        let url = URL(fileURLWithPath: path)
        let bundle = Bundle(url: url)
        bundleIdentifier = bundle?.bundleIdentifier

        // Items record the running app's localized name, which can be any of
        // these depending on how the bundle is set up.
        let fileName = url.deletingPathExtension().lastPathComponent
        let infoNames = ["CFBundleDisplayName", "CFBundleName"].flatMap { key in
            [bundle?.localizedInfoDictionary?[key], bundle?.infoDictionary?[key]].compactMap { $0 as? String }
        }
        let candidateNames = infoNames + [FileManager.default.displayName(atPath: path), fileName]
        name = infoNames.first ?? fileName
        normalizedNames = Set(candidateNames.map(Self.normalized))
    }

    func matches(_ item: ClipboardItem) -> Bool {
        if let bundleIdentifier, let itemBundleIdentifier = item.sourceBundleIdentifier {
            return bundleIdentifier == itemBundleIdentifier
        }
        guard let sourceAppName = item.sourceAppName else {
            return false
        }
        return normalizedNames.contains(Self.normalized(sourceAppName))
    }

    nonisolated private static func normalized(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
