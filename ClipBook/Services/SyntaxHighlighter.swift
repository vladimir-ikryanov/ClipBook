import AppKit

/// Colors the code in a text preview by its programming language.
///
/// The language is guessed from the text itself, and conservatively: text that
/// does not clearly read as code, prose above all, is left as it is, because
/// coloring the words of a sentence is worse than no colors at all. The
/// languages share one simple lexer that tells comments, strings, numbers,
/// keywords, types and calls apart, which is all a preview needs, and it takes
/// well under a millisecond on a typical snippet.
nonisolated enum SyntaxHighlighter {
  /// Longer text is left plain, so a huge item never keeps a core busy.
  static let characterLimit = 100_000
  /// Text up to this length is colored before it is first drawn. Longer text
  /// is drawn plain at first and colored once the background pass is done.
  static let synchronousCharacterLimit = 10_000
  // The language is guessed from the start of the text.
  private static let detectionSampleLength = 2_000
  // The fewest signal points a language needs before the text is taken for it.
  private static let minimumDetectionScore = 2

  enum Language: CaseIterable {
    case json
    case markup
    case css
    case shell
    case sql
    case swift
    case javaScript
    case python
    case go
    case rust
    case cFamily
  }

  enum TokenKind: CaseIterable {
    case keyword
    case string
    case comment
    case number
    case type
    case function
    case attribute
    case property
    case tag
  }

  struct Token: Sendable {
    let range: NSRange
    let kind: TokenKind
  }

  /// The colored parts of the text, or none when it does not read as code.
  static func tokens(in text: String) -> [Token] {
    guard text.utf16.count <= characterLimit, let language = language(of: text) else {
      return []
    }

    let characters = Array(text.utf16)
    if language == .markup {
      var lexer = MarkupLexer(characters: characters)
      return lexer.run()
    }
    var lexer = CodeLexer(characters: characters, grammar: Grammar.grammar(for: language))
    return lexer.run()
  }

  /// Only the color of the text changes, so its layout stays as it is.
  static func apply(_ tokens: [Token], to textStorage: NSTextStorage) {
    guard !tokens.isEmpty else {
      return
    }

    textStorage.beginEditing()
    for token in tokens where NSMaxRange(token.range) <= textStorage.length {
      textStorage.addAttribute(.foregroundColor, value: color(for: token.kind), range: token.range)
    }
    textStorage.endEditing()
  }

  // MARK: - Colors

  // Close to the default Xcode theme, which most people who copy code know.
  // The colors follow the appearance on their own, so switching between light
  // and dark needs no second pass.
  private static let colors: [TokenKind: NSColor] = [
    .keyword: dynamicColor(light: 0x9B2393, dark: 0xFC5FA3),
    .string: dynamicColor(light: 0xC41A16, dark: 0xFC6A5D),
    .comment: dynamicColor(light: 0x5D6C79, dark: 0x7F8C98),
    .number: dynamicColor(light: 0x1C00CF, dark: 0xD0BF69),
    .type: dynamicColor(light: 0x0B4F79, dark: 0x5DD8FF),
    .function: dynamicColor(light: 0x326D74, dark: 0x67B7A4),
    .attribute: dynamicColor(light: 0x643820, dark: 0xFD8F3F),
    .property: dynamicColor(light: 0x6C36A9, dark: 0xA167E6),
    .tag: dynamicColor(light: 0x0F68A0, dark: 0x41A1C0)
  ]

  private static func color(for kind: TokenKind) -> NSColor {
    colors[kind] ?? .labelColor
  }

  private static func dynamicColor(light: UInt32, dark: UInt32) -> NSColor {
    NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
      let value = isDark ? dark : light
      return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
        green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255,
        alpha: 1
      )
    }
  }

  // MARK: - Detection

  static func language(of text: String) -> Language? {
    let sample = String(text.prefix(detectionSampleLength))
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard let first = sample.first else {
      return nil
    }

    if (first == "{" || first == "[") && isJSON(text) {
      return .json
    }
    if first == "<" && isMarkup(sample) {
      return .markup
    }
    guard !readsAsProse(sample) else {
      return nil
    }

    let range = NSRange(location: 0, length: (sample as NSString).length)
    var bestMatch: (language: Language, score: Int)?
    for (language, signals) in detectionSignals {
      let score = signals.reduce(0) { score, signal in
        signal.expression.firstMatch(in: sample, range: range) == nil ? score : score + signal.weight
      }
      if score > (bestMatch?.score ?? 0) {
        bestMatch = (language, score)
      }
    }
    guard let bestMatch, bestMatch.score >= minimumDetectionScore else {
      return nil
    }

    return bestMatch.language
  }

  private static func isJSON(_ text: String) -> Bool {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedText.last == "}" || trimmedText.last == "]" else {
      return false
    }

    return (try? JSONSerialization.jsonObject(with: Data(trimmedText.utf8))) != nil
  }

  private static func isMarkup(_ sample: String) -> Bool {
    let lowercasedSample = sample.lowercased()
    if lowercasedSample.hasPrefix("<?xml")
        || lowercasedSample.hasPrefix("<!doctype")
        || lowercasedSample.hasPrefix("<!--") {
      return true
    }

    let range = NSRange(location: 0, length: (sample as NSString).length)
    return openingTagExpression.firstMatch(in: sample, range: range) != nil
      && (sample.contains("</") || sample.contains("/>"))
  }

  private static let openingTagExpression = try! NSRegularExpression(
    pattern: #"^<[A-Za-z][\w:.-]*(\s[^<>]*)?/?>"#
  )

  // What may follow a word in a sentence.
  private static let sentencePunctuation = Set(#".,!?:;)"'"#)
  // How a line of code usually ends, where a sentence would end with a period.
  private static let codeLineEndings = Set(#";{}()[]=>\"#)
  private static let commentPrefixes = ["//", "/*", "*", "#", "--", "<!--"]

  // Prose is told apart by its lines: long runs of plain words that start at
  // the margin and end like a sentence. A command with its options, paths and
  // quoted arguments has too few plain words to pass for one. Comments read
  // like prose too, so they are not counted either way.
  private static func readsAsProse(_ sample: String) -> Bool {
    var lineCount = 0
    var proseLineCount = 0
    for line in sample.split(whereSeparator: \.isNewline) {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      guard !trimmedLine.isEmpty,
            !commentPrefixes.contains(where: { trimmedLine.hasPrefix($0) }) else {
        continue
      }

      lineCount += 1
      let isIndented = line.first == " " || line.first == "\t"
      let words = trimmedLine.split(separator: " ")
      let plainWordCount = words.filter(isPlainWord).count
      let endsLikeCode = trimmedLine.last.map { codeLineEndings.contains($0) } ?? false
      if !isIndented && !endsLikeCode && words.count >= 6 && plainWordCount * 5 >= words.count * 4 {
        proseLineCount += 1
      }
    }
    return proseLineCount * 2 >= lineCount && proseLineCount > 0
  }

  private static func isPlainWord(_ word: Substring) -> Bool {
    var word = word
    while let last = word.last, sentencePunctuation.contains(last) {
      word = word.dropLast()
    }
    return word.first?.isLetter == true && word.allSatisfy { $0.isLetter || $0 == "'" || $0 == "’" || $0 == "-" }
  }

  private struct Signal {
    let expression: NSRegularExpression
    let weight: Int

    init(_ pattern: String, weight: Int = 1, ignoresCase: Bool = false) {
      var options: NSRegularExpression.Options = [.anchorsMatchLines]
      if ignoresCase {
        options.insert(.caseInsensitive)
      }
      expression = try! NSRegularExpression(pattern: pattern, options: options)
      self.weight = weight
    }
  }

  // Each language scores the points of the signals the text shows, and the
  // one with the most wins. Strong signals that hardly occur anywhere else are
  // worth two points, enough on their own; weak ones need company.
  private static let detectionSignals: [(Language, [Signal])] = [
    (.swift, [
      Signal(#"^\s*import (Foundation|SwiftUI|UIKit|AppKit|Combine|XCTest|Testing)\s*$"#, weight: 2),
      Signal(#"\bfunc \w+\s*(<[^>]*>)?\("#),
      Signal(#"\b(let|var) \w+(\s*:\s*[\w\[\]?<>.]+)?\s*="#),
      Signal(#"\b(guard|if) (let|var)\b|\bguard\b.*\belse\s*\{"#, weight: 2),
      Signal(#"@(MainActor|State|Published|Binding|objc|escaping|available|main|Observable)\b"#, weight: 2),
      Signal(#"\b(struct|class|enum|protocol|extension|actor) \w+(\s*:\s*[\w, ]+)?\s*\{"#),
      Signal(#"\)\s*(async\s*)?(throws\s*)?->\s*[\w\[(]"#),
      Signal(#"\b(nil|private\(set\)|fileprivate|inout|didSet|willSet)\b"#)
    ]),
    (.javaScript, [
      Signal(#"\b(const|let) \w+\s*="#),
      Signal(#"=>"#),
      Signal(#"\bfunction\b\s*\*?\s*\w*\s*\("#, weight: 2),
      Signal(#"\bconsole\.\w+\("#, weight: 2),
      Signal(#"^\s*import .* from ['"]|\brequire\(['"]"#, weight: 2),
      Signal(#"^\s*export (default|const|function|class|interface|type)\b"#, weight: 2),
      Signal(#"===|!=="#),
      Signal(#"\b(document|window)\.\w+"#),
      Signal(#"\binterface \w+\s*\{|:\s*(string|number|boolean)\b"#),
      Signal(#";\s*$"#)
    ]),
    (.python, [
      Signal(#"^\s*def \w+\(.*\)\s*(->\s*[^:]+)?:\s*$"#, weight: 2),
      Signal(#"^\s*from [\w.]+ import \w|^\s*import [\w.]+(\s+as \w+)?\s*$"#),
      Signal(#"^\s*(if|elif|else|for|while|with|try|except|class)\b.*:\s*$"#),
      Signal(#"\bself\.\w+"#),
      Signal(#"\b(None|True|False)\b"#),
      Signal(#"^\s*(elif|except)\b|__\w+__|\bf"[^"]*\{"#, weight: 2)
    ]),
    (.go, [
      Signal(#"^package \w+\s*$"#, weight: 2),
      Signal(#"\bfunc (\(\w+ \*?\w+\) )?\w+\("#),
      Signal(#":="#),
      Signal(#"\bfmt\.\w+\("#, weight: 2),
      Signal(#"\berr != nil\b"#, weight: 2)
    ]),
    (.rust, [
      Signal(#"\bfn \w+\s*(<[^>]*>)?\("#, weight: 2),
      Signal(#"\blet mut\b"#, weight: 2),
      Signal(#"^\s*use \w+(::[\w{}*, ]+)+;"#, weight: 2),
      Signal(#"\b\w+!\("#),
      Signal(#"::"#),
      Signal(#"&mut |&self\b|\bimpl\b"#, weight: 2)
    ]),
    (.cFamily, [
      Signal(#"^\s*#(include|define|import|pragma|ifndef)\b"#, weight: 2),
      Signal(#"\b(public|private|protected)( static)?( final)? [\w<>\[\],]+ \w+\s*\("#, weight: 2),
      Signal(#"\bint main\s*\("#, weight: 2),
      Signal(#"\bstd::|\bSystem\.out\.print|\bConsole\.Write|@(interface|implementation)\b"#, weight: 2),
      Signal(#"\b(void|int|char|double|float|bool|long)\s+\**\w+\s*[(=;]"#),
      Signal(#"\b(fun|val) \w+"#),
      Signal(#";\s*$"#)
    ]),
    (.sql, [
      Signal(#"\bSELECT\b[\s\S]*\bFROM\b"#, weight: 2),
      Signal(#"\bselect\b[\s\S]*\bfrom\b"#, ignoresCase: true),
      Signal(#"^\s*(INSERT INTO|UPDATE \w+ SET|DELETE FROM|CREATE (TABLE|INDEX|VIEW)|ALTER TABLE|DROP TABLE)\b"#, weight: 2, ignoresCase: true),
      Signal(#"\b(WHERE|INNER JOIN|LEFT JOIN|GROUP BY|ORDER BY)\b"#),
      Signal(#"\bwhere\s+[\w.]+\s*(=|<|>|like\b|in\b|is\b)"#, ignoresCase: true),
      Signal(#";\s*$"#)
    ]),
    (.css, [
      Signal(#"^\s*[-\w]+\s*:\s*[^;{}\n]+;\s*$"#),
      Signal(#"^[.#:\w\[\]*>+~ ,=\"'()-]+\{[ \t]*$"#),
      Signal(#"\b\d+(px|em|rem|vh|vw|pt)\b"#),
      Signal(#"@media\b|@import\b|!important\b|@keyframes\b"#, weight: 2)
    ]),
    (.shell, [
      Signal(#"^#!.*\b(ba|z|k|fi)?sh\b"#, weight: 3),
      Signal(#"^\s*(\$ )?(sudo|brew|apt|apt-get|npm|npx|yarn|pnpm|pip3?|git|cd|ls|mkdir|rm|cp|mv|chmod|chown|curl|wget|docker|kubectl|export|echo|source|cat|grep|ssh|scp|xcodebuild|xcrun|swift|make|defaults|open|killall|launchctl|tar|find|sed|awk)\s"#),
      Signal(#"^\$ \w"#, weight: 2),
      Signal(#"(^|\s)--?[a-zA-Z][\w-]*"#),
      Signal(#"\$\{?\w+\}?"#),
      Signal(#"\|\s*\w+|&&"#),
      Signal(#"^\s*(if|for|while)\b.*;\s*(then|do)\b|^\s*(fi|done|esac)\s*$"#, weight: 2)
    ])
  ]
}

// MARK: - Grammars

private nonisolated struct Grammar {
  var keywords: Set<String> = []
  var types: Set<String> = []
  var lineComments: [[UInt16]] = []
  var blockComment: (open: [UInt16], close: [UInt16])?
  var stringQuotes: Set<UInt16> = units(#""'"#)
  // Quotes whose strings may go on over several lines, like template literals.
  var multilineQuotes: Set<UInt16> = []
  var tripleQuotedStrings = false
  var keywordsIgnoreCase = false
  var capitalizedNamesAreTypes = true
  // Prefixes of attributes, decorators, annotations and directives, such as
  // `@MainActor` or `#include`.
  var directivePrefixes: Set<UInt16> = []
  // Characters that may be part of a name besides letters, digits and `_`.
  var namePunctuation: Set<UInt16> = []
  // CSS properties: names followed by a colon inside a block.
  var namesBeforeColonAreProperties = false
  // JSON keys: strings followed by a colon.
  var stringsBeforeColonAreProperties = false
  var hexColorsAreNumbers = false
  // The shell colors variables, the command a line runs, and its options.
  var isShell = false

  static func grammar(for language: SyntaxHighlighter.Language) -> Grammar {
    switch language {
    case .json:
      return json
    case .css:
      return css
    case .shell:
      return shell
    case .sql:
      return sql
    case .swift:
      return swift
    case .javaScript:
      return javaScript
    case .python:
      return python
    case .go:
      return go
    case .rust:
      return rust
    case .cFamily, .markup:
      return cFamily
    }
  }

  private static let cStyleLineComments: [[UInt16]] = [units("//")]
  private static let cStyleBlockComment: (open: [UInt16], close: [UInt16]) = (units("/*"), units("*/"))

  private static let json = Grammar(
    keywords: ["true", "false", "null"],
    stringQuotes: units("\""),
    capitalizedNamesAreTypes: false,
    stringsBeforeColonAreProperties: true
  )

  private static let css = Grammar(
    keywords: ["important", "inherit", "initial", "unset", "none", "auto"],
    blockComment: cStyleBlockComment,
    capitalizedNamesAreTypes: false,
    directivePrefixes: units("@"),
    namePunctuation: units("-"),
    namesBeforeColonAreProperties: true,
    hexColorsAreNumbers: true
  )

  private static let shell = Grammar(
    keywords: [
      "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac",
      "in", "function", "return", "local", "export", "readonly", "declare", "unset", "shift",
      "exit", "break", "continue", "source", "alias", "sudo", "time"
    ],
    lineComments: [units("#")],
    stringQuotes: units("\"'`"),
    capitalizedNamesAreTypes: false,
    namePunctuation: units("-"),
    isShell: true
  )

  private static let sql = Grammar(
    keywords: [
      "select", "from", "where", "and", "or", "not", "insert", "into", "values", "update", "set",
      "delete", "create", "table", "index", "view", "drop", "alter", "add", "column", "primary",
      "key", "foreign", "references", "join", "inner", "left", "right", "outer", "full", "cross",
      "on", "as", "group", "by", "order", "asc", "desc", "having", "limit", "offset", "union",
      "all", "distinct", "null", "is", "in", "like", "between", "exists", "case", "when", "then",
      "else", "end", "default", "constraint", "unique", "if", "begin", "commit", "rollback",
      "transaction", "with", "returning", "true", "false", "replace", "trigger", "using"
    ],
    types: [
      "int", "integer", "varchar", "text", "char", "boolean", "bool", "date", "datetime",
      "timestamp", "real", "float", "double", "decimal", "numeric", "bigint", "smallint",
      "serial", "blob", "json", "jsonb", "uuid"
    ],
    lineComments: [units("--")],
    blockComment: cStyleBlockComment,
    keywordsIgnoreCase: true,
    capitalizedNamesAreTypes: false
  )

  private static let swift = Grammar(
    keywords: [
      "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func", "import",
      "init", "inout", "internal", "let", "open", "operator", "private", "protocol", "public",
      "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch",
      "continue", "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in",
      "repeat", "return", "throw", "switch", "where", "while", "as", "false", "is", "nil",
      "self", "Self", "super", "throws", "true", "try", "async", "await", "actor", "some", "any",
      "weak", "unowned", "lazy", "final", "override", "mutating", "nonmutating", "convenience",
      "required", "get", "set", "willSet", "didSet", "indirect", "nonisolated", "isolated",
      "consuming", "borrowing", "sending", "macro", "package"
    ],
    lineComments: cStyleLineComments,
    blockComment: cStyleBlockComment,
    stringQuotes: units("\""),
    tripleQuotedStrings: true,
    directivePrefixes: units("@#")
  )

  private static let javaScript = Grammar(
    keywords: [
      "break", "case", "catch", "class", "const", "continue", "debugger", "default", "delete",
      "do", "else", "export", "extends", "finally", "for", "function", "if", "import", "in",
      "instanceof", "new", "return", "super", "switch", "this", "throw", "try", "typeof", "var",
      "void", "while", "with", "yield", "let", "static", "async", "await", "of", "null",
      "undefined", "true", "false", "from", "as", "interface", "type", "enum", "implements",
      "private", "public", "protected", "readonly", "declare", "namespace", "abstract", "keyof",
      "get", "set"
    ],
    types: ["any", "unknown", "never", "number", "string", "boolean", "object", "bigint", "symbol"],
    lineComments: cStyleLineComments,
    blockComment: cStyleBlockComment,
    stringQuotes: units("\"'`"),
    multilineQuotes: units("`"),
    directivePrefixes: units("@"),
    namePunctuation: units("$")
  )

  private static let python = Grammar(
    keywords: [
      "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
      "continue", "def", "del", "elif", "else", "except", "finally", "for", "from", "global",
      "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass", "raise", "return",
      "try", "while", "with", "yield", "self", "cls", "match", "case"
    ],
    types: ["int", "str", "float", "bool", "list", "dict", "set", "tuple", "bytes", "object"],
    lineComments: [units("#")],
    tripleQuotedStrings: true,
    directivePrefixes: units("@")
  )

  private static let go = Grammar(
    keywords: [
      "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough",
      "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range",
      "return", "select", "struct", "switch", "type", "var", "nil", "true", "false", "iota"
    ],
    types: [
      "int", "int8", "int16", "int32", "int64", "uint", "uint8", "uint16", "uint32", "uint64",
      "uintptr", "float32", "float64", "complex64", "complex128", "string", "bool", "byte",
      "rune", "error", "any"
    ],
    lineComments: cStyleLineComments,
    blockComment: cStyleBlockComment,
    stringQuotes: units("\"'`"),
    multilineQuotes: units("`")
  )

  // A single quote starts a lifetime as often as a character, so only double
  // quotes make strings.
  private static let rust = Grammar(
    keywords: [
      "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else", "enum",
      "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop", "match", "mod", "move",
      "mut", "pub", "ref", "return", "self", "Self", "static", "struct", "super", "trait",
      "true", "type", "unsafe", "use", "where", "while"
    ],
    types: [
      "i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64", "u128", "usize",
      "f32", "f64", "bool", "char", "str"
    ],
    lineComments: cStyleLineComments,
    blockComment: cStyleBlockComment,
    stringQuotes: units("\""),
    directivePrefixes: units("#")
  )

  // C, C++, Objective-C, Java, C# and Kotlin share most of their words.
  private static let cFamily = Grammar(
    keywords: [
      "auto", "break", "case", "char", "const", "continue", "default", "do", "double", "else",
      "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long", "register",
      "return", "short", "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
      "unsigned", "void", "volatile", "while", "bool", "true", "false", "NULL", "nullptr",
      "class", "namespace", "new", "delete", "this", "public", "private", "protected",
      "virtual", "override", "template", "typename", "using", "try", "catch", "throw",
      "throws", "final", "abstract", "extends", "implements", "import", "package", "interface",
      "super", "instanceof", "synchronized", "boolean", "byte", "fun", "val", "var", "when",
      "object", "companion", "data", "sealed", "is", "internal", "open", "lateinit", "null",
      "self", "nil", "YES", "NO", "id", "readonly", "async", "await", "string", "operator"
    ],
    lineComments: cStyleLineComments,
    blockComment: cStyleBlockComment,
    directivePrefixes: units("@#")
  )
}

private nonisolated func units(_ string: String) -> Set<UInt16> {
  Set(string.utf16)
}

private nonisolated func units(_ string: String) -> [UInt16] {
  Array(string.utf16)
}

private nonisolated enum Character16 {
  static let newline = UInt16(UInt8(ascii: "\n"))
  static let carriageReturn = UInt16(UInt8(ascii: "\r"))
  static let space = UInt16(UInt8(ascii: " "))
  static let tab = UInt16(UInt8(ascii: "\t"))
  static let backslash = UInt16(UInt8(ascii: "\\"))
  static let dollar = UInt16(UInt8(ascii: "$"))
  static let hash = UInt16(UInt8(ascii: "#"))
  static let dash = UInt16(UInt8(ascii: "-"))
  static let dot = UInt16(UInt8(ascii: "."))
  static let colon = UInt16(UInt8(ascii: ":"))
  static let equals = UInt16(UInt8(ascii: "="))
  static let underscore = UInt16(UInt8(ascii: "_"))
  static let openParenthesis = UInt16(UInt8(ascii: "("))
  static let openBrace = UInt16(UInt8(ascii: "{"))
  static let closeBrace = UInt16(UInt8(ascii: "}"))
  static let openBracket = UInt16(UInt8(ascii: "["))
  static let lessThan = UInt16(UInt8(ascii: "<"))
  static let greaterThan = UInt16(UInt8(ascii: ">"))
  static let slash = UInt16(UInt8(ascii: "/"))
  static let exclamation = UInt16(UInt8(ascii: "!"))
  static let question = UInt16(UInt8(ascii: "?"))
  static let ampersand = UInt16(UInt8(ascii: "&"))
  static let semicolon = UInt16(UInt8(ascii: ";"))
  static let pipe = UInt16(UInt8(ascii: "|"))

  static func isLetter(_ character: UInt16) -> Bool {
    (character >= 0x41 && character <= 0x5A) || (character >= 0x61 && character <= 0x7A)
  }

  static func isUppercase(_ character: UInt16) -> Bool {
    character >= 0x41 && character <= 0x5A
  }

  static func isDigit(_ character: UInt16) -> Bool {
    character >= 0x30 && character <= 0x39
  }

  static func isHexDigit(_ character: UInt16) -> Bool {
    isDigit(character) || (character >= 0x41 && character <= 0x46) || (character >= 0x61 && character <= 0x66)
  }

  static func isWhitespace(_ character: UInt16) -> Bool {
    character == space || character == tab || character == newline || character == carriageReturn
  }
}

// MARK: - Lexers

/// One pass over the text, one token at a time. Whatever it does not
/// recognize, such as operators and punctuation, keeps the plain color.
private nonisolated struct CodeLexer {
  typealias C = Character16

  let characters: [UInt16]
  let grammar: Grammar
  private var tokens: [SyntaxHighlighter.Token] = []
  private var index = 0
  private var braceDepth = 0
  // In the shell, whether the next word is the command a line runs.
  private var expectsCommand = true
  private static let shellKeywordsBeforeCommands: Set<String> = [
    "if", "then", "else", "elif", "while", "until", "do", "sudo", "time"
  ]

  init(characters: [UInt16], grammar: Grammar) {
    self.characters = characters
    self.grammar = grammar
  }

  mutating func run() -> [SyntaxHighlighter.Token] {
    while index < characters.count {
      if lexComment() || lexString() || lexNumber() || lexDirective() || lexShellVariable()
          || lexShellOption() || lexName() {
        continue
      }
      lexPunctuation(characters[index])
      index += 1
    }
    return tokens
  }

  private mutating func addToken(from start: Int, to end: Int, kind: SyntaxHighlighter.TokenKind) {
    guard end > start else {
      return
    }
    tokens.append(SyntaxHighlighter.Token(range: NSRange(location: start, length: end - start), kind: kind))
  }

  private func hasPrefix(_ prefix: [UInt16], at position: Int) -> Bool {
    guard position + prefix.count <= characters.count else {
      return false
    }
    for offset in 0..<prefix.count where characters[position + offset] != prefix[offset] {
      return false
    }
    return true
  }

  private func isNameCharacter(_ character: UInt16) -> Bool {
    C.isLetter(character) || C.isDigit(character) || character == C.underscore
      || grammar.namePunctuation.contains(character)
  }

  private func isAtWordStart(_ position: Int) -> Bool {
    position == 0 || C.isWhitespace(characters[position - 1])
  }

  // The first character after the spaces that follow a position, on the same line.
  private func nextCharacter(after position: Int) -> UInt16? {
    var position = position
    while position < characters.count,
          characters[position] == C.space || characters[position] == C.tab {
      position += 1
    }
    return position < characters.count ? characters[position] : nil
  }

  private func endOfLine(from position: Int) -> Int {
    var position = position
    while position < characters.count, characters[position] != C.newline {
      position += 1
    }
    return position
  }

  private mutating func lexComment() -> Bool {
    for prefix in grammar.lineComments where hasPrefix(prefix, at: index) {
      // A `#` inside a word, such as `$#` or `a#b`, does not start a comment.
      if prefix == [C.hash] && !isAtWordStart(index) {
        continue
      }
      let end = endOfLine(from: index)
      addToken(from: index, to: end, kind: .comment)
      index = end
      return true
    }

    guard let blockComment = grammar.blockComment, hasPrefix(blockComment.open, at: index) else {
      return false
    }
    var end = index + blockComment.open.count
    while end < characters.count && !hasPrefix(blockComment.close, at: end) {
      end += 1
    }
    end = min(end + blockComment.close.count, characters.count)
    addToken(from: index, to: end, kind: .comment)
    index = end
    return true
  }

  private mutating func lexString() -> Bool {
    let quote = characters[index]
    guard grammar.stringQuotes.contains(quote) else {
      return false
    }

    let start = index
    var end: Int
    if grammar.tripleQuotedStrings, hasPrefix([quote, quote, quote], at: index) {
      end = index + 3
      while end < characters.count && !hasPrefix([quote, quote, quote], at: end) {
        end += characters[end] == C.backslash ? 2 : 1
      }
      end = min(end + 3, characters.count)
    } else {
      let isMultiline = grammar.multilineQuotes.contains(quote)
      end = index + 1
      var isClosed = false
      while end < characters.count {
        let character = characters[end]
        // Single quotes in the shell keep a backslash as it is.
        if character == C.backslash && !(grammar.isShell && quote == UInt16(UInt8(ascii: "'"))) {
          end += 2
          continue
        }
        if character == quote {
          end += 1
          isClosed = true
          break
        }
        if character == C.newline && !isMultiline {
          break
        }
        end += 1
      }
      // A quote that is not closed on its line is an apostrophe, a lifetime or
      // a typo rather than a string, and coloring the rest of the text after
      // it would be wrong far more often than right.
      guard isClosed || isMultiline else {
        return false
      }
      end = min(end, characters.count)
    }

    let isKey = grammar.stringsBeforeColonAreProperties && nextCharacter(after: end) == C.colon
    addToken(from: start, to: end, kind: isKey ? .property : .string)
    index = end
    expectsCommand = false
    return true
  }

  private mutating func lexNumber() -> Bool {
    let character = characters[index]
    if grammar.hexColorsAreNumbers, character == C.hash {
      var end = index + 1
      while end < characters.count && isNameCharacter(characters[end]) {
        end += 1
      }
      // `#fff` is a color, `#header` the selector of an element.
      let digits = characters[(index + 1)..<end]
      if [3, 4, 6, 8].contains(digits.count) && digits.allSatisfy(C.isHexDigit) {
        addToken(from: index, to: end, kind: .number)
        index = end
        return true
      }
    }

    guard C.isDigit(character), index == 0 || !isNameCharacter(characters[index - 1]) else {
      return false
    }
    var end = index + 1
    while end < characters.count {
      let next = characters[end]
      let isFraction = next == C.dot && end + 1 < characters.count && C.isDigit(characters[end + 1])
      guard C.isLetter(next) || C.isDigit(next) || next == C.underscore || isFraction else {
        break
      }
      end += 1
    }
    addToken(from: index, to: end, kind: .number)
    index = end
    expectsCommand = false
    return true
  }

  private mutating func lexDirective() -> Bool {
    guard grammar.directivePrefixes.contains(characters[index]),
          index + 1 < characters.count, C.isLetter(characters[index + 1]) else {
      return false
    }
    var end = index + 1
    while end < characters.count && isNameCharacter(characters[end]) {
      end += 1
    }
    addToken(from: index, to: end, kind: .attribute)
    index = end
    return true
  }

  private mutating func lexShellVariable() -> Bool {
    guard grammar.isShell, characters[index] == C.dollar, index + 1 < characters.count else {
      return false
    }

    let next = characters[index + 1]
    var end = index + 1
    if next == C.openBrace {
      while end < characters.count && characters[end] != C.closeBrace && characters[end] != C.newline {
        end += 1
      }
      end = min(end + 1, characters.count)
    } else if C.isLetter(next) || next == C.underscore {
      while end < characters.count
              && (C.isLetter(characters[end]) || C.isDigit(characters[end]) || characters[end] == C.underscore) {
        end += 1
      }
    } else if C.isDigit(next) || "@*#?$!".utf16.contains(next) {
      end += 1
    } else {
      return false
    }
    addToken(from: index, to: end, kind: .property)
    index = end
    expectsCommand = false
    return true
  }

  private mutating func lexShellOption() -> Bool {
    guard grammar.isShell, characters[index] == C.dash, isAtWordStart(index),
          index + 1 < characters.count,
          C.isLetter(characters[index + 1]) || characters[index + 1] == C.dash else {
      return false
    }
    var end = index + 1
    while end < characters.count && (isNameCharacter(characters[end]) || characters[end] == C.dash) {
      end += 1
    }
    addToken(from: index, to: end, kind: .attribute)
    index = end
    return true
  }

  private mutating func lexName() -> Bool {
    let character = characters[index]
    let startsName = C.isLetter(character) || character == C.underscore
      || (grammar.namePunctuation.contains(character) && character != C.dash)
      || (character == C.dash && grammar.namesBeforeColonAreProperties
            && index + 1 < characters.count && C.isLetter(characters[index + 1]))
    guard startsName else {
      return false
    }

    let start = index
    var end = index + 1
    while end < characters.count && isNameCharacter(characters[end]) {
      end += 1
    }
    index = end
    let name = String(decoding: characters[start..<end], as: UTF16.self)
    let next = nextCharacter(after: end)
    let isMember = start > 0 && characters[start - 1] == C.dot

    if !isMember, grammar.keywords.contains(grammar.keywordsIgnoreCase ? name.lowercased() : name) {
      addToken(from: start, to: end, kind: .keyword)
      if grammar.isShell {
        expectsCommand = Self.shellKeywordsBeforeCommands.contains(name)
      }
      return true
    }
    if !isMember, grammar.types.contains(grammar.keywordsIgnoreCase ? name.lowercased() : name) {
      addToken(from: start, to: end, kind: .type)
      return true
    }
    if grammar.isShell {
      if expectsCommand {
        // `NAME=value` before a command sets a variable for it.
        if next == C.equals {
          addToken(from: start, to: end, kind: .property)
        } else {
          addToken(from: start, to: end, kind: .function)
          expectsCommand = false
        }
      }
      return true
    }
    if grammar.namesBeforeColonAreProperties && braceDepth > 0 && next == C.colon {
      addToken(from: start, to: end, kind: .property)
      return true
    }
    if next == C.openParenthesis
        || (next == C.exclamation && end + 1 < characters.count && characters[end + 1] == C.openParenthesis) {
      addToken(from: start, to: end, kind: .function)
      return true
    }
    if grammar.capitalizedNamesAreTypes && C.isUppercase(character) {
      addToken(from: start, to: end, kind: .type)
    }
    return true
  }

  private mutating func lexPunctuation(_ character: UInt16) {
    switch character {
    case C.openBrace:
      braceDepth += 1
    case C.closeBrace:
      braceDepth = max(0, braceDepth - 1)
    default:
      break
    }

    guard grammar.isShell else {
      return
    }
    switch character {
    case C.newline, C.pipe, C.semicolon, C.ampersand, C.openParenthesis, C.openBrace:
      expectsCommand = true
    case C.space, C.tab, C.carriageReturn, C.backslash:
      break
    default:
      expectsCommand = false
    }
  }
}

/// HTML, XML and SVG: tag names, attributes and their values, comments and
/// character references. What is between the tags stays plain.
private nonisolated struct MarkupLexer {
  typealias C = Character16

  let characters: [UInt16]
  private var tokens: [SyntaxHighlighter.Token] = []
  private var index = 0
  private static let commentOpen: [UInt16] = units("<!--")
  private static let commentClose: [UInt16] = units("-->")

  init(characters: [UInt16]) {
    self.characters = characters
  }

  mutating func run() -> [SyntaxHighlighter.Token] {
    while index < characters.count {
      if hasPrefix(Self.commentOpen, at: index) {
        var end = index + Self.commentOpen.count
        while end < characters.count && !hasPrefix(Self.commentClose, at: end) {
          end += 1
        }
        end = min(end + Self.commentClose.count, characters.count)
        addToken(from: index, to: end, kind: .comment)
        index = end
      } else if characters[index] == C.lessThan, index + 1 < characters.count,
                startsTag(characters[index + 1]) {
        lexTag()
      } else if characters[index] == C.ampersand {
        lexCharacterReference()
      } else {
        index += 1
      }
    }
    return tokens
  }

  private func startsTag(_ character: UInt16) -> Bool {
    C.isLetter(character) || character == C.slash || character == C.exclamation || character == C.question
  }

  private func isNameCharacter(_ character: UInt16) -> Bool {
    C.isLetter(character) || C.isDigit(character) || character == C.underscore
      || character == C.dash || character == C.colon || character == C.dot
  }

  private func hasPrefix(_ prefix: [UInt16], at position: Int) -> Bool {
    guard position + prefix.count <= characters.count else {
      return false
    }
    for offset in 0..<prefix.count where characters[position + offset] != prefix[offset] {
      return false
    }
    return true
  }

  private mutating func addToken(from start: Int, to end: Int, kind: SyntaxHighlighter.TokenKind) {
    guard end > start else {
      return
    }
    tokens.append(SyntaxHighlighter.Token(range: NSRange(location: start, length: end - start), kind: kind))
  }

  private mutating func lexTag() {
    var position = index + 1
    while position < characters.count,
          [C.slash, C.exclamation, C.question].contains(characters[position]) {
      position += 1
    }
    let nameStart = position
    while position < characters.count && isNameCharacter(characters[position]) {
      position += 1
    }
    addToken(from: nameStart, to: position, kind: .tag)

    while position < characters.count && characters[position] != C.greaterThan {
      let character = characters[position]
      if character == UInt16(UInt8(ascii: "\"")) || character == UInt16(UInt8(ascii: "'")) {
        var end = position + 1
        while end < characters.count && characters[end] != character {
          end += 1
        }
        end = min(end + 1, characters.count)
        addToken(from: position, to: end, kind: .string)
        position = end
      } else if C.isLetter(character) || character == C.underscore {
        let start = position
        while position < characters.count && isNameCharacter(characters[position]) {
          position += 1
        }
        addToken(from: start, to: position, kind: .property)
      } else if character == C.lessThan {
        // A stray `<` that never closed its tag; the next tag starts here.
        index = position
        return
      } else {
        position += 1
      }
    }
    index = min(position + 1, characters.count)
  }

  private mutating func lexCharacterReference() {
    var end = index + 1
    while end < characters.count, end - index <= 10,
          C.isLetter(characters[end]) || C.isDigit(characters[end]) || characters[end] == C.hash {
      end += 1
    }
    if end < characters.count, characters[end] == C.semicolon, end > index + 1 {
      addToken(from: index, to: end + 1, kind: .number)
      index = end + 1
    } else {
      index += 1
    }
  }
}
