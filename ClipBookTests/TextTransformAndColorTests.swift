@testable import ClipBook
import Foundation
import Testing

@Suite
enum TextTransformAndColorTests {
    @Suite
    struct TextTransformTests {
        /// One transform applied to one input, and the text it must produce.
        struct Row: Sendable, CustomTestStringConvertible {
            let transform: ClipboardTextTransform
            let input: String
            let expected: String

            init(_ transform: ClipboardTextTransform, _ input: String, _ expected: String) {
                self.transform = transform
                self.input = input
                self.expected = expected
            }

            var testDescription: String { "\(transform) \(input.debugDescription)" }
        }

        private static let trimmingRows = [
            Row(.trimTrailingNewlines, "\n\n  hello world\n\n", "  hello world"),
            Row(.trimTrailingSpaces, "   hello world   \t ", "hello world"),
            Row(.trimLeadingWhitespaces, "   first\n\t\tsecond", "first\nsecond"),
            Row(.trimTrailingSpacesAllLines, "first   \n  second \t ", "first\n  second"),
            Row(.trimSurroundingWhitespaces, " \n  hello \t\n ", "hello"),
        ]

        private static let htmlDecodeRows = [
            Row(.htmlDecode, "&amp;#65;", "&#65;"),
            Row(.htmlDecode, "&amp;#x41;", "&#x41;"),
            Row(.htmlDecode, "&amp;lt;script&amp;gt;", "&lt;script&gt;"),
            Row(.htmlDecode, "&#65;&#x42;&#x63;", "ABc"),
            Row(
                .htmlDecode,
                "Hello&nbsp;World &mdash; 2026 &ndash; &copy; &reg; &trade; &hellip;",
                "Hello\u{00A0}World \u{2014} 2026 \u{2013} \u{00A9} \u{00AE} \u{2122} \u{2026}"
            ),
            Row(
                .htmlDecode,
                "&lsquo;single&rsquo; &amp; &ldquo;double&rdquo; &bull; &quot;q&quot; &apos;a&apos; &#39;s&#39;",
                "\u{2018}single\u{2019} & \u{201C}double\u{201D} \u{2022} \"q\" 'a' 's'"
            ),
            Row(.htmlDecode, "&#38;lt;", "&lt;"),
            Row(.htmlDecode, "&#x26;gt;", "&gt;"),
            Row(.htmlDecode, "&amp;#60;", "&#60;"),
            Row(.htmlDecode, "&amp;amp;", "&amp;"),
            Row(.htmlDecode, "&#38;#65;", "&#65;"),
            Row(.htmlDecode, "&unknown; &#xZZ; &#55296;", "&unknown; &#xZZ; &#55296;"),
        ]

        private static let identifierRows: [Row] = [
            ("HTMLParser", [
                (ClipboardTextTransform.camelCase, "htmlParser"),
                (.pascalCase, "HtmlParser"),
                (.snakeCase, "html_parser"),
                (.kebabCase, "html-parser"),
                (.screamingSnakeCase, "HTML_PARSER"),
                (.dotCase, "html.parser"),
            ]),
            ("XMLHttpRequest", [
                (ClipboardTextTransform.camelCase, "xmlHttpRequest"),
                (.pascalCase, "XmlHttpRequest"),
                (.snakeCase, "xml_http_request"),
                (.kebabCase, "xml-http-request"),
                (.screamingSnakeCase, "XML_HTTP_REQUEST"),
                (.dotCase, "xml.http.request"),
            ]),
        ].flatMap { input, outputs in outputs.map { Row($0.0, input, $0.1) } }

        private static let otherRows = [
            Row(.extractNumbers, "Date: 2026-10-30", "2026\n10\n30"),
            Row(.extractNumbers, "Encoding UTF-8 and ISO-8859-1", "8\n8859\n1"),
            Row(.extractNumbers, "Release v1.2.3", "1.2\n3"),
            Row(.extractNumbers, "Delta -42.5 and +.75 and -0.5", "-42.5\n.75\n-0.5"),
            Row(
                .stripMarkdown,
                "Call `my_function_name` in ~/Library/Preferences with 2 * 3 = 6",
                "Call my_function_name in ~/Library/Preferences with 2 * 3 = 6"
            ),
            Row(
                .stripMarkdown,
                "# Heading\n**Bold** and *italic* and _underlined_ and ~~struck~~ [Link](https://example.com)",
                "Heading\nBold and italic and underlined and struck Link"
            ),
            Row(.normalizeWhitespace, "hello   world\n\tnext", "hello world next"),
            Row(.addBullets, "apples, bananas, cherries", "- apples\n- bananas\n- cherries"),
            Row(.hexDecode, "48656c6c6f", "Hello"),
            Row(.base64Decode, Data("ClipBook".utf8).base64EncodedString(), "ClipBook"),
        ]

        @Test(arguments: trimmingRows + htmlDecodeRows + identifierRows + otherRows)
        func transformRewritesTextAsExpected(row: Row) {
            #expect(row.transform.apply(to: row.input) == row.expected)
        }

        @Test
        func everyTransformHasAUniqueTitleAndDescription() {
            let allCases = ClipboardTextTransform.allCases
            #expect(!allCases.isEmpty)
            #expect(ClipboardTextTransform.sortedCases.count == allCases.count)
            #expect(Set(ClipboardTextTransform.sortedCases) == Set(allCases))

            let titles = allCases.map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            let descriptions = allCases.map { $0.description.trimmingCharacters(in: .whitespacesAndNewlines) }
            #expect(!titles.contains { $0.isEmpty })
            #expect(!descriptions.contains { $0.isEmpty })
            #expect(Set(titles).count == allCases.count, "transform titles must be unique")
            #expect(Set(descriptions).count == allCases.count, "transform descriptions must be unique")
        }

        /// Random transforms and the extractors, which return nothing when the sample has no match, are covered elsewhere.
        @Test(arguments: ClipboardTextTransform.allCases.filter {
            ![.generateUUID, .shuffleLines, .extractEmails, .extractURLs].contains($0)
        })
        func deterministicTransformsAreRepeatableAndHandleEmptyText(transform: ClipboardTextTransform) {
            let sample = "Hello, World!\nSecond line 123"
            let output = transform.apply(to: sample)
            #expect(output == transform.apply(to: sample), "\(transform) must be deterministic")
            #expect(!output.isEmpty, "\(transform) should produce output for non-empty text")
            _ = transform.apply(to: "")
        }

        @Test
        func generateUUIDProducesAFreshUUIDEachTime() {
            let first = ClipboardTextTransform.generateUUID.apply(to: "ignored")
            let second = ClipboardTextTransform.generateUUID.apply(to: "ignored")
            #expect(UUID(uuidString: first) != nil)
            #expect(UUID(uuidString: second) != nil)
            #expect(first != second)
        }

        @Test
        func shuffleLinesKeepsEveryLine() {
            let shuffled = ClipboardTextTransform.shuffleLines.apply(to: "alpha\nbeta\ngamma")
            #expect(shuffled.components(separatedBy: "\n").sorted() == ["alpha", "beta", "gamma"])
        }
    }

    @Suite
    struct ColorTextTests {
        /// A color text and the components it must parse to.
        struct Row: Sendable, CustomTestStringConvertible {
            let input: String
            let red: Double
            let green: Double
            let blue: Double
            var alpha = 1.0
            var tolerance = 0.01
            var allowsBareHex = false

            var testDescription: String { input.debugDescription }
        }

        private static let half = 128.0 / 255.0

        private static let parsedRows = [
            Row(input: "#ff8000", red: 1, green: half, blue: 0),
            Row(input: "#ff000080", red: 1, green: 0, blue: 0, alpha: half),
            Row(input: "ff8000", red: 1, green: half, blue: 0, allowsBareHex: true),
            Row(input: "rgb(255, 0, 128)", red: 1, green: 0, blue: half),
            Row(input: "rgba(100%, 50%, 0%, 25%)", red: 1, green: 0.5, blue: 0, alpha: 0.25),
            Row(input: "rgb(255 128 0 / 0.5)", red: 1, green: half, blue: 0, alpha: 0.5),
            Row(input: "rgb(\n  255,\n  0,\n  128\n)", red: 1, green: 0, blue: half),
            Row(input: "hsl(0, 200%, 150%)", red: 1, green: 1, blue: 1),
            Row(input: "hsl(0, 200%, -50%)", red: 0, green: 0, blue: 0),
            Row(input: "hsl(0, 200%, 50%)", red: 1, green: 0, blue: 0),
            Row(input: "hsla(\n  120deg,\n  100%,\n  50%,\n  0.75\n)", red: 0, green: 1, blue: 0, alpha: 0.75),
            Row(input: "hsl(200grad 100% 50%)", red: 0, green: 1, blue: 1),
            Row(input: "hsl(0.5turn 100% 50%)", red: 0, green: 1, blue: 1),
            Row(input: "hsl(\(Double.pi)rad 100% 50%)", red: 0, green: 1, blue: 1),
            Row(input: "hsl(-120deg 100% 50%)", red: 0, green: 0, blue: 1),
            Row(input: "hwb(0 0% 0%)", red: 1, green: 0, blue: 0),
            Row(input: "hwb(0 50% 50%)", red: 0.5, green: 0.5, blue: 0.5),
            Row(input: "lab(100% 0 0)", red: 1, green: 1, blue: 1, tolerance: 0.02),
            Row(input: "lch(0% 0 none)", red: 0, green: 0, blue: 0, tolerance: 0.02),
            Row(input: "oklab(1 0 0)", red: 1, green: 1, blue: 1, tolerance: 0.02),
            Row(input: "oklch(0 0 0deg / 50%)", red: 0, green: 0, blue: 0, alpha: 0.5, tolerance: 0.02),
        ]

        @Test(arguments: [
            (input: "ff8000", allowsBareHex: false),
            (input: "#fff", allowsBareHex: true),
            (input: "#gggggg", allowsBareHex: true),
            (input: "oklch(0.7, 0.2, 120deg)", allowsBareHex: false),
            (input: "rgb(255, 0, none)", allowsBareHex: false),
            (input: "unknown(1, 2, 3)", allowsBareHex: false),
        ])
        func rejectsTextThatIsNotAColor(input: String, allowsBareHex: Bool) {
            #expect(ColorText(input, allowsBareHex: allowsBareHex) == nil)
        }
    }
}
