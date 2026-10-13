import CryptoKit
import Foundation

enum ClipboardTextTransform: CaseIterable {
  case apTitleCase
  case addBullets
  case addLineNumbers
  case base64Decode
  case base64Encode
  case csvToLines
  case camelCase
  case lowerCase
  case upperCase
  case capitalizeWords
  case dotCase
  case doubleSpaceLines
  case escapeNewlines
  case escapeRegex
  case extractEmails
  case extractNumbers
  case extractURLs
  case htmlDecode
  case htmlEncode
  case hexDecode
  case hexEncode
  case generateUUID
  case indentLines
  case joinLines
  case kebabCase
  case linesToCSV
  case md5Hash
  case naturalSortLines
  case naturalSortLinesDescending
  case numberedList
  case pascalCase
  case quoteEachLine
  case removeAccents
  case removeAllSpacing
  case removeDuplicateLines
  case removeExtraSpaces
  case removeWhitespaces
  case reverseWords
  case reverseLines
  case reverseText
  case sha256Hash
  case screamingSnakeCase
  case sentenceCase
  case shuffleLines
  case slugify
  case smartQuotes
  case snakeCase
  case sortLines
  case sortLinesDescending
  case sortLinesByLength
  case sortLinesByLengthDescending
  case spacesToTabs
  case straightQuotes
  case stripHTMLTags
  case stripMarkdown
  case tabsToSpaces
  case titleCase
  case trimTrailingSpacesAllLines
  case trimLeadingWhitespaces
  case trimTrailingNewlines
  case trimTrailingSpaces
  case urlDecode
  case urlEncode
  case unescapeNewlines
  case unindentLines
  case wrapInBrackets
  case wrapInParentheses
  case wrapInQuotes
  case wrapInSingleQuotes
  case cleanTerminalCommand
  case normalizeWhitespace
  case removeLineBreaks
  case removeEmptyLines
  case trimSurroundingWhitespaces

  // Menus and the command palette both list the transforms in the order of
  // their names, in whichever language the app is running in.
  static var sortedCases: [ClipboardTextTransform] {
    allCases.sorted {
      $0.title.compare(
        $1.title,
        options: [.caseInsensitive, .diacriticInsensitive],
        range: nil,
        locale: L10n.currentLocale
      ) == .orderedAscending
    }
  }

  var title: String {
    switch self {
    case .apTitleCase:
      return L10n.string("AP Title Case")
    case .addBullets:
      return L10n.string("Add Bullets")
    case .addLineNumbers:
      return L10n.string("Add Line Numbers")
    case .base64Decode:
      return L10n.string("Base64 Decode")
    case .base64Encode:
      return L10n.string("Base64 Encode")
    case .csvToLines:
      return L10n.string("CSV to Lines")
    case .camelCase:
      return L10n.string("Camel Case")
    case .lowerCase:
      return L10n.string("Lowercase")
    case .upperCase:
      return L10n.string("Uppercase")
    case .capitalizeWords:
      return L10n.string("Capitalize words")
    case .dotCase:
      return L10n.string("Dot Case")
    case .doubleSpaceLines:
      return L10n.string("Double Space Lines")
    case .escapeNewlines:
      return L10n.string("Escape Newlines")
    case .escapeRegex:
      return L10n.string("Escape Regex")
    case .extractEmails:
      return L10n.string("Extract Emails")
    case .extractNumbers:
      return L10n.string("Extract Numbers")
    case .extractURLs:
      return L10n.string("Extract URLs")
    case .htmlDecode:
      return L10n.string("HTML Decode")
    case .htmlEncode:
      return L10n.string("HTML Encode")
    case .hexDecode:
      return L10n.string("Hex Decode")
    case .hexEncode:
      return L10n.string("Hex Encode")
    case .generateUUID:
      return L10n.string("Generate UUID")
    case .indentLines:
      return L10n.string("Indent Lines")
    case .joinLines:
      return L10n.string("Join Lines")
    case .kebabCase:
      return L10n.string("Kebab Case")
    case .linesToCSV:
      return L10n.string("Lines to CSV")
    case .md5Hash:
      return L10n.string("MD5 Hash")
    case .naturalSortLines:
      return L10n.string("Natural Sort Lines")
    case .naturalSortLinesDescending:
      return L10n.string("Natural Sort Lines (Z-A)")
    case .numberedList:
      return L10n.string("Numbered List")
    case .pascalCase:
      return L10n.string("Pascal Case")
    case .quoteEachLine:
      return L10n.string("Quote Each Line")
    case .removeAccents:
      return L10n.string("Remove Accents")
    case .removeAllSpacing:
      return L10n.string("Remove All Spacing")
    case .removeDuplicateLines:
      return L10n.string("Remove Duplicate Lines")
    case .removeExtraSpaces:
      return L10n.string("Remove Extra Spaces")
    case .removeWhitespaces:
      return L10n.string("Remove Whitespaces")
    case .reverseWords:
      return L10n.string("Reverse Words")
    case .reverseLines:
      return L10n.string("Reverse Lines")
    case .reverseText:
      return L10n.string("Reverse Text")
    case .sha256Hash:
      return L10n.string("SHA256 Hash")
    case .screamingSnakeCase:
      return L10n.string("Screaming Snake Case")
    case .sentenceCase:
      return L10n.string("Sentence Case")
    case .shuffleLines:
      return L10n.string("Shuffle Lines")
    case .slugify:
      return L10n.string("Slugify")
    case .smartQuotes:
      return L10n.string("Smart Quotes")
    case .snakeCase:
      return L10n.string("Snake Case")
    case .sortLines:
      return L10n.string("Sort Lines")
    case .sortLinesDescending:
      return L10n.string("Sort Lines (Z-A)")
    case .sortLinesByLength:
      return L10n.string("Sort Lines by Length")
    case .sortLinesByLengthDescending:
      return L10n.string("Sort Lines by Length (long first)")
    case .spacesToTabs:
      return L10n.string("Spaces to Tabs")
    case .straightQuotes:
      return L10n.string("Straight Quotes")
    case .stripHTMLTags:
      return L10n.string("Strip HTML Tags")
    case .stripMarkdown:
      return L10n.string("Strip Markdown")
    case .tabsToSpaces:
      return L10n.string("Tabs to Spaces")
    case .titleCase:
      return L10n.string("Title Case")
    case .trimTrailingSpacesAllLines:
      return L10n.string("Trim Trailing Spaces All Lines")
    case .trimLeadingWhitespaces:
      return L10n.string("Trim Leading Whitespaces")
    case .trimTrailingNewlines:
      return L10n.string("Trim Trailing Newlines")
    case .trimTrailingSpaces:
      return L10n.string("Trim Trailing Spaces")
    case .urlDecode:
      return L10n.string("URL Decode")
    case .urlEncode:
      return L10n.string("URL Encode")
    case .unescapeNewlines:
      return L10n.string("Unescape Newlines")
    case .unindentLines:
      return L10n.string("Unindent Lines")
    case .wrapInBrackets:
      return L10n.string("Wrap in Brackets")
    case .wrapInParentheses:
      return L10n.string("Wrap in Parentheses")
    case .wrapInQuotes:
      return L10n.string("Wrap in Quotes")
    case .wrapInSingleQuotes:
      return L10n.string("Wrap in Single Quotes")
    case .cleanTerminalCommand:
      return L10n.string("Clean Terminal Command")
    case .normalizeWhitespace:
      return L10n.string("Normalize Whitespace")
    case .removeLineBreaks:
      return L10n.string("Remove Line Breaks")
    case .removeEmptyLines:
      return L10n.string("Remove Empty Lines")
    case .trimSurroundingWhitespaces:
      return L10n.string("Trim Surrounding Whitespaces")
    }
  }

  var description: String {
    switch self {
    case .apTitleCase:
      return L10n.string("Title case with lowercase minor words (AP style).")
    case .addBullets:
      return L10n.string("Convert comma-separated or line-separated text to bullet points.")
    case .addLineNumbers:
      return L10n.string("Prefix each line with a number.")
    case .base64Decode:
      return L10n.string("Decode Base64 to text.")
    case .base64Encode:
      return L10n.string("Encode text to Base64.")
    case .csvToLines:
      return L10n.string("Convert comma separated to line separated.")
    case .camelCase:
      return L10n.string("Convert to camelCase.")
    case .lowerCase:
      return L10n.string("Convert all text to lowercase.")
    case .upperCase:
      return L10n.string("Convert all text to uppercase.")
    case .capitalizeWords:
      return L10n.string("Capitalize the first letter of each word.")
    case .dotCase:
      return L10n.string("Convert to dot.case.")
    case .doubleSpaceLines:
      return L10n.string("Add blank line between each line.")
    case .escapeNewlines:
      return L10n.string("Convert newlines to \\n literal.")
    case .escapeRegex:
      return L10n.string("Escape special regex characters.")
    case .extractEmails:
      return L10n.string("Extract all email addresses.")
    case .extractNumbers:
      return L10n.string("Extract all numbers from text.")
    case .extractURLs:
      return L10n.string("Extract all URLs from text.")
    case .htmlDecode:
      return L10n.string("Decode HTML entities to characters.")
    case .htmlEncode:
      return L10n.string("Encode special characters for HTML.")
    case .hexDecode:
      return L10n.string("Convert hexadecimal to text.")
    case .hexEncode:
      return L10n.string("Convert text to hexadecimal.")
    case .generateUUID:
      return L10n.string("Replace text with a new UUID.")
    case .indentLines:
      return L10n.string("Add 4 spaces to the start of each line.")
    case .joinLines:
      return L10n.string("Combine all lines with comma separator.")
    case .kebabCase:
      return L10n.string("Convert to kebab-case.")
    case .linesToCSV:
      return L10n.string("Convert line separated to comma separated.")
    case .md5Hash:
      return L10n.string("Generate MD5 hash of the text.")
    case .naturalSortLines:
      return L10n.string("Sort lines naturally (1, 2, 10 not 1, 10, 2).")
    case .naturalSortLinesDescending:
      return L10n.string("Sort lines naturally in reverse order.")
    case .numberedList:
      return L10n.string("Convert lines to numbered list.")
    case .pascalCase:
      return L10n.string("Convert to PascalCase.")
    case .quoteEachLine:
      return L10n.string("Wrap each line in double quotes.")
    case .removeAccents:
      return L10n.string("Convert accented characters to plain ASCII.")
    case .removeAllSpacing:
      return L10n.string("Collapse all whitespace including line breaks into single space.")
    case .removeDuplicateLines:
      return L10n.string("Keep only unique lines.")
    case .removeExtraSpaces:
      return L10n.string("Collapse multiple spaces into one, preserve line breaks.")
    case .removeWhitespaces:
      return L10n.string("Remove all spaces and whitespace characters.")
    case .reverseWords:
      return L10n.string("Reverse the order of words.")
    case .reverseLines:
      return L10n.string("Reverse the order of lines.")
    case .reverseText:
      return L10n.string("Reverse the entire text.")
    case .sha256Hash:
      return L10n.string("Generate SHA256 hash of the text.")
    case .screamingSnakeCase:
      return L10n.string("Convert to SCREAMING_SNAKE_CASE.")
    case .sentenceCase:
      return L10n.string("Capitalize the first letter of each sentence.")
    case .shuffleLines:
      return L10n.string("Randomize the order of lines.")
    case .slugify:
      return L10n.string("Convert to URL-friendly slug.")
    case .smartQuotes:
      return L10n.string("Convert straight quotes to curly quotes.")
    case .snakeCase:
      return L10n.string("Convert to snake_case.")
    case .sortLines:
      return L10n.string("Sort lines alphabetically.")
    case .sortLinesDescending:
      return L10n.string("Sort lines reverse alphabetically.")
    case .sortLinesByLength:
      return L10n.string("Sort lines from shortest to longest.")
    case .sortLinesByLengthDescending:
      return L10n.string("Sort lines from longest to shortest.")
    case .spacesToTabs:
      return L10n.string("Convert 4 spaces to tabs.")
    case .straightQuotes:
      return L10n.string("Convert smart typography to ASCII equivalents (quotes, dashes, ellipsis).")
    case .stripHTMLTags:
      return L10n.string("Remove all HTML markup.")
    case .stripMarkdown:
      return L10n.string("Remove Markdown formatting.")
    case .tabsToSpaces:
      return L10n.string("Convert tabs to 4 spaces.")
    case .titleCase:
      return L10n.string("Capitalize first letter of each word (proper title case).")
    case .trimTrailingSpacesAllLines:
      return L10n.string("Remove trailing spaces from every line.")
    case .trimLeadingWhitespaces:
      return L10n.string("Remove whitespace from start of each line.")
    case .trimTrailingNewlines:
      return L10n.string("Remove newlines from start and end.")
    case .trimTrailingSpaces:
      return L10n.string("Remove spaces from start and end of text.")
    case .urlDecode:
      return L10n.string("Decode URL-encoded text.")
    case .urlEncode:
      return L10n.string("Encode text for URLs.")
    case .unescapeNewlines:
      return L10n.string("Convert \\n literals to actual newlines.")
    case .unindentLines:
      return L10n.string("Remove leading spaces or tab from each line.")
    case .wrapInBrackets:
      return L10n.string("Surround text with square brackets.")
    case .wrapInParentheses:
      return L10n.string("Surround text with parentheses.")
    case .wrapInQuotes:
      return L10n.string("Surround text with double quotes.")
    case .wrapInSingleQuotes:
      return L10n.string("Surround text with single quotes.")
    case .cleanTerminalCommand:
      return L10n.string("Remove prompts and terminal formatting from commands.")
    case .normalizeWhitespace:
      return L10n.string("Collapse repeated whitespace into single spaces.")
    case .removeLineBreaks:
      return L10n.string("Join lines into a single line of text.")
    case .removeEmptyLines:
      return L10n.string("Collapse consecutive empty lines into one.")
    case .trimSurroundingWhitespaces:
      return L10n.string("Remove whitespace from the beginning and end.")
    }
  }

  func apply(to text: String) -> String {
    switch self {
    case .apTitleCase:
      return Self.apTitleCase(text)
    case .addBullets:
      return Self.listItems(from: text).map { "- \($0)" }.joined(separator: "\n")
    case .addLineNumbers:
      return Self.lines(in: text).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    case .base64Decode:
      return Self.base64Decoded(text)
    case .base64Encode:
      return Data(text.utf8).base64EncodedString()
    case .csvToLines:
      return Self.commaSeparatedItems(from: text).joined(separator: "\n")
    case .camelCase:
      return Self.camelCase(text)
    case .lowerCase:
      return text.localizedLowercase
    case .upperCase:
      return text.localizedUppercase
    case .capitalizeWords:
      return Self.words(in: text).map { Self.capitalizedWord($0) }.joined(separator: " ")
    case .dotCase:
      return Self.words(in: text).map { $0.localizedLowercase }.joined(separator: ".")
    case .doubleSpaceLines:
      return Self.lines(in: text).joined(separator: "\n\n")
    case .escapeNewlines:
      return text.replacingOccurrences(of: "\n", with: "\\n")
    case .escapeRegex:
      return Self.escapeRegex(text)
    case .extractEmails:
      return Self.matches(in: text, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, options: [.caseInsensitive])
        .joined(separator: "\n")
    case .extractNumbers:
      return Self.matches(in: text, pattern: #"-?(?:\d+(?:\.\d+)?|\.\d+)"#).joined(separator: "\n")
    case .extractURLs:
      return Self.matches(in: text, pattern: #"https?://[^\s<>"']+|www\.[^\s<>"']+"#, options: [.caseInsensitive])
        .joined(separator: "\n")
    case .htmlDecode:
      return Self.htmlDecoded(text)
    case .htmlEncode:
      return Self.htmlEncoded(text)
    case .hexDecode:
      return Self.hexDecoded(text)
    case .hexEncode:
      return Data(text.utf8).map { String(format: "%02x", $0) }.joined()
    case .generateUUID:
      return UUID().uuidString
    case .indentLines:
      return Self.lines(in: text).map { "    \($0)" }.joined(separator: "\n")
    case .joinLines:
      return Self.lines(in: text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
    case .kebabCase:
      return Self.words(in: text).map { $0.localizedLowercase }.joined(separator: "-")
    case .linesToCSV:
      return Self.lines(in: text).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
    case .md5Hash:
      return Self.md5Hash(text)
    case .naturalSortLines:
      return Self.lines(in: text).sorted { $0.localizedStandardCompare($1) == .orderedAscending }.joined(separator: "\n")
    case .naturalSortLinesDescending:
      return Self.lines(in: text).sorted { $0.localizedStandardCompare($1) == .orderedDescending }.joined(separator: "\n")
    case .numberedList:
      return Self.lines(in: text).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    case .pascalCase:
      return Self.words(in: text).map { Self.capitalizedWord($0) }.joined()
    case .quoteEachLine:
      return Self.lines(in: text).map { "\"\($0)\"" }.joined(separator: "\n")
    case .removeAccents:
      return Self.removingAccents(from: text)
    case .removeAllSpacing:
      return Self.collapsingWhitespace(in: text).trimmingCharacters(in: .whitespacesAndNewlines)
    case .removeDuplicateLines:
      return Self.removingDuplicateLines(from: text)
    case .removeExtraSpaces:
      return Self.removingExtraSpaces(from: text)
    case .removeWhitespaces:
      return String(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
    case .reverseWords:
      return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.reversed().joined(separator: " ")
    case .reverseLines:
      return Self.lines(in: text).reversed().joined(separator: "\n")
    case .reverseText:
      return String(text.reversed())
    case .sha256Hash:
      return Self.sha256Hash(text)
    case .screamingSnakeCase:
      return Self.words(in: text).map { $0.localizedUppercase }.joined(separator: "_")
    case .sentenceCase:
      return Self.sentenceCase(text)
    case .shuffleLines:
      return Self.lines(in: text).shuffled().joined(separator: "\n")
    case .slugify:
      return Self.slugify(text)
    case .smartQuotes:
      return Self.smartQuotes(text)
    case .snakeCase:
      return Self.words(in: text).map { $0.localizedLowercase }.joined(separator: "_")
    case .sortLines:
      return Self.lines(in: text).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.joined(separator: "\n")
    case .sortLinesDescending:
      return Self.lines(in: text).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }.joined(separator: "\n")
    case .sortLinesByLength:
      return Self.lines(in: text).sorted { $0.count == $1.count ? $0 < $1 : $0.count < $1.count }.joined(separator: "\n")
    case .sortLinesByLengthDescending:
      return Self.lines(in: text).sorted { $0.count == $1.count ? $0 > $1 : $0.count > $1.count }.joined(separator: "\n")
    case .spacesToTabs:
      return text.replacingOccurrences(of: "    ", with: "\t")
    case .straightQuotes:
      return Self.straightQuotes(text)
    case .stripHTMLTags:
      return Self.replacingMatches(in: text, pattern: #"<[^>]+>"#, with: "")
    case .stripMarkdown:
      return Self.stripMarkdown(text)
    case .tabsToSpaces:
      return text.replacingOccurrences(of: "\t", with: "    ")
    case .titleCase:
      return Self.words(in: text).map { Self.capitalizedWord($0) }.joined(separator: " ")
    case .trimTrailingSpacesAllLines:
      return Self.lines(in: text).map { Self.trimmingTrailingWhitespaces(from: $0) }.joined(separator: "\n")
    case .trimLeadingWhitespaces:
      return Self.lines(in: text).map { Self.trimmingLeadingWhitespaces(from: $0) }.joined(separator: "\n")
    case .trimTrailingNewlines:
      return text.trimmingCharacters(in: .newlines)
    case .trimTrailingSpaces:
      return text.trimmingCharacters(in: .whitespaces)
    case .urlDecode:
      return text.removingPercentEncoding ?? text
    case .urlEncode:
      return text.addingPercentEncoding(withAllowedCharacters: Self.urlAllowedCharacters) ?? text
    case .unescapeNewlines:
      return text.replacingOccurrences(of: "\\n", with: "\n")
    case .unindentLines:
      return Self.lines(in: text).map { Self.unindentedLine($0) }.joined(separator: "\n")
    case .wrapInBrackets:
      return "[\(text)]"
    case .wrapInParentheses:
      return "(\(text))"
    case .wrapInQuotes:
      return "\"\(text)\""
    case .wrapInSingleQuotes:
      return "'\(text)'"
    case .cleanTerminalCommand:
      return Self.cleanTerminalCommand(text)
    case .normalizeWhitespace:
      return Self.collapsingWhitespace(in: text).trimmingCharacters(in: .whitespacesAndNewlines)
    case .removeLineBreaks:
      return Self.removeLineBreaks(from: text)
    case .removeEmptyLines:
      return Self.collapsingEmptyLines(in: text)
    case .trimSurroundingWhitespaces:
      return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }

  private static let urlAllowedCharacters: CharacterSet = {
    var characters = CharacterSet.alphanumerics
    characters.insert(charactersIn: "-._~")
    return characters
  }()

  private static func lines(in text: String) -> [String] {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .components(separatedBy: "\n")
  }

  private static func listItems(from text: String) -> [String] {
    lines(in: text)
      .flatMap { commaSeparatedItems(from: $0) }
      .filter { !$0.isEmpty }
  }

  private static func commaSeparatedItems(from text: String) -> [String] {
    text
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  private static func words(in text: String) -> [String] {
    let separatedCamelCase = text.replacingOccurrences(
      of: #"([\p{Ll}\p{Nd}])([\p{Lu}])"#,
      with: "$1 $2",
      options: .regularExpression
    )

    return matches(in: separatedCamelCase, pattern: #"[\p{L}\p{N}]+"#)
  }

  private static func capitalizedWord(_ word: String) -> String {
    guard let first = word.first else {
      return word
    }

    return String(first).localizedUppercase + word.dropFirst().localizedLowercase
  }

  private static func camelCase(_ text: String) -> String {
    let tokens = words(in: text)
    guard let first = tokens.first else {
      return ""
    }

    return first.localizedLowercase + tokens.dropFirst().map { Self.capitalizedWord($0) }.joined()
  }

  private static func apTitleCase(_ text: String) -> String {
    let minorWords: Set<String> = [
      "a", "an", "and", "as", "at", "but", "by", "for", "in", "nor", "of", "on", "or", "per", "the", "to", "vs", "via"
    ]
    let tokens = words(in: text)

    return tokens.enumerated().map { index, word in
      let lowercased = word.localizedLowercase
      if index > 0, index < tokens.count - 1, minorWords.contains(lowercased) {
        return lowercased
      }

      return capitalizedWord(word)
    }
    .joined(separator: " ")
  }

  private static func base64Decoded(_ text: String) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = Data(base64Encoded: trimmed, options: [.ignoreUnknownCharacters]),
          let decoded = String(data: data, encoding: .utf8) else {
      return text
    }

    return decoded
  }

  private static func hexDecoded(_ text: String) -> String {
    let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
    let cleaned = String(text.unicodeScalars.filter { hexCharacters.contains($0) })
    guard !cleaned.isEmpty, cleaned.count.isMultiple(of: 2) else {
      return text
    }

    var bytes: [UInt8] = []
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
      let nextIndex = cleaned.index(index, offsetBy: 2)
      guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else {
        return text
      }

      bytes.append(byte)
      index = nextIndex
    }

    return String(data: Data(bytes), encoding: .utf8) ?? text
  }

  private static func md5Hash(_ text: String) -> String {
    Insecure.MD5.hash(data: Data(text.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  private static func sha256Hash(_ text: String) -> String {
    SHA256.hash(data: Data(text.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  private static func removingAccents(from text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: .current)
  }

  private static func slugify(_ text: String) -> String {
    let ascii = removingAccents(from: text).localizedLowercase
    let slug = replacingMatches(in: ascii, pattern: #"[^a-z0-9]+"#, with: "-")
    return slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
  }

  private static func removingDuplicateLines(from text: String) -> String {
    var seen = Set<String>()
    return lines(in: text).filter { seen.insert($0).inserted }.joined(separator: "\n")
  }

  private static func removingExtraSpaces(from text: String) -> String {
    lines(in: text)
      .map { replacingMatches(in: $0, pattern: #"[ \t]+"#, with: " ").trimmingCharacters(in: .whitespaces) }
      .joined(separator: "\n")
  }

  private static func trimmingLeadingWhitespaces(from line: String) -> String {
    var result = line
    while let first = result.unicodeScalars.first, CharacterSet.whitespaces.contains(first) {
      result.removeFirst()
    }

    return result
  }

  private static func trimmingTrailingWhitespaces(from line: String) -> String {
    var result = line
    while let last = result.unicodeScalars.last, CharacterSet.whitespaces.contains(last) {
      result.removeLast()
    }

    return result
  }

  private static func collapsingEmptyLines(in text: String) -> String {
    var previousLineWasEmpty = false
    var result: [String] = []

    for line in lines(in: text) {
      let isEmpty = line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if isEmpty, previousLineWasEmpty {
        continue
      }

      result.append(isEmpty ? "" : line)
      previousLineWasEmpty = isEmpty
    }

    return result.joined(separator: "\n")
  }

  private static func escapeRegex(_ text: String) -> String {
    var result = ""
    let specialCharacters = Set("\\.^$*+?()[]{}|")

    for character in text {
      if specialCharacters.contains(character) {
        result.append("\\")
      }

      result.append(character)
    }

    return result
  }

  private static func htmlEncoded(_ text: String) -> String {
    text
      .replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
  }

  private static func htmlDecoded(_ text: String) -> String {
    var decoded = text
      .replacingOccurrences(of: "&quot;", with: "\"")
      .replacingOccurrences(of: "&#39;", with: "'")
      .replacingOccurrences(of: "&apos;", with: "'")
      .replacingOccurrences(of: "&lt;", with: "<")
      .replacingOccurrences(of: "&gt;", with: ">")
      .replacingOccurrences(of: "&amp;", with: "&")

    decoded = replacingNumericHTMLEntities(in: decoded, pattern: #"&#(\d+);"#, radix: 10)
    decoded = replacingNumericHTMLEntities(in: decoded, pattern: #"&#x([0-9a-fA-F]+);"#, radix: 16)
    return decoded
  }

  private static func replacingNumericHTMLEntities(in text: String, pattern: String, radix: Int) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return text
    }

    let matches = regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    var result = text
    for match in matches.reversed() {
      guard let wholeRange = Range(match.range(at: 0), in: result),
            let valueRange = Range(match.range(at: 1), in: text),
            let value = UInt32(text[valueRange], radix: radix),
            let scalar = UnicodeScalar(value) else {
        continue
      }

      result.replaceSubrange(wholeRange, with: String(scalar))
    }

    return result
  }

  private static func smartQuotes(_ text: String) -> String {
    var result = ""
    var nextDoubleQuoteIsOpening = true
    var nextSingleQuoteIsOpening = true

    for character in text {
      switch character {
      case "\"":
        result.append(nextDoubleQuoteIsOpening ? "“" : "”")
        nextDoubleQuoteIsOpening.toggle()
      case "'":
        result.append(nextSingleQuoteIsOpening ? "‘" : "’")
        nextSingleQuoteIsOpening.toggle()
      default:
        result.append(character)
      }
    }

    return result
  }

  private static func straightQuotes(_ text: String) -> String {
    text
      .replacingOccurrences(of: "“", with: "\"")
      .replacingOccurrences(of: "”", with: "\"")
      .replacingOccurrences(of: "„", with: "\"")
      .replacingOccurrences(of: "«", with: "\"")
      .replacingOccurrences(of: "»", with: "\"")
      .replacingOccurrences(of: "‘", with: "'")
      .replacingOccurrences(of: "’", with: "'")
      .replacingOccurrences(of: "‚", with: "'")
      .replacingOccurrences(of: "–", with: "-")
      .replacingOccurrences(of: "—", with: "-")
      .replacingOccurrences(of: "…", with: "...")
  }

  private static func stripMarkdown(_ text: String) -> String {
    var result = text
    result = replacingMatches(in: result, pattern: #"!\[([^\]]*)\]\([^)]+\)"#, with: "$1")
    result = replacingMatches(in: result, pattern: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1")
    result = replacingMatches(in: result, pattern: #"(?m)^\s{0,3}#{1,6}\s*"#, with: "")
    result = replacingMatches(in: result, pattern: #"(?m)^\s*>\s?"#, with: "")
    result = replacingMatches(in: result, pattern: #"(?m)^\s*[-*+]\s+"#, with: "")
    result = replacingMatches(in: result, pattern: #"(?m)^\s*\d+\.\s+"#, with: "")
    result = replacingMatches(in: result, pattern: #"`{1,3}"#, with: "")
    result = replacingMatches(in: result, pattern: #"[*_~]{1,3}"#, with: "")
    return result
  }

  private static func unindentedLine(_ line: String) -> String {
    if line.hasPrefix("    ") {
      return String(line.dropFirst(4))
    }

    if line.hasPrefix("\t") || line.hasPrefix(" ") {
      return String(line.dropFirst())
    }

    return line
  }

  private static func matches(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return []
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
      guard let range = Range(match.range, in: text) else {
        return nil
      }

      return String(text[range])
    }
  }

  private static func replacingMatches(in text: String, pattern: String, with replacement: String) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return text
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
  }

  private static func sentenceCase(_ text: String) -> String {
    var result = ""
    var shouldCapitalizeNextLetter = true

    for character in text.localizedLowercase {
      let string = String(character)
      if shouldCapitalizeNextLetter, string.rangeOfCharacter(from: .letters) != nil {
        result += string.localizedUppercase
        shouldCapitalizeNextLetter = false
      } else {
        result += string
      }

      if ".!?\n".contains(character) {
        shouldCapitalizeNextLetter = true
      }
    }

    return result
  }

  private static func cleanTerminalCommand(_ text: String) -> String {
    let normalizedText = text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let lines = removingANSIEscapeSequences(from: normalizedText)
      .components(separatedBy: "\n")

    let segments = lines.compactMap { rawLine -> String? in
      var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
      line = removingTerminalGutter(from: line)
      line = removingShellPrompt(from: line)
      line = line.trimmingCharacters(in: .whitespacesAndNewlines)

      guard !line.isEmpty else {
        return nil
      }

      if line.hasSuffix("\\") {
        line.removeLast()
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      return line.isEmpty ? nil : line
    }

    return collapsingWhitespace(in: segments.joined(separator: " "))
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func removeLineBreaks(from text: String) -> String {
    text
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static func collapsingWhitespace(in text: String) -> String {
    text
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static func removingTerminalGutter(from line: String) -> String {
    var result = line
    while let first = result.first, "│┃║▏▎▌▐>".contains(first) {
      result.removeFirst()
      result = result.trimmingCharacters(in: .whitespaces)
    }
    return result
  }

  private static func removingShellPrompt(from line: String) -> String {
    let patterns = [
      #"^\s*(?:[$#%❯➜])\s+(.+)$"#,
      #"^\s*[^ \t\n]+@[^ \t\n]+\s+.+?[$#%]\s+(.+)$"#,
      #"^\s*[^ \t\n]+(?:\s+[^ \t\n]+)?\s+[$#%]\s+(.+)$"#
    ]

    for pattern in patterns {
      if let match = firstCapture(in: line, pattern: pattern) {
        return match
      }
    }

    return line
  }

  private static func removingANSIEscapeSequences(from text: String) -> String {
    text.replacingOccurrences(
      of: "\u{001B}\\[[0-?]*[ -/]*[@-~]",
      with: "",
      options: .regularExpression
    )
  }

  private static func firstCapture(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: text) else {
      return nil
    }

    return String(text[captureRange])
  }
}
