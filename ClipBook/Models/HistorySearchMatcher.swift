import Foundation
import os

/// The terms a search query looks for in each history item.
nonisolated struct HistorySearchTerms: Equatable, Sendable {
    struct ASCIITerm: Sendable {
        let lowercasedBytes: [UInt8]
        let containsDigit: Bool
    }

    let values: [String]
    let asciiTerms: [ASCIITerm?]

    init(query: String) {
        self.init(values: query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
    }

    init(values: [String]) {
        self.values = values
        self.asciiTerms = values.map { term in
            guard !term.isEmpty,
                  term.utf8.allSatisfy({ !($0 < 0x09 || ($0 > 0x0D && $0 < 0x20) || $0 == 0x7F || $0 >= 0x80) }) else {
                return nil
            }
            var lowered: [UInt8] = []
            lowered.reserveCapacity(term.utf8.count)
            var hasDigit = false
            for byte in term.utf8 {
                if byte >= 0x30 && byte <= 0x39 {
                    hasDigit = true
                }
                let lowerByte = (byte >= 0x41 && byte <= 0x5A) ? (byte | 0x20) : byte
                lowered.append(lowerByte)
            }
            return ASCIITerm(lowercasedBytes: lowered, containsDigit: hasDigit)
        }
    }

    var isEmpty: Bool {
        values.isEmpty
    }

    static func == (lhs: HistorySearchTerms, rhs: HistorySearchTerms) -> Bool {
        lhs.values == rhs.values
    }
}

/// Checks whether an item's search text contains every term of a search query.
nonisolated enum HistorySearchMatcher {
    static let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    private static let enUSLocale = Locale(identifier: "en_US")
    private static let asciiContractionDigraphs: [(digraph: String, prefix: String)] = [
        ("aa", "a"), ("ch", "c"), ("cs", "c"), ("dz", "d"), ("gy", "g"), ("lj", "l"),
        ("ll", "l"), ("ly", "l"), ("nj", "n"), ("ny", "n"), ("rr", "r"), ("sh", "s"),
        ("sz", "s"), ("th", "t"), ("ty", "t"), ("xh", "x"), ("zh", "z"), ("zs", "z")
    ]

    private struct FoldTables: Sendable {
        let digits: [UInt64]
        let letters: [UInt64]
    }

    // Bitmap lookup tables over all Unicode scalar values (0...0x10FFFF) for
    // scalars that Foundation's case- and diacritic-insensitive search can
    // equate with ASCII digits or ASCII letters/punctuation, or ignore inside
    // an ASCII match.
    private static let foldTables: FoldTables = {
        let wordCount = (0x110000 + 63) / 64
        var digits = [UInt64](repeating: 0, count: wordCount)
        var letters = [UInt64](repeating: 0, count: wordCount)

        let chunkWords = 64
        let chunkCount = (wordCount + chunkWords - 1) / chunkWords

        digits.withUnsafeMutableBufferPointer { digitsBuffer in
            letters.withUnsafeMutableBufferPointer { lettersBuffer in
                nonisolated(unsafe) let digitsPtr = digitsBuffer.baseAddress!
                nonisolated(unsafe) let lettersPtr = lettersBuffer.baseAddress!

                DispatchQueue.concurrentPerform(iterations: chunkCount) { chunk in
                    let startWord = chunk * chunkWords
                    let endWord = min(startWord + chunkWords, wordCount)
                    for wordIndex in startWord..<endWord {
                        var digitMask: UInt64 = 0
                        var letterMask: UInt64 = 0
                        let baseScalar = UInt32(wordIndex * 64)
                        for bit in 0..<64 {
                            let value = baseScalar + UInt32(bit)
                            guard value <= 0x10FFFF,
                                  let scalar = Unicode.Scalar(value) else {
                                continue
                            }
                            let properties = scalar.properties
                            if value >= 0x80, properties.numericType != nil {
                                digitMask |= (UInt64(1) << bit)
                            }
                            if Self.computesFoldsToASCIILetters(scalar, properties: properties) {
                                letterMask |= (UInt64(1) << bit)
                            }
                        }
                        digitsPtr[wordIndex] = digitMask
                        lettersPtr[wordIndex] = letterMask
                    }
                }
            }
        }

        return FoldTables(digits: digits, letters: letters)
    }()

    private static let localeAllowsPrefilterCache = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

    private static func computesFoldsToASCIILetters(
        _ scalar: Unicode.Scalar,
        properties: Unicode.Scalar.Properties
    ) -> Bool {
        let value = scalar.value
        if value < 0x80 {
            return value < 0x09 || (value > 0x0D && value < 0x20) || value == 0x7F
        }
        switch value {
        case 0x3400...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0x20000...0x3FFFF:
            return false
        default:
            break
        }

        let categoryAllowed: Bool
        switch properties.generalCategory {
        case .nonspacingMark, .enclosingMark, .spacingMark, .format, .control,
             .modifierLetter, .modifierSymbol, .otherLetter, .mathSymbol:
            categoryAllowed = true
        default:
            categoryAllowed = false
        }
        guard properties.isCased
            || properties.changesWhenNFKCCaseFolded
            || properties.isDefaultIgnorableCodePoint
            || categoryAllowed else {
            return false
        }

        if properties.lowercaseMapping.utf8.contains(where: { $0 < 0x80 })
            || properties.uppercaseMapping.utf8.contains(where: { $0 < 0x80 })
            || properties.titlecaseMapping.utf8.contains(where: { $0 < 0x80 }) {
            return true
        }
        let string = String(scalar)
        if string.folding(options: Self.compareOptions, locale: nil).utf8.contains(where: { $0 < 0x80 }) {
            return true
        }
        if properties.changesWhenNFKCCaseFolded
            && string.decomposedStringWithCompatibilityMapping.utf8.contains(where: { $0 < 0x80 }) {
            return true
        }
        if string.compare("a", options: Self.compareOptions, locale: enUSLocale) != .orderedAscending
            && string.compare("zzzzzzzz", options: Self.compareOptions, locale: enUSLocale) != .orderedDescending {
            return true
        }
        if "a\(scalar)b".range(of: "ab", options: Self.compareOptions, range: nil, locale: enUSLocale) != nil {
            return true
        }
        return false
    }

    static func warmUp() {
        _ = foldTables
    }

    static func foldsToASCIIDigits(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        guard value >= 0x80, value <= 0x10FFFF else {
            return false
        }
        let wordIndex = Int(value >> 6)
        let bit = UInt64(1) << (value & 63)
        return (foldTables.digits[wordIndex] & bit) != 0
    }

    static func foldsToASCIILetters(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        guard value <= 0x10FFFF else {
            return false
        }
        let wordIndex = Int(value >> 6)
        let bit = UInt64(1) << (value & 63)
        return (foldTables.letters[wordIndex] & bit) != 0
    }

    static func allowsASCIIPrefilter(for locale: Locale) -> Bool {
        let identifier = locale.identifier
        if let cached = localeAllowsPrefilterCache.withLock({ $0[identifier] }) {
            return cached
        }
        let allowed = "I".range(of: "i", options: Self.compareOptions, range: nil, locale: locale) != nil
            && "i".range(of: "I", options: Self.compareOptions, range: nil, locale: locale) != nil
            && asciiContractionDigraphs.allSatisfy { digraph, prefix in
                digraph.range(of: prefix, options: Self.compareOptions, range: nil, locale: locale) != nil
            }
        localeAllowsPrefilterCache.withLock { $0[identifier] = allowed }
        return allowed
    }

    @inline(__always)
    private static func asciiLower(_ byte: UInt8) -> UInt8 {
        (byte >= 0x41 && byte <= 0x5A) ? (byte | 0x20) : byte
    }

    @inline(__always)
    private static func isAllASCII(_ bytes: UnsafeBufferPointer<UInt8>) -> Bool {
        for byte in bytes where byte < 0x09 || (byte > 0x0D && byte < 0x20) || byte == 0x7F || byte >= 0x80 {
            return false
        }
        return true
    }

    @inline(__always)
    private static func containsASCIICaseInsensitive(
        haystack: UnsafeBufferPointer<UInt8>,
        needle: [UInt8]
    ) -> Bool {
        let haystackCount = haystack.count
        let needleCount = needle.count
        guard needleCount > 0, haystackCount >= needleCount else {
            return needleCount == 0
        }
        let first = needle[0]
        let lastStart = haystackCount - needleCount
        var index = 0
        while index <= lastStart {
            if asciiLower(haystack[index]) == first {
                var offset = 1
                while offset < needleCount && asciiLower(haystack[index + offset]) == needle[offset] {
                    offset += 1
                }
                if offset == needleCount {
                    return true
                }
            }
            index += 1
        }
        return false
    }

    static func matches(
        _ text: String,
        _ terms: HistorySearchTerms,
        locale: Locale = .current,
        allowsPrefilter: Bool? = nil
    ) -> Bool {
        let values = terms.values
        guard !values.isEmpty else {
            return true
        }

        let canUsePrefilter = allowsPrefilter ?? allowsASCIIPrefilter(for: locale)
        guard canUsePrefilter else {
            for term in values {
                if text.range(of: term, options: Self.compareOptions, range: nil, locale: locale) == nil {
                    return false
                }
            }
            return true
        }

        let original = text
        var contiguous = text
        return contiguous.withUTF8 { haystack in
            let asciiHaystack = isAllASCII(haystack)
            var scannedScalars = false
            var hasFoldLetters = false
            var hasFoldDigits = false

            let asciiTerms = terms.asciiTerms
            for index in values.indices {
                let term = values[index]
                guard let asciiTerm = asciiTerms[index] else {
                    if original.range(of: term, options: Self.compareOptions, range: nil, locale: locale) == nil {
                        return false
                    }
                    continue
                }

                let foundBytes = containsASCIICaseInsensitive(
                    haystack: haystack,
                    needle: asciiTerm.lowercasedBytes
                )
                if asciiHaystack {
                    if !foundBytes {
                        return false
                    }
                    continue
                }

                if !foundBytes {
                    // On non-ASCII text, Foundation switches to ICU collation search
                    // when a multi-character needle contains an ASCII digit, so only
                    // single-digit or digit-free ASCII needles can be rejected by the
                    // scalar fold tables alone.
                    if !(asciiTerm.containsDigit && asciiTerm.lowercasedBytes.count > 1) {
                        if !scannedScalars {
                            scannedScalars = true
                            let digitsTable = foldTables.digits
                            let lettersTable = foldTables.letters
                            for scalar in original.unicodeScalars {
                                let value = scalar.value
                                let wordIndex = Int(value >> 6)
                                let bit = UInt64(1) << (value & 63)
                                if (lettersTable[wordIndex] & bit) != 0 {
                                    hasFoldLetters = true
                                }
                                if (digitsTable[wordIndex] & bit) != 0 {
                                    hasFoldDigits = true
                                }
                                if hasFoldLetters && hasFoldDigits {
                                    break
                                }
                            }
                        }
                        let canFoldToTerm = hasFoldLetters || (asciiTerm.containsDigit && hasFoldDigits)
                        if !canFoldToTerm {
                            return false
                        }
                    }
                }

                if original.range(of: term, options: Self.compareOptions, range: nil, locale: locale) == nil {
                    return false
                }
            }
            return true
        }
    }
}
