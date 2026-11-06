import AppKit

/// What the user said about an item, which always wins over what the app
/// detects on its own. An item the user said nothing about has none.
enum ItemSensitivity: String, Codable, Hashable {
    /// The whole content is hidden.
    case sensitive
    /// Nothing is hidden, whatever the content looks like.
    case notSensitive
}

/// Hides passwords, keys and tokens in the text the history shows. Only what
/// is drawn on screen is masked: pasting, copying, dragging and searching all
/// work with the real content.
enum SensitiveContent {
    /// A fully hidden item always shows the same number of dots, so the length
    /// of the secret is not given away.
    static let wholeMask = String(repeating: maskCharacter, count: 12)
    static let inlineMask = String(repeating: maskCharacter, count: 8)
    /// A card number keeps its last four digits, the way a receipt shows it,
    /// so cards can be told apart. The groups before them are always three,
    /// whatever the length of the number.
    private static let cardNumberMask = Array(
        repeating: String(repeating: maskCharacter, count: 4),
        count: 3
    ).joined(separator: " ")
    // A circle rather than a bullet: it is bigger, and it is rare in text, so
    // a row of them is told apart from the text around it.
    private static let maskCharacter = "●"
    private static let maskExpression = try! NSRegularExpression(
        pattern: "\(maskCharacter){\(inlineMask.count),}|\(cardNumberMask)(?= \\d{4}(?!\\d))"
    )

    // The circle is as tall as a capital letter, which is too heavy for a row of
    // them, so the dots are drawn smaller than the text and lifted to stay in
    // the middle of the line.
    private static let maskFontScale: CGFloat = 0.42
    private static let maskBaselineOffsetScale: CGFloat = 0.19
    private static let maskSpacing: CGFloat = 3

    /// What the dots are drawn with in text of the given font, besides their
    /// color.
    static func maskAttributes(for font: NSFont) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFontManager.shared.convert(font, toSize: font.pointSize * maskFontScale),
            .baselineOffset: font.pointSize * maskBaselineOffsetScale,
            .kern: maskSpacing
        ]
    }

    /// Sets the dots in `range` apart from the text right before them by the
    /// space there is between the dots themselves.
    static func addSpacing(beforeMaskAt range: NSRange, in attributedText: NSMutableAttributedString) {
        guard range.location > 0 else {
            return
        }

        let precedingCharacter = (attributedText.string as NSString)
            .rangeOfComposedCharacterSequence(at: range.location - 1)
        attributedText.addAttribute(.kern, value: maskSpacing, range: precedingCharacter)
    }

    /// Where the dots that stand for hidden content are in a text that was
    /// masked, so they can be drawn unlike the text itself.
    static func maskRanges(in maskedText: String) -> [NSRange] {
        guard maskedText.contains(maskCharacter) else {
            return []
        }

        let string = maskedText as NSString
        let fullRange = NSRange(location: 0, length: string.length)
        return maskExpression.matches(in: maskedText, range: fullRange).flatMap { match in
            // The groups of a card number are drawn one by one, so the spaces
            // between them stay as wide as in the text.
            string.substring(with: match.range).contains(" ")
                ? groupRanges(in: match.range, of: string)
                : [match.range]
        }
    }

    private static func groupRanges(in range: NSRange, of string: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var location = range.location
        while location < NSMaxRange(range) {
            let space = string.range(
                of: " ",
                range: NSRange(location: location, length: NSMaxRange(range) - location)
            )
            let end = space.location == NSNotFound ? NSMaxRange(range) : space.location
            ranges.append(NSRange(location: location, length: end - location))
            location = end + 1
        }
        return ranges
    }

    private static func mask(for secret: SensitiveContentDetector.Secret) -> String {
        guard let ending = secret.cardNumberEnding else {
            return inlineMask
        }
        return "\(cardNumberMask) \(ending)"
    }

    // A row shows the beginning of the text only, so that is all it is searched
    // for secrets. The preview shows everything and searches much further.
    private static let itemCharacterLimit = 4_000
    static let previewCharacterLimit = 200_000
    // A secret that begins inside a limit may end after it, so the search goes
    // on this far past it. The longest tokens and keys are shorter.
    private static let straddlingMargin = 4_096

    /// The part of `text` to search when the first `limit` characters of it are
    /// shown. The whitespace a text begins with is not shown, so it does not
    /// count against the limit.
    private static func searchedText(_ text: String, limit: Int) -> String {
        let window = text.prefix(while: \.isWhitespace).count + limit + straddlingMargin
        // The byte count is known without walking through the text, and no text
        // has fewer bytes than characters.
        guard text.utf8.count > window else {
            return text
        }
        return String(text.prefix(window))
    }

    /// Puts the masks in place of `secrets` in a text of `length` characters,
    /// the last first so the ranges before it hold. `replace` does it for the
    /// kind of text at hand.
    private static func maskSecrets(
        _ secrets: [SensitiveContentDetector.Secret],
        inTextOfLength length: Int,
        replacing replace: (NSRange, String) -> Void
    ) {
        let bounds = NSRange(location: 0, length: length)
        for secret in secrets.reversed() {
            // A range outside the text would raise an exception.
            let clamped = NSIntersectionRange(secret.range, bounds)
            if clamped.length > 0 {
                replace(clamped, mask(for: secret))
            }
        }
    }

    static func isMasked(_ item: ClipboardItem, detectsAutomatically: Bool) -> Bool {
        guard item.kind.canHoldSensitiveContent else {
            return false
        }

        switch item.sensitivity {
        case .sensitive:
            return true
        case .notSensitive:
            return false
        case .none:
            guard detectsAutomatically else {
                return false
            }
            return !detectedSecrets(
                in: searchedText(item.previewText, limit: itemCharacterLimit),
                for: item
            ).isEmpty
        }
    }

    /// Whether the item holds a secret anywhere in its content, which decides
    /// whether it stays out of the history. What the user said about the item
    /// wins over what is found in it.
    static func containsSensitiveContent(_ item: ClipboardItem) -> Bool {
        guard item.kind.canHoldSensitiveContent else {
            return false
        }

        switch item.sensitivity {
        case .sensitive:
            return true
        case .notSensitive:
            return false
        case .none:
            // Each item is checked once here, so what is found is not
            // remembered for the rows.
            let detectsPasswordLikeText = item.kind == .text || item.kind == .richText
            return !SensitiveContentDetector.secrets(
                in: searchedText(item.previewText, limit: previewCharacterLimit),
                detectsPasswordLikeText: detectsPasswordLikeText
            ).isEmpty
        }
    }

    /// The text to show in place of `text`, which is the item's content or a
    /// part of it.
    static func maskedText(
        _ text: String,
        for item: ClipboardItem,
        detectsAutomatically: Bool,
        characterLimit: Int = itemCharacterLimit
    ) -> String {
        guard item.kind.canHoldSensitiveContent else {
            return text
        }

        switch item.sensitivity {
        case .sensitive:
            return wholeMask
        case .notSensitive:
            return text
        case .none:
            guard detectsAutomatically else {
                return text
            }

            let secrets = detectedSecrets(in: searchedText(text, limit: characterLimit), for: item)
            guard !secrets.isEmpty else {
                return text
            }

            let masked = NSMutableString(string: text)
            maskSecrets(secrets, inTextOfLength: masked.length) { masked.replaceCharacters(in: $0, with: $1) }
            return masked as String
        }
    }

    /// The formatted counterpart of `maskedText`, for rich text.
    static func maskedAttributedText(
        _ attributedText: NSAttributedString,
        for item: ClipboardItem,
        detectsAutomatically: Bool
    ) -> NSAttributedString {
        guard item.kind.canHoldSensitiveContent else {
            return attributedText
        }

        switch item.sensitivity {
        case .sensitive:
            let attributes = attributedText.length > 0
                ? attributedText.attributes(at: 0, effectiveRange: nil)
                : [:]
            return NSAttributedString(string: wholeMask, attributes: attributes)
        case .notSensitive:
            return attributedText
        case .none:
            guard detectsAutomatically else {
                return attributedText
            }

            // Only the preview shows rich text, so all of its reach is searched.
            let secrets = detectedSecrets(
                in: searchedText(attributedText.string, limit: previewCharacterLimit),
                for: item
            )
            guard !secrets.isEmpty else {
                return attributedText
            }

            let masked = NSMutableAttributedString(attributedString: attributedText)
            maskSecrets(secrets, inTextOfLength: masked.length) { masked.replaceCharacters(in: $0, with: $1) }
            return masked
        }
    }

    // Rows are configured again and again while the list scrolls and reloads,
    // so what was found in a text is remembered.
    private static let cache: NSCache<NSString, CachedSecrets> = {
        let cache = NSCache<NSString, CachedSecrets>()
        cache.countLimit = 2_000
        cache.totalCostLimit = 8_000_000
        return cache
    }()

    private final class CachedSecrets {
        let secrets: [SensitiveContentDetector.Secret]

        init(_ secrets: [SensitiveContentDetector.Secret]) {
            self.secrets = secrets
        }
    }

    private static func detectedSecrets(
        in text: String,
        for item: ClipboardItem
    ) -> [SensitiveContentDetector.Secret] {
        // A link or an email address is one token by nature, so only text is
        // checked for being a password as a whole.
        let detectsPasswordLikeText = item.kind == .text || item.kind == .richText
        let key = "\(detectsPasswordLikeText ? 1 : 0)\(text)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached.secrets
        }

        let secrets = SensitiveContentDetector.secrets(
            in: text,
            detectsPasswordLikeText: detectsPasswordLikeText
        )
        cache.setObject(CachedSecrets(secrets), forKey: key, cost: key.length)
        return secrets
    }
}

/// How an item with sensitive content is shown at the moment.
struct SensitiveContentPresentation: Equatable {
    static let none = SensitiveContentPresentation(isMasked: false, isRevealed: false)

    /// The item has content to hide.
    var isMasked: Bool
    /// The user asked to see it for now.
    var isRevealed: Bool

    var hidesContent: Bool {
        isMasked && !isRevealed
    }
}

extension ClipboardKind {
    /// The kinds whose content is text the history shows as it is.
    var canHoldSensitiveContent: Bool {
        switch self {
        case .text, .richText, .link, .email:
            return true
        case .color, .image, .file:
            return false
        }
    }
}

/// Finds the parts of a text that look like a secret. It prefers missing a
/// secret to hiding ordinary text, because the user can always hide an item by
/// hand, while text that is hidden for no reason gets in the way every time.
enum SensitiveContentDetector {
    struct Secret {
        var range: NSRange
        /// The last four digits of a secret that is a card number.
        var cardNumberEnding: String?
    }

    /// The secrets in `text`, in order and without overlaps.
    static func secrets(in text: String, detectsPasswordLikeText: Bool) -> [Secret] {
        let string = text as NSString
        guard string.length > 0 else {
            return []
        }

        let fullRange = NSRange(location: 0, length: string.length)
        var ranges: [NSRange] = []
        var cardNumbers: [Secret] = []

        for expression in tokenExpressions {
            expression.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                if let match {
                    ranges.append(match.range)
                }
            }
        }

        urlPasswordExpression.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            if let range = match?.range(at: 1), range.location != NSNotFound {
                ranges.append(range)
            }
        }

        authorizationExpression.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let range = match?.range(at: 1), range.location != NSNotFound,
                  containsDigit(string.substring(with: range)) else {
                return
            }
            ranges.append(range)
        }

        // The value of a name in the query or the fragment of a URL ends where the
        // next parameter begins, which a value anywhere else does not. Each kind
        // has a pattern of its own: one that took the "&" into the value would
        // swallow the parameters after it, and one that left it out would not
        // match a password such as "P&ss1234".
        let hasQuerySeparator = string.rangeOfCharacter(from: Self.querySeparators).location != NSNotFound
        for (expression, isQuery) in [(assignmentExpression, false), (queryAssignmentExpression, true)]
        where !isQuery || hasQuerySeparator {
            expression.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                // The value is in the group of the way it is written: in double
                // quotes, in single quotes or bare.
                guard let match,
                      match.range(at: 1).location != NSNotFound,
                      let valueRange = (2...4).map(match.range(at:)).first(where: { $0.location != NSNotFound }) else {
                    return
                }

                let nameRange = match.range(at: 1)
                let isBare = match.range(at: 4).location != NSNotFound
                let nameStart = startOfName(endingAt: nameRange.location, in: string)
                let isQueryParameter = isBare && nameStart > 0
                    && "?&#".contains(string.substring(with: string.rangeOfComposedCharacterSequence(at: nameStart - 1)))
                guard isQueryParameter == isQuery else {
                    return
                }

                let name = string.substring(with: nameRange).lowercased()
                let value = string.substring(with: valueRange)
                if value.count >= 4, isSecretValue(value, assignedTo: name) {
                    ranges.append(valueRange)
                }
            }
        }

        cardNumberExpression.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let match else {
                return
            }
            let candidate = string.substring(with: match.range)
            guard isCardNumber(candidate) else {
                return
            }
            let ending = String(candidate.filter { $0.wholeNumberValue != nil }.suffix(4))
            cardNumbers.append(Secret(range: match.range, cardNumberEnding: ending))
        }

        if detectsPasswordLikeText, ranges.isEmpty, cardNumbers.isEmpty {
            let trimmedRange = string.rangeOfTrimmedContent
            if trimmedRange.length > 0, isPasswordLike(string.substring(with: trimmedRange)) {
                ranges.append(trimmedRange)
            }
        }

        return merged(ranges.map { Secret(range: $0) } + cardNumbers)
    }

    // MARK: - Patterns

    // Tokens that say what they are with a prefix or a shape of their own.
    private static let tokenExpressions: [NSRegularExpression] = [
        // OpenAI, Anthropic
        #"\bsk-[A-Za-z0-9_\-]{20,}"#,
        // GitHub
        #"\bgh[pousr]_[A-Za-z0-9]{36,}"#,
        #"\bgithub_pat_[A-Za-z0-9_]{22,}"#,
        // GitLab
        #"\bglpat-[A-Za-z0-9_\-]{20,}"#,
        // AWS access key ID
        #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#,
        // Slack
        #"\bxox[abposr]-[A-Za-z0-9\-]{10,}"#,
        // Google API key
        #"\bAIza[0-9A-Za-z_\-]{35}"#,
        // Stripe secret and restricted keys
        #"\b[sr]k_(?:live|test)_[0-9A-Za-z]{16,}"#,
        // SendGrid
        #"\bSG\.[A-Za-z0-9_\-]{16,}\.[A-Za-z0-9_\-]{16,}"#,
        // npm
        #"\bnpm_[A-Za-z0-9]{36,}"#,
        // Hugging Face
        #"\bhf_[A-Za-z0-9]{30,}"#,
        // JSON Web Token
        #"\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]*"#,
        // Private key block, to its end or to the end of the text
        #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|\z)"#
    ].map(makeExpression)

    // The password in scheme://user:password@host
    private static let urlPasswordExpression = makeExpression(
        #"://[^\s/:@]+:([^\s/@]{3,})@"#
    )

    private static let authorizationExpression = makeExpression(
        #"(?i)(?:\bbearer|\bauthorization\s*:\s*basic)\s+([A-Za-z0-9_\-.=+/]{16,})"#
    )

    // name = value, name: value and "name": "value", where the name says the
    // value is a secret. The pattern starts at the word that says so, and the
    // beginning of the name is found by hand: a pattern that starts with the
    // rest of the name takes a time that grows with the square of the length
    // of a long run of letters and digits, such as encoded data.
    private static func makeAssignmentExpression(bareValue: String) -> NSRegularExpression {
        makeExpression(
            #"(?i)((?:password|passwd|passphrase|pwd|secret|token|api[_\-]?key|access[_\-]?key|private[_\-]?key|credential)"#
                + #"[A-Za-z0-9_\-]*)["']?\s*[:=]\s*(?:"([^"\n]{4,})"|'([^'\n]{4,})'|("# + bareValue + #"))"#
        )
    }

    // Anywhere but in the query of a URL a bare value runs to the next space
    // or quote, so "P&ss1234" and "ab#cdefgh" are whole. A "&" that starts the
    // next field of a form body, as in "password=hunter22&remember=1", ends it.
    private static let assignmentExpression = makeAssignmentExpression(
        bareValue: #"(?:[^\s"',;&]|&(?![A-Za-z0-9_\-]+=)){4,}"#
    )

    // In the query or the fragment of a URL a bare value ends at "&" or "#".
    private static let querySeparators = CharacterSet(charactersIn: "?&#")
    private static let queryAssignmentExpression = makeAssignmentExpression(bareValue: #"[^\s"',;&#]{4,}"#)

    private static let cardNumberExpression = makeExpression(#"(?<![\d.])[3-6]\d(?:[ \-]?\d){11,17}(?![\d.])"#)

    private static func makeExpression(_ pattern: String) -> NSRegularExpression {
        // The patterns are constants, so one that does not compile is a
        // programming error.
        try! NSRegularExpression(pattern: pattern)
    }

    // MARK: - Checks

    private static let passwordNames = ["password", "passwd", "passphrase", "pwd"]

    // What code and documentation put where a secret would be.
    private static let placeholderValues: Set<String> = [
        "true", "false", "null", "nil", "none", "undefined", "string", "str", "text",
        "varchar", "char", "bool", "boolean", "int", "integer", "data", "optional",
        "required", "self", "this", "password", "secret", "token", "changeme", "example"
    ]

    private static func isSecretValue(_ value: String, assignedTo name: String) -> Bool {
        let lowercasedValue = value.lowercased()
        guard !placeholderValues.contains(lowercasedValue.trimmingCharacters(in: .punctuationCharacters)),
              // A call, a property, a variable or a template stands for a
              // secret that is somewhere else.
              value.rangeOfCharacter(from: CharacterSet(charactersIn: "()[]{}<>")) == nil,
              !value.hasPrefix("$"), !value.hasPrefix("%"),
              !lowercasedValue.hasPrefix("env."),
              !lowercasedValue.contains("process.env") else {
            return false
        }

        // People type passwords, so any word may be one. Keys and tokens are
        // generated, and a value without a digit is more likely a name or a
        // type next to a field that happens to be called "token".
        if passwordNames.contains(where: { name.contains($0) }) {
            return true
        }

        return value.count >= 6
            && containsDigit(value)
            && !value.allSatisfy { $0.isNumber || $0 == "." }
    }

    private static let nameCharacters = CharacterSet(charactersIn: "_-").union(.alphanumerics)
    private static let maximumNameLength = 64

    /// Where the name that ends with the word at `location` begins.
    private static func startOfName(endingAt location: Int, in string: NSString) -> Int {
        var start = location
        while start > 0, location - start < maximumNameLength {
            let charRange = string.rangeOfComposedCharacterSequence(at: start - 1)
            let scalars = string.substring(with: charRange).unicodeScalars
            guard scalars.count == 1, let scalar = scalars.first, nameCharacters.contains(scalar) else {
                break
            }
            start = charRange.location
        }
        return start
    }

    private static func containsDigit(_ value: String) -> Bool {
        value.contains { $0.isASCII && $0.isNumber }
    }

    private static func isCardNumber(_ candidate: String) -> Bool {
        let digits = candidate.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else {
            return false
        }

        // The Luhn checksum every payment card number passes.
        var sum = 0
        for (index, digit) in digits.reversed().enumerated() {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }
        return sum % 10 == 0
    }

    /// True for a single word that reads as a password someone made up or
    /// generated, rather than as a name, a version or a file.
    private static func isPasswordLike(_ text: String) -> Bool {
        guard (8...64).contains(text.count),
              text.allSatisfy({ $0.isASCII && !$0.isWhitespace }),
              text.contains(where: \.isLowercase),
              text.contains(where: \.isUppercase),
              containsDigit(text),
              !looksLikeCode(text) else {
            return false
        }

        // Made up: all four kinds of characters, the way password rules ask.
        // A generator may throw in a slash, a backslash or a colon as well, so
        // only a word built like a path or an address is left alone.
        if text.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*?~")) != nil {
            return !looksLikePath(text)
        }

        // Generated: digits scattered among the letters. A name with a number
        // in it, such as "Report2024Final", keeps its digits together. Without
        // a symbol to tell it apart, a word with a slash, a backslash or a
        // colon is taken for a path, a time or a key fingerprint.
        return text.count >= 12
            && digitRunCount(in: text) >= 3
            && text.rangeOfCharacter(from: CharacterSet(charactersIn: "\\/:")) == nil
    }

    // A path or an address has its separators in a pattern: a scheme before
    // "://", a drive letter before ":\", or the same separator more than once.
    private static func looksLikePath(_ text: String) -> Bool {
        if text.contains("://") || text.range(of: #"^[A-Za-z]:[\\/]"#, options: .regularExpression) != nil {
            return true
        }

        return "/\\:".contains { separator in
            text.filter { $0 == separator }.count >= 2
        }
    }

    // A password generator picks brackets and quotes one at a time, so they
    // rarely come in pairs. Code opens what it closes: a call, a subscript,
    // a string.
    private static let pairedDelimiters: [(Character, Character)] = [
        ("(", ")"), ("[", "]"), ("{", "}"), ("<", ">")
    ]

    private static func looksLikeCode(_ text: String) -> Bool {
        if pairedDelimiters.contains(where: { text.contains($0.0) && text.contains($0.1) }) {
            return true
        }

        return "\"'`".contains { quote in
            text.filter { $0 == quote }.count >= 2
        }
    }

    private static func digitRunCount(in text: String) -> Int {
        var count = 0
        var isInsideRun = false
        for character in text {
            let isDigit = character.isNumber
            if isDigit, !isInsideRun {
                count += 1
            }
            isInsideRun = isDigit
        }
        return count
    }

    private static func merged(_ secrets: [Secret]) -> [Secret] {
        let sorted = secrets
            .filter { $0.range.length > 0 }
            .sorted { $0.range.location < $1.range.location }
        var result: [Secret] = []
        for secret in sorted {
            guard let last = result.last, secret.range.location <= NSMaxRange(last.range) else {
                result.append(secret)
                continue
            }

            // A card number keeps its ending only while nothing around it is
            // hidden with it, such as the value of a "password" that is the
            // card number itself.
            let union = NSUnionRange(last.range, secret.range)
            let ending = [last, secret]
                .first { $0.range == union && $0.cardNumberEnding != nil }?
                .cardNumberEnding
            result[result.count - 1] = Secret(range: union, cardNumberEnding: ending)
        }
        return result
    }
}

private extension NSString {
    var rangeOfTrimmedContent: NSRange {
        let visibleCharacters = CharacterSet.whitespacesAndNewlines.inverted
        let first = rangeOfCharacter(from: visibleCharacters)
        guard first.location != NSNotFound else {
            return NSRange(location: 0, length: 0)
        }

        let last = rangeOfCharacter(from: visibleCharacters, options: .backwards)
        return NSRange(location: first.location, length: NSMaxRange(last) - first.location)
    }
}
