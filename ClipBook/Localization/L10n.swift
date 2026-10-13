import Foundation

enum L10n {
    private static let fallbackLanguage = "en"
    private static var currentLanguage = fallbackLanguage

    static var languageIdentifier: String {
        currentLanguage
    }

    static var currentLocale: Locale {
        Locale(identifier: currentLanguage)
    }

    static func setLanguage(_ language: String) {
        currentLanguage = normalizedLanguage(language)
    }

    static func string(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        let format = String(localized: key, bundle: bundle(for: currentLanguage))
        guard !arguments.isEmpty else {
            return format
        }

        return String(
            format: format,
            locale: currentLocale,
            arguments: arguments
        )
    }

    static func string(forKey key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(forKey: key)
        guard !arguments.isEmpty else {
            return format
        }

        return String(
            format: format,
            locale: currentLocale,
            arguments: arguments
        )
    }

    private static func localizedString(forKey key: String) -> String {
        let value = bundle(for: currentLanguage).localizedString(forKey: key, value: nil, table: nil)
        if value != key || currentLanguage == fallbackLanguage {
            return value
        }

        return bundle(for: fallbackLanguage).localizedString(forKey: key, value: key, table: nil)
    }

    private static func normalizedLanguage(_ language: String) -> String {
        switch language {
        case "en", "en-GB", "de", "it", "pt-BR", "es", "ja", "zh-Hans":
            return language
        default:
            return fallbackLanguage
        }
    }

    private static func bundle(for language: String) -> Bundle {
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let baseLanguage = language.split(separator: "-").first,
           let path = Bundle.main.path(forResource: String(baseLanguage), ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return Bundle.main
    }
}
