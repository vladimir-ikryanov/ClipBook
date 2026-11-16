@testable import ClipBook
import AppKit
import Foundation
import Testing

@Suite
struct SearchPipelineTests {
    @Test
    func searchTermsTokenizationAndASCIIClassification() {
        let empty = HistorySearchTerms(query: "   \n\t  ")
        #expect(empty.isEmpty)
        #expect(empty.values.isEmpty)
        #expect(empty.asciiTerms.isEmpty)

        let terms = HistorySearchTerms(query: "  Alpha\t9[\nCafé  \r\nv2_beta ")
        #expect(!terms.isEmpty)
        #expect(terms.values == ["Alpha", "9[", "Café", "v2_beta"])
        #expect(terms.asciiTerms.count == 4)

        #expect(terms.asciiTerms[0]?.lowercasedBytes == Array("alpha".utf8))
        #expect(terms.asciiTerms[0]?.containsDigit == false)

        #expect(terms.asciiTerms[1]?.lowercasedBytes == Array("9[".utf8))
        #expect(terms.asciiTerms[1]?.containsDigit == true)

        #expect(terms.asciiTerms[2] == nil)

        #expect(terms.asciiTerms[3]?.lowercasedBytes == Array("v2_beta".utf8))
        #expect(terms.asciiTerms[3]?.containsDigit == true)

        let withNUL = HistorySearchTerms(values: ["ab\0cd", "plain\u{7F}"])
        #expect(withNUL.asciiTerms[0] == nil)
        #expect(withNUL.asciiTerms[1] == nil)

        #expect(HistorySearchTerms(query: "foo   bar") == HistorySearchTerms(query: "foo bar"))
        #expect(HistorySearchTerms(query: "foo bar") != HistorySearchTerms(query: "FOO bar"))
    }

    @Test
    func matcherParityWithFoundationAcrossScriptsSymbolsAndLocales() {
        let locales = [
            Locale(identifier: "en_US"),
            Locale(identifier: "tr_TR"),
            Locale(identifier: "az"),
            Locale(identifier: "de_DE"),
            Locale(identifier: "da_DK"),
            Locale(identifier: "es_ES")
        ]

        let haystacks = [
            "",
            "Hello World ClipBook 2026",
            "Café",
            "Cafe\u{0301}",
            "ca\u{0301}fe",
            "cafe",
            "año",
            "an\u{0303}o",
            "ano",
            "Søren Łódź Æther Œuvre Straße ø ł æ œ ß",
            "a≠b",
            "a≮b",
            "a≯b",
            "a\u{00AD}b",
            "한글 테스트",
            "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF} 테스트",
            "東京タワー 🚀 ClipBook",
            "日本語テキスト ✨",
            "abc\0def",
            "İstanbul ışık İSTANBUL I\u{0307}stanbul IŞIK",
            "Aalborg Ålborg llama chico",
            "東京 9[ café",
            "東京 ９[ café",
            "한글 99 test",
            "résumé ٤٢ 9["
        ]

        let queries = [
            "",
            "   ",
            "hello",
            "HELLO world",
            "hello mars",
            "cafe",
            "café",
            "Cafe\u{0301}",
            "ca\u{0301}fe",
            "ano",
            "año",
            "an\u{0303}o",
            "o",
            "ø",
            "l",
            "ł",
            "ae",
            "æ",
            "oe",
            "œ",
            "ss",
            "ß",
            "s",
            "=",
            "a=b",
            "!=",
            "<=",
            "<",
            ">",
            "≠",
            "ab",
            "a\u{00AD}b",
            "한글",
            "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}",
            "東京",
            "🚀",
            "东京",
            "abc",
            "def",
            "c\0d",
            "abcdef",
            "istanbul",
            "İstanbul",
            "ışık",
            "i",
            "I",
            "aa",
            "å",
            "ll",
            "ch",
            "9[",
            "9",
            "42",
            "東京 9["
        ]

        for locale in locales {
            for haystack in haystacks {
                for query in queries {
                    let terms = HistorySearchTerms(query: query)
                    let actual = HistorySearchMatcher.matches(haystack, terms, locale: locale)
                    let expected = terms.values.allSatisfy { term in
                        haystack.range(
                            of: term,
                            options: [.caseInsensitive, .diacriticInsensitive],
                            range: nil,
                            locale: locale
                        ) != nil
                    }
                    #expect(
                        actual == expected,
                        "Mismatch for locale=\(locale.identifier) haystack=\(String(reflecting: haystack)) query=\(String(reflecting: query)): got \(actual), expected \(expected)"
                    )
                }
            }
        }
    }

    @Test
    func matcherAndHighlighterAgreeAcrossMultiWordAndDiacriticQueries() {
        let font = NSFont.systemFont(ofSize: 13)
        let baseColor = NSColor.labelColor
        let highlightColor = HistorySearchMatchHighlighter.highlightColor
        let locale = Locale.current

        let samples = [
            "Café résumé naïve world",
            "Feliz año nuevo 2026",
            "Plain ASCII alpha beta gamma",
            "東京タワー ClipBook 🚀",
            "a\u{00AD}b soft hyphen"
        ]
        let singleTermQueries = ["cafe", "résumé", "ano", "alpha", "9[", "東京", "ab", "missing"]
        let multiTermQueries = ["cafe world", "resume naive", "alpha gamma", "cafe missing", "feliz ano"]

        func hasHighlightedCharacter(in attributed: NSAttributedString) -> Bool {
            var found = false
            attributed.enumerateAttribute(
                .foregroundColor,
                in: NSRange(location: 0, length: attributed.length)
            ) { value, _, stop in
                if (value as? NSColor) == highlightColor {
                    found = true
                    stop.pointee = true
                }
            }
            return found
        }

        for text in samples {
            for query in singleTermQueries {
                let terms = HistorySearchTerms(query: query)
                let matched = HistorySearchMatcher.matches(text, terms, locale: locale)
                let attributed = HistorySearchMatchHighlighter.attributedString(
                    text: text,
                    font: font,
                    textColor: baseColor,
                    searchQuery: query
                )
                #expect(
                    hasHighlightedCharacter(in: attributed) == matched,
                    "Single-term highlighter disagreement for text=\(text) query=\(query)"
                )
            }

            for query in multiTermQueries {
                let terms = HistorySearchTerms(query: query)
                let matched = HistorySearchMatcher.matches(text, terms, locale: locale)
                let attributed = HistorySearchMatchHighlighter.attributedString(
                    text: text,
                    font: font,
                    textColor: baseColor,
                    searchQuery: query
                )
                if matched {
                    #expect(hasHighlightedCharacter(in: attributed))
                    let nsText = text as NSString
                    for term in terms.values {
                        let range = nsText.range(
                            of: term,
                            options: HistorySearchMatcher.compareOptions,
                            range: NSRange(location: 0, length: nsText.length),
                            locale: locale
                        )
                        #expect(range.location != NSNotFound)
                        if range.location != NSNotFound {
                            let color = attributed.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor
                            #expect(color == highlightColor)
                        }
                    }
                }
            }
        }
    }

    @Test
    func searchCorpusCancellationAndPrefixRefinementBitmapReuse() throws {
        let locale = Locale(identifier: "en_US")
        let texts = [
            "alpha beta",
            "delta epsilon",
            "Àlpha diacritic",
            "alpaca farm",
            "unrelated ascii row",
            "ALPHA2 digit suffix",
            "Æther",
            "ﬁlter ligature",
            "Straße",
            "Maß"
        ]
        let ids = texts.map { _ in UUID() }
        let corpus = HistorySearchCorpus(revision: 7, ids: ids, texts: texts)

        let cancelledJob = HistorySearchJob()
        cancelledJob.cancel()
        #expect(cancelledJob.isCancelled)
        #expect(cancelledJob.run(corpus: corpus, terms: HistorySearchTerms(query: "alp"), locale: locale) == nil)

        let initialJob = HistorySearchJob()
        let initialResult = try #require(
            initialJob.run(corpus: corpus, terms: HistorySearchTerms(query: "alp"), locale: locale)
        )
        #expect(initialResult.matches == [true, false, true, true, false, true, false, false, false, false])
        #expect(initialResult.matchCount == 4)
        #expect(initialResult.indexByID.count == texts.count)

        // Strict ASCII prefix refinement ("alp" -> "alpha") reuses previous bitmap for ASCII misses
        // while still matching non-ASCII "Àlpha diacritic".
        let refinedJob = HistorySearchJob()
        let refinedResult = try #require(
            refinedJob.run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "alpha"),
                locale: locale,
                previous: initialResult
            )
        )
        #expect(refinedResult.matches == [true, false, true, false, false, true, false, false, false, false])
        #expect(refinedResult.matchCount == 3)
        #expect(refinedResult.indexByID == initialResult.indexByID)

        // Foundation parity on "Æther" ("a" -> "ae"), plus true `false -> true` prefix-refinement
        // transitions on non-ASCII ligature "ﬁlter" ("f" -> "fi") and sharp-s "Maß" ("s" -> "ss")
        // / "Straße" ("stras" -> "strass"), exercising HistorySearchCorpus's non-ASCII re-evaluation path.
        let aResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: HistorySearchTerms(query: "a"), locale: locale)
        )
        #expect(aResult.matches[6] == false)
        let aeResult = try #require(
            HistorySearchJob().run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "ae"),
                locale: locale,
                previous: aResult
            )
        )
        #expect(
            aeResult.matches[6]
                == ("Æther".range(of: "ae", options: HistorySearchMatcher.compareOptions, locale: locale) != nil)
        )

        let fResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: HistorySearchTerms(query: "f"), locale: locale)
        )
        #expect(fResult.matches[7] == false)
        let fiResult = try #require(
            HistorySearchJob().run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "fi"),
                locale: locale,
                previous: fResult
            )
        )
        #expect(fiResult.matches[7] == true)

        let sResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: HistorySearchTerms(query: "s"), locale: locale)
        )
        #expect(sResult.matches[9] == false)
        let ssResult = try #require(
            HistorySearchJob().run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "ss"),
                locale: locale,
                previous: sResult
            )
        )
        #expect(ssResult.matches[8] == true)
        #expect(ssResult.matches[9] == true)

        let strasResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: HistorySearchTerms(query: "stras"), locale: locale)
        )
        #expect(strasResult.matches[8] == false)
        let strassResult = try #require(
            HistorySearchJob().run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "strass"),
                locale: locale,
                previous: strasResult
            )
        )
        #expect(strassResult.matches[8] == true)

        // Non-prefix query ("delta") must not skip rows that were false in `initialResult`.
        let disjointJob = HistorySearchJob()
        let disjointResult = try #require(
            disjointJob.run(
                corpus: corpus,
                terms: HistorySearchTerms(query: "delta"),
                locale: locale,
                previous: initialResult
            )
        )
        #expect(disjointResult.matches == [false, true, false, false, false, false, false, false, false, false])
        #expect(disjointResult.matchCount == 1)

        // Danish (`da_DK`): verifies Foundation parity on "a" -> "aa" refinement across ICU versions
        // (including the `false -> true` transition on "Aalborg"/"Ålborg" when ICU contracts "aa").
        let daLocale = Locale(identifier: "da_DK")
        let daTexts = ["Aalborg", "Ålborg", "plain"]
        let daCorpus = HistorySearchCorpus(revision: 8, ids: daTexts.map { _ in UUID() }, texts: daTexts)
        let daAResult = try #require(
            HistorySearchJob().run(corpus: daCorpus, terms: HistorySearchTerms(query: "a"), locale: daLocale)
        )
        let expectedDaA = daTexts.map {
            $0.range(of: "a", options: HistorySearchMatcher.compareOptions, locale: daLocale) != nil
        }
        #expect(daAResult.matches == expectedDaA)
        let daAAResult = try #require(
            HistorySearchJob().run(
                corpus: daCorpus,
                terms: HistorySearchTerms(query: "aa"),
                locale: daLocale,
                previous: daAResult
            )
        )
        let expectedDaAA = daTexts.map {
            $0.range(of: "aa", options: HistorySearchMatcher.compareOptions, locale: daLocale) != nil
        }
        #expect(daAAResult.matches == expectedDaAA)
        if "aa".range(of: "a", options: HistorySearchMatcher.compareOptions, locale: daLocale) == nil {
            #expect(daAResult.matches == [false, false, true])
            #expect(daAAResult.matches == [true, true, false])
        }

        // Turkish (`tr_TR`): dotted/dotless I folding disables the ASCII prefilter and matches Foundation parity.
        let trLocale = Locale(identifier: "tr_TR")
        let trTexts = ["İstanbul", "I\u{0307}stanbul", "ISPARTA", "ısparta", "isparta", "plain"]
        let trCorpus = HistorySearchCorpus(revision: 9, ids: trTexts.map { _ in UUID() }, texts: trTexts)
        let trIResult = try #require(
            HistorySearchJob().run(corpus: trCorpus, terms: HistorySearchTerms(query: "i"), locale: trLocale)
        )
        let expectedTrI = trTexts.map {
            $0.range(of: "i", options: HistorySearchMatcher.compareOptions, locale: trLocale) != nil
        }
        #expect(trIResult.matches == expectedTrI)
        let trIsResult = try #require(
            HistorySearchJob().run(
                corpus: trCorpus,
                terms: HistorySearchTerms(query: "is"),
                locale: trLocale,
                previous: trIResult
            )
        )
        let expectedTrIs = trTexts.map {
            $0.range(of: "is", options: HistorySearchMatcher.compareOptions, locale: trLocale) != nil
        }
        #expect(trIsResult.matches == expectedTrIs)

        // Multi-chunk corpus (`count > 512`, `checkStride = 64`) containing `> 400`-byte non-ASCII
        // matching entries (`warmUpFontCascadeIfNeeded`) matches Foundation parity.
        let longNonASCIIMatch = "東京タワー ✨\n" + String(repeating: "日本語テキスト needle cascade ", count: 24)
        #expect(longNonASCIIMatch.utf8.count > 400)
        let largeTexts: [String] = (0..<600).map { index in
            switch index {
            case 17, 305, 589:
                return "\(longNonASCIIMatch) #\(index)"
            case 42, 411:
                return "Àlpha needle diacritic row \(index)"
            case 128, 512:
                return "ascii needle row \(index)"
            default:
                return "unmatched filler entry \(index)"
            }
        }
        let largeCorpus = HistorySearchCorpus(
            revision: 10,
            ids: largeTexts.map { _ in UUID() },
            texts: largeTexts
        )
        let largeNeeResult = try #require(
            HistorySearchJob().run(corpus: largeCorpus, terms: HistorySearchTerms(query: "nee"), locale: locale)
        )
        let largeNeedleResult = try #require(
            HistorySearchJob().run(
                corpus: largeCorpus,
                terms: HistorySearchTerms(query: "needle"),
                locale: locale,
                previous: largeNeeResult
            )
        )
        let expectedLargeNeedle = largeTexts.map {
            $0.range(of: "needle", options: HistorySearchMatcher.compareOptions, locale: locale) != nil
        }
        #expect(largeNeedleResult.matches == expectedLargeNeedle)
        #expect(largeNeedleResult.matchCount == 7)

        let nonASCIICascadeTerms = HistorySearchTerms(query: "日本語 needle")
        let nonASCIICascadeResult = try #require(
            HistorySearchJob().run(corpus: largeCorpus, terms: nonASCIICascadeTerms, locale: locale)
        )
        let expectedNonASCICI = largeTexts.map { haystack in
            nonASCIICascadeTerms.values.allSatisfy { term in
                haystack.range(of: term, options: HistorySearchMatcher.compareOptions, locale: locale) != nil
            }
        }
        #expect(nonASCIICascadeResult.matches == expectedNonASCICI)
        #expect(nonASCIICascadeResult.matchCount == 3)
    }

    @Test
    @MainActor
    func appModelMultiTermSearchAndSingleTagOrderingCacheInvalidation() {
        let model = AppModel()
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

        var olderFirstInTag = ClipboardItem.fixture(
            text: "alpha older manual-first",
            copiedAt: baseDate,
            tags: [1, 2]
        )
        olderFirstInTag.tagOrders = [1: 0]

        var newerSecondInTag = ClipboardItem.fixture(
            text: "alpha beta newer manual-second",
            copiedAt: baseDate.addingTimeInterval(60),
            tags: [1, 2]
        )
        newerSecondInTag.tagOrders = [1: 1]

        let untaggedNewest = ClipboardItem.fixture(
            text: "beta gamma untagged",
            copiedAt: baseDate.addingTimeInterval(120),
            tags: []
        )

        model.items = [olderFirstInTag, newerSecondInTag, untaggedNewest]
        #expect(model.filteredItems.map(\.id) == [untaggedNewest.id, newerSecondInTag.id, olderFirstInTag.id])

        let revisionBeforeSearch = model.sortedListRevision
        model.searchQuery = "alpha"
        #expect(model.sortedListRevision == revisionBeforeSearch)
        #expect(model.filteredItems.map(\.id) == [newerSecondInTag.id, olderFirstInTag.id])

        model.searchQuery = "alpha beta"
        #expect(model.sortedListRevision == revisionBeforeSearch)
        #expect(model.filteredItems.map(\.id) == [newerSecondInTag.id])

        model.searchQuery = ""
        #expect(model.sortedListRevision == revisionBeforeSearch)

        // Entering single-tag filter activates manual `orderingTagID` and invalidates cached sort order.
        model.selectedHistoryFilterTagIDs = [1]
        #expect(model.orderingTagID == 1)
        let singleTagRevision = model.sortedListRevision
        #expect(singleTagRevision != revisionBeforeSearch)
        #expect(model.filteredItems.map(\.id) == [olderFirstInTag.id, newerSecondInTag.id])

        // Widening to two tags leaves single-tag `orderingTagID` and restores `copiedAt` sort order.
        model.selectedHistoryFilterTagIDs = [1, 2]
        #expect(model.orderingTagID == nil)
        #expect(model.sortedListRevision != singleTagRevision)
        #expect(model.filteredItems.map(\.id) == [newerSecondInTag.id, olderFirstInTag.id])
    }

    @Test
    @MainActor
    func previewFieldAndTextRowRedrawWhenTogglingHidesSensitiveContent() throws {
        TestSupport.ensureAppKitInitialized()

        let baseFont = NSFont.systemFont(ofSize: 13)
        let field = HistoryTextPreviewField()
        let literalMasked = "Token \(SensitiveContent.inlineMask) suffix"
        let bulletLocation = (literalMasked as NSString).range(of: SensitiveContent.inlineMask).location

        field.update(
            previewText: literalMasked,
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: true,
            widthHint: 480
        )
        let hiddenFont = try #require(
            field.attributedStringValue.attribute(.font, at: bulletLocation, effectiveRange: nil) as? NSFont
        )
        #expect(abs(hiddenFont.pointSize - baseFont.pointSize * 0.42) < 0.01)

        // Same `previewText` with `hidesSensitiveContent: false` must invalidate `RenderedState` and redraw unscaled.
        field.update(
            previewText: literalMasked,
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: false,
            widthHint: 480
        )
        let revealedFont = try #require(
            field.attributedStringValue.attribute(.font, at: bulletLocation, effectiveRange: nil) as? NSFont
        )
        #expect(abs(revealedFont.pointSize - baseFont.pointSize) < 0.01)

        // Toggling back to `true` restores mask font scaling.
        field.update(
            previewText: literalMasked,
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: true,
            widthHint: 480
        )
        let rehiddenFont = try #require(
            field.attributedStringValue.attribute(.font, at: bulletLocation, effectiveRange: nil) as? NSFont
        )
        #expect(abs(rehiddenFont.pointSize - baseFont.pointSize * 0.42) < 0.01)

        // End-to-end `HistoryItemRowTextView` toggle with runtime-assembled token.
        let token = ["sk", "-", String(repeating: "a1B2c3D4", count: 4)].joined()
        let item = ClipboardItem.fixture(kind: .text, text: "API key \(token) active")
        let row = HistoryItemRowTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 48))

        row.configure(
            item: item,
            quickPasteIndex: 1,
            tableWidth: 480,
            detectsSensitiveContent: true,
            revealsSensitiveContent: false
        )
        #expect(row.hidesSensitiveContent)

        row.configure(
            item: item,
            quickPasteIndex: 1,
            tableWidth: 480,
            detectsSensitiveContent: true,
            revealsSensitiveContent: true
        )
        #expect(!row.hidesSensitiveContent)
    }

    @Test
    func previewFormatterCutPreservesInlineAndCardMaskSpansAcrossBoundaries() {
        let inlineMasked = "Key \(SensitiveContent.inlineMask) trailing context words"
        let inlinePreview = HistoryTextPreviewFormatter.preview(from: inlineMasked)

        for budget in 1...inlineMasked.count {
            let (cutPreview, _) = HistoryTextPreviewFormatter.cut(inlinePreview, toVisibleCharacters: budget)
            if cutPreview.text.contains("●") {
                let ranges = SensitiveContent.maskRanges(in: cutPreview.text)
                #expect(
                    ranges.count == 1 && ranges[0].length == SensitiveContent.inlineMask.utf16.count,
                    "Inline mask split at budget=\(budget): \(cutPreview.text)"
                )
            }
        }

        let cardMask = "●●●● ●●●● ●●●● 4242"
        let cardMasked = "Card \(cardMask) trailing context words"
        let cardPreview = HistoryTextPreviewFormatter.preview(from: cardMasked)

        for budget in 1...cardMasked.count {
            let (cutPreview, _) = HistoryTextPreviewFormatter.cut(cardPreview, toVisibleCharacters: budget)
            if cutPreview.text.contains("●") {
                let ranges = SensitiveContent.maskRanges(in: cutPreview.text)
                #expect(
                    ranges.map(\.length) == [4, 4, 4],
                    "Card mask split at budget=\(budget): \(cutPreview.text)"
                )
                #expect(cutPreview.text.contains(cardMask))
            }
        }

        // `boundedString` via `preview(from:characterLimit:)` also preserves mask spans.
        let boundedInline = HistoryTextPreviewFormatter.preview(from: inlineMasked, characterLimit: 7)
        #expect(SensitiveContent.maskRanges(in: boundedInline.text).map(\.length) == [8])

        let boundedCard = HistoryTextPreviewFormatter.preview(from: cardMasked, characterLimit: 12)
        #expect(SensitiveContent.maskRanges(in: boundedCard.text).map(\.length) == [4, 4, 4])
        #expect(boundedCard.text.contains(cardMask))

        // Masks ending directly at `endIndex` with no trailing text do not report a cut or append "...".
        let inlineAtEnd = "Key \(SensitiveContent.inlineMask)"
        let inlineAtEndPreview = HistoryTextPreviewFormatter.preview(from: inlineAtEnd)
        for budget in 5..<inlineAtEnd.count {
            let (cutPreview, isCut) = HistoryTextPreviewFormatter.cut(inlineAtEndPreview, toVisibleCharacters: budget)
            #expect(!isCut, "Unexpected isCut at budget=\(budget)")
            #expect(!cutPreview.text.hasSuffix("..."))
            #expect(cutPreview.text == inlineAtEnd)
        }
        let boundedInlineAtEnd = HistoryTextPreviewFormatter.preview(from: inlineAtEnd, characterLimit: 6)
        #expect(!boundedInlineAtEnd.text.hasSuffix("..."))
        #expect(boundedInlineAtEnd.text == inlineAtEnd)

        let cardAtEnd = "Card \(cardMask)"
        let cardAtEndPreview = HistoryTextPreviewFormatter.preview(from: cardAtEnd)
        for budget in 6..<cardAtEnd.count {
            let (cutPreview, isCut) = HistoryTextPreviewFormatter.cut(cardAtEndPreview, toVisibleCharacters: budget)
            #expect(!isCut, "Unexpected isCut at budget=\(budget)")
            #expect(!cutPreview.text.hasSuffix("..."))
            #expect(cutPreview.text == cardAtEnd)
        }
        let boundedCardAtEnd = HistoryTextPreviewFormatter.preview(from: cardAtEnd, characterLimit: 6)
        #expect(!boundedCardAtEnd.text.hasSuffix("..."))
        #expect(boundedCardAtEnd.text == cardAtEnd)

        // Multi-line/tabbed input preserves pre-cut `symbolRanges`, drops post-cut `symbolRanges`,
        // and keeps every range within `0...cutPreview.text.utf16.count`.
        let tabbedMultiline = "col1\tKey \(SensitiveContent.inlineMask)\ncol2"
        let tabbedPreview = HistoryTextPreviewFormatter.preview(from: tabbedMultiline)
        #expect(tabbedPreview.symbolRanges.count == 2)
        let preMaskSymbolRange = tabbedPreview.symbolRanges[0]
        let (cutAtMask, wasCutAtMask) = HistoryTextPreviewFormatter.cut(tabbedPreview, toVisibleCharacters: 10)
        #expect(wasCutAtMask)
        #expect(cutAtMask.symbolRanges == [preMaskSymbolRange])

        for budget in 1...tabbedPreview.text.count {
            let (cutPreview, _) = HistoryTextPreviewFormatter.cut(tabbedPreview, toVisibleCharacters: budget)
            let utf16Count = cutPreview.text.utf16.count
            for range in cutPreview.symbolRanges {
                #expect(range.location >= 0 && range.length > 0)
                #expect(NSMaxRange(range) <= utf16Count)
            }
        }
    }

    @Test
    @MainActor
    func previewFieldInvalidatesRenderedStateWhenSymbolRangesChangeAcrossIdenticalDisplayText() throws {
        TestSupport.ensureAppKitInitialized()

        let baseFont = NSFont.systemFont(ofSize: 13)
        let field = HistoryTextPreviewField()
        let expectedDisplayText = "col1\(HistoryTextPreviewFormatter.tabSymbol)col2"
        let arrowLocation = (expectedDisplayText as NSString)
            .range(of: HistoryTextPreviewFormatter.tabSymbol)
            .location
        let symbolColor = HistoryPreviewSymbolAppearance.color(for: field)

        field.update(
            previewText: "col1\tcol2",
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: false,
            widthHint: 480
        )
        #expect(field.attributedStringValue.string == expectedDisplayText)
        let textColorAtStart = try #require(
            field.attributedStringValue.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
        )
        let tabSymbolColor = try #require(
            field.attributedStringValue.attribute(.foregroundColor, at: arrowLocation, effectiveRange: nil) as? NSColor
        )
        #expect(tabSymbolColor == symbolColor)
        #expect(tabSymbolColor != textColorAtStart)

        // Updating to a literal arrow produces the exact same `displayText` ("col1→col2") with empty `symbolRanges`.
        field.update(
            previewText: expectedDisplayText,
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: false,
            widthHint: 480
        )
        #expect(field.attributedStringValue.string == expectedDisplayText)
        let literalArrowColor = try #require(
            field.attributedStringValue.attribute(.foregroundColor, at: arrowLocation, effectiveRange: nil) as? NSColor
        )
        #expect(literalArrowColor == textColorAtStart)
        #expect(literalArrowColor != symbolColor)

        // Switching back to a tab character restores symbol coloring on the arrow range.
        field.update(
            previewText: "col1\tcol2",
            searchQuery: "",
            font: baseFont,
            textColor: .labelColor,
            maximumNumberOfLines: 2,
            wrappingMode: .byWordWrapping,
            hidesSensitiveContent: false,
            widthHint: 480
        )
        let restoredSymbolColor = try #require(
            field.attributedStringValue.attribute(.foregroundColor, at: arrowLocation, effectiveRange: nil) as? NSColor
        )
        #expect(restoredSymbolColor == symbolColor)
    }

    @Test
    func previewFormatterBoundedStringOnLargeLeadingWhitespacePreservesMasks() {
        let leadingWhitespace = String(repeating: " \n\t", count: 4_000)

        let inlineBody = "Prefix \(SensitiveContent.inlineMask) trailing words after mask"
        let inlineInput = leadingWhitespace + inlineBody
        for limit in 8...14 {
            let preview = HistoryTextPreviewFormatter.preview(from: inlineInput, characterLimit: limit)
            #expect(
                SensitiveContent.maskRanges(in: preview.text).map(\.length) == [8],
                "Inline mask corrupted at characterLimit=\(limit): \(preview.text)"
            )
            #expect(preview.text == "Prefix \(SensitiveContent.inlineMask)...")
        }

        let wideMask = String(repeating: "●", count: 40)
        let wideInput = leadingWhitespace + "Token \(wideMask) trailing words"
        for limit in [7, 20, 35, 45] {
            let preview = HistoryTextPreviewFormatter.preview(from: wideInput, characterLimit: limit)
            #expect(
                SensitiveContent.maskRanges(in: preview.text).map(\.length) == [40],
                "Wide inline mask corrupted at characterLimit=\(limit): \(preview.text)"
            )
            #expect(preview.text == "Token \(wideMask)...")
        }

        let cardMask = "●●●● ●●●● ●●●● 4242"
        let cardInput = leadingWhitespace + "Card \(cardMask) trailing words after card"
        for limit in 6...23 {
            let preview = HistoryTextPreviewFormatter.preview(from: cardInput, characterLimit: limit)
            #expect(
                SensitiveContent.maskRanges(in: preview.text).map(\.length) == [4, 4, 4],
                "Card mask corrupted at characterLimit=\(limit): \(preview.text)"
            )
            #expect(preview.text == "Card \(cardMask)...")
        }
    }

    @Test
    @MainActor
    func appModelIgnoresStaleLocaleSearchResult() throws {
        let currentLocale = Locale.current
        let terms = HistorySearchTerms(query: "i")
        let matchesUnderCurrentLocale = HistorySearchMatcher.matches("I", terms, locale: currentLocale)
        let mismatchedLocale = matchesUnderCurrentLocale
            ? Locale(identifier: "tr_TR")
            : Locale(identifier: "en_US")
        #expect(HistorySearchMatcher.matches("I", terms, locale: mismatchedLocale) != matchesUnderCurrentLocale)

        let model = AppModel()
        let item = ClipboardItem.fixture(
            kind: .text,
            text: "I",
            sourceAppName: nil,
            sourceBundleIdentifier: nil,
            searchText: "I"
        )
        model.items = [item]
        model.searchQuery = "i"

        let corpus = model.makeSearchCorpus()
        let staleLocaleResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: terms, locale: mismatchedLocale)
        )
        #expect(staleLocaleResult.matches == [!matchesUnderCurrentLocale])
        model.installSearchResult(staleLocaleResult)

        // Positional fast path (`!hasContentTypes && !hasTags && !hasSources`) ignores mismatched locale.
        #expect((model.filteredItems.map(\.id) == [item.id]) == matchesUnderCurrentLocale)

        // Non-fast-path filter loop (`hasContentTypes == true`) also ignores mismatched locale.
        model.selectedHistoryFilterContentTypes = [.text]
        #expect((model.filteredItems.map(\.id) == [item.id]) == matchesUnderCurrentLocale)
        model.selectedHistoryFilterContentTypes = []

        let currentLocaleResult = try #require(
            HistorySearchJob().run(corpus: corpus, terms: terms, locale: currentLocale)
        )
        model.installSearchResult(currentLocaleResult)
        #expect((model.filteredItems.map(\.id) == [item.id]) == matchesUnderCurrentLocale)
    }

    @Test
    func mayContainSecretPrefilterCoversEverySecretPatternAndLongTextThreshold() {
        #expect(!SensitiveContentDetector.mayContainSecret(in: ""))
        #expect(!SensitiveContentDetector.mayContainSecret(in: "Ordinary prose with letters, commas, and spaces only."))
        #expect(!SensitiveContentDetector.mayContainSecret(in: "日本語テキスト 한글 Café résumé"))

        // Runtime-assembled fixtures covering digits, delimiters, and letter-only prefix families.
        let samples = [
            ["AI", "za", String(repeating: "B", count: 35)].joined(),
            ["AK", "IA", String(repeating: "Q", count: 16)].joined(),
            ["AS", "IA", String(repeating: "R", count: 16)].joined(),
            ["S", "G.", String(repeating: "m", count: 22), ".", String(repeating: "n", count: 43)].joined(),
            ["ey", "J", String(repeating: "a", count: 24), ".", "ey", "J", String(repeating: "b", count: 24)].joined(),
            ["sk", "-", String(repeating: "a1B2c3D4", count: 4)].joined(),
            ["ghp", "_", String(repeating: "x9Y8z7", count: 6)].joined(),
            "password=alphabeta",
            "https://user:secret@example.com",
            "Bearer abcdefghijklmnop1"
        ]
        for sample in samples {
            #expect(
                SensitiveContentDetector.mayContainSecret(in: sample),
                "Prefilter rejected sample: \(sample.prefix(6))"
            )
        }

        // Long ordinary prose (>= 16,000 UTF-8 bytes) passes through so secrets beyond the prefix are still scanned.
        let underLimit = String(repeating: "abcd ", count: 3_199)
        #expect(underLimit.utf8.count < 16_000)
        #expect(!SensitiveContentDetector.mayContainSecret(in: underLimit))

        let atOrOverLimit = String(repeating: "abcd ", count: 3_201)
        #expect(atOrOverLimit.utf8.count >= 16_000)
        #expect(SensitiveContentDetector.mayContainSecret(in: atOrOverLimit))
    }
}

extension SharedProcessStateTests {
    @Suite(.serialized)
    struct HistorySearchControllerTests {
        @Test
        @MainActor
        func debouncesSearchQueryUpdatesOffMainThread() async throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            try harness.seedHistory([
                ClipboardItem.fixture(text: "Alpha entry", copiedAt: base),
                ClipboardItem.fixture(text: "Beta needle", copiedAt: base.addingTimeInterval(10)),
                ClipboardItem.fixture(text: "Gamma needle", copiedAt: base.addingTimeInterval(20))
            ])

            let controller = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
            _ = controller.view
            let toolbar = HistoryToolbar()
            toolbar.delegate = controller
            controller.attachToolbar(toolbar)

            controller.historyToolbar(toolbar, didChangeSearchQuery: "needle")
            #expect(harness.model.searchQuery.isEmpty)

            let completed = await TestSupport.waitUntil {
                harness.model.searchQuery == "needle"
                    && harness.model.searchResult?.terms == HistorySearchTerms(query: "needle")
            }
            #expect(completed)
            #expect(harness.model.filteredItems.count == 2)
        }

        @Test
        @MainActor
        func trailingWhitespacePreservesSelectionWhileTermChangesSelectFirstMatch() async throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let secondMatch = ClipboardItem.fixture(text: "Needle older", copiedAt: base)
            let firstMatch = ClipboardItem.fixture(text: "Needle newer", copiedAt: base.addingTimeInterval(10))
            let unrelated = ClipboardItem.fixture(text: "Unrelated top", copiedAt: base.addingTimeInterval(20))
            try harness.seedHistory([secondMatch, firstMatch, unrelated])

            let controller = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
            _ = controller.view
            let toolbar = HistoryToolbar()
            toolbar.delegate = controller
            controller.attachToolbar(toolbar)
            controller.selectFirstHistoryItem()
            #expect(harness.model.selectedItemID == unrelated.id)

            controller.historyToolbar(toolbar, didChangeSearchQuery: "needle")
            let settled = await TestSupport.waitUntil {
                harness.model.searchQuery == "needle"
                    && harness.model.searchResult?.terms == HistorySearchTerms(query: "needle")
            }
            #expect(settled)
            #expect(harness.model.selectedItemID == firstMatch.id)

            // Move selection to the second match, then type trailing whitespace (unchanged parsed terms).
            controller.historyToolbar(toolbar, didRequestMoveSelection: .down)
            #expect(harness.model.selectedItemID == secondMatch.id)

            controller.historyToolbar(toolbar, didChangeSearchQuery: "needle   ")
            #expect(harness.model.searchQuery == "needle   ")
            #expect(harness.model.selectedItemID == secondMatch.id)
        }

        @Test
        @MainActor
        func flushesPendingSearchSynchronouslyOnSelectionMove() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let targetSecond = ClipboardItem.fixture(text: "Target second", copiedAt: base)
            let targetFirst = ClipboardItem.fixture(text: "Target first", copiedAt: base.addingTimeInterval(10))
            let unrelatedTop = ClipboardItem.fixture(text: "Unrelated top", copiedAt: base.addingTimeInterval(20))
            try harness.seedHistory([targetSecond, targetFirst, unrelatedTop])

            let controller = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
            _ = controller.view
            let toolbar = HistoryToolbar()
            toolbar.delegate = controller
            controller.attachToolbar(toolbar)
            controller.selectFirstHistoryItem()
            #expect(harness.model.selectedItemID == unrelatedTop.id)

            controller.historyToolbar(toolbar, didChangeSearchQuery: "target")
            #expect(harness.model.searchQuery.isEmpty)

            controller.historyToolbar(toolbar, didRequestMoveSelection: .down)
            #expect(harness.model.searchQuery == "target")
            #expect(harness.model.filteredItems.map(\.id) == [targetFirst.id, targetSecond.id])
            #expect(harness.model.selectedItemID == targetSecond.id)
        }

        @Test
        @MainActor
        func flushesPendingSearchSynchronouslyOnToolbarCopySortAndOpenSelection() throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let targetSecond = ClipboardItem.fixture(text: "Target second", copiedAt: base)
            let targetFirst = ClipboardItem.fixture(text: "Target first", copiedAt: base.addingTimeInterval(10))
            let unrelatedTop = ClipboardItem.fixture(text: "Unrelated top", copiedAt: base.addingTimeInterval(20))
            try harness.seedHistory([targetSecond, targetFirst, unrelatedTop])

            let controller = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
            _ = controller.view
            let toolbar = HistoryToolbar()
            toolbar.delegate = controller
            controller.attachToolbar(toolbar)
            controller.selectFirstHistoryItem()
            #expect(harness.model.selectedItemID == unrelatedTop.id)

            // `historyToolbarDidRequestCopy` flushes pending debounced query before copying selection.
            controller.historyToolbar(toolbar, didChangeSearchQuery: "target")
            #expect(harness.model.searchQuery.isEmpty)
            controller.historyToolbarDidRequestCopy(toolbar)
            #expect(harness.model.searchQuery == "target")
            #expect(harness.model.selectedItemID == targetFirst.id)
            #expect(harness.pasteboard.string(forType: .string) == "Target first")

            // `selectHistoryItemOnOpen` flushes pending debounced query before resolving selection.
            controller.historyToolbar(toolbar, didChangeSearchQuery: "second")
            #expect(harness.model.searchQuery == "target")
            controller.selectHistoryItemOnOpen()
            #expect(harness.model.searchQuery == "second")
            #expect(harness.model.selectedItemID == targetSecond.id)

            // `historyToolbarDidRequestToggleSortOrder` flushes pending debounced query before reversing order.
            controller.historyToolbar(toolbar, didChangeSearchQuery: "target")
            #expect(harness.model.searchQuery == "second")
            controller.historyToolbarDidRequestToggleSortOrder(toolbar)
            #expect(harness.model.searchQuery == "target")
            #expect(harness.model.isHistorySortReversed)
        }

        @Test
        @MainActor
        func refreshesInstalledSearchOnItemsMutationAndClearsPendingSearchAfterHiddenInterval() async throws {
            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }

            let base = Date(timeIntervalSince1970: 1_700_000_000)
            let alpha = ClipboardItem.fixture(text: "Alpha entry", copiedAt: base)
            let beta = ClipboardItem.fixture(text: "Beta needle", copiedAt: base.addingTimeInterval(10))
            let gamma = ClipboardItem.fixture(text: "Gamma needle", copiedAt: base.addingTimeInterval(20))
            try harness.seedHistory([alpha, beta, gamma])

            let controller = HistoryContentViewController(model: harness.model, coordinator: harness.coordinator)
            _ = controller.view
            let toolbar = HistoryToolbar()
            toolbar.delegate = controller
            controller.attachToolbar(toolbar)

            controller.historyToolbar(toolbar, didChangeSearchQuery: "needle")
            let initialInstalled = await TestSupport.waitUntil {
                harness.model.searchQuery == "needle"
                    && harness.model.searchResult?.revision == harness.model.sortedListRevision
            }
            #expect(initialInstalled)
            #expect(harness.model.filteredItems.map(\.id) == [gamma.id, beta.id])

            let revisionBeforeInsert = harness.model.sortedListRevision
            let delta = ClipboardItem.fixture(text: "Delta needle", copiedAt: base.addingTimeInterval(30))
            harness.model.insert(delta)
            #expect(harness.model.sortedListRevision != revisionBeforeInsert)

            let refreshed = await TestSupport.waitUntil {
                harness.model.searchResult?.revision == harness.model.sortedListRevision
            }
            #expect(refreshed)
            #expect(harness.model.filteredItems.map(\.id) == [delta.id, gamma.id, beta.id])

            // Clearing after hidden interval while a debounced search is pending cancels it and resets search.
            controller.historyToolbar(toolbar, didChangeSearchQuery: "alpha")
            controller.clearSearchAfterHiddenInterval()
            #expect(harness.model.searchQuery.isEmpty)
            #expect(harness.model.searchResult == nil)
            #expect(harness.model.filteredItems.count == 4)

            // Also cancels a debounced search queued from an empty query so it never fires later.
            controller.historyToolbar(toolbar, didChangeSearchQuery: "beta")
            #expect(harness.model.searchQuery.isEmpty)
            controller.clearSearchAfterHiddenInterval()
            try await Task.sleep(for: .milliseconds(100))
            #expect(harness.model.searchQuery.isEmpty)
            #expect(harness.model.searchResult == nil)
            #expect(harness.model.filteredItems.count == 4)
        }

        @Test
        @MainActor
        func rowTextCacheSkipsRevealedSecretsAndEmptiesOnPermanentDeleteAndClearHistory() throws {
            TestSupport.ensureAppKitInitialized()

            let harness = try TestSupport.makeTestCoordinator()
            defer { harness.cleanup() }
            harness.model.preferences.trashRetentionDays = 0

            let uniqueSuffix = UUID().uuidString
            let token = ["sk", "-", String(repeating: "z9Y8x7W6", count: 4)].joined()
            let secretText = "Revealed token \(token) \(uniqueSuffix)"
            let ordinaryText = "Ordinary cached row text \(uniqueSuffix)"
            let secondText = "Second cached row text \(uniqueSuffix)"

            let secretItem = ClipboardItem.fixture(kind: .text, text: secretText)
            let ordinaryItem = ClipboardItem.fixture(kind: .text, text: ordinaryText)
            let secondItem = ClipboardItem.fixture(kind: .text, text: secondText)
            try harness.seedHistory([secretItem, ordinaryItem, secondItem])

            let row = HistoryItemRowTextView(frame: NSRect(x: 0, y: 0, width: 480, height: 48))

            // Revealed sensitive content is never placed into the shared row text cache.
            row.configure(
                item: secretItem,
                quickPasteIndex: 1,
                tableWidth: 480,
                detectsSensitiveContent: true,
                revealsSensitiveContent: true
            )
            #expect(!row.hidesSensitiveContent)
            #expect(HistoryRowTextCache.preview(for: secretText) == nil)

            // Ordinary row text is cached, and permanent deletion (`isTrashEnabled == false`) empties the cache.
            row.configure(
                item: ordinaryItem,
                quickPasteIndex: 1,
                tableWidth: 480,
                detectsSensitiveContent: true,
                revealsSensitiveContent: false
            )
            #expect(HistoryRowTextCache.preview(for: ordinaryText) != nil)
            harness.coordinator.delete([ordinaryItem])
            #expect(HistoryRowTextCache.preview(for: ordinaryText) == nil)

            // Clearing history also empties the row text cache.
            row.configure(
                item: secondItem,
                quickPasteIndex: 1,
                tableWidth: 480,
                detectsSensitiveContent: true,
                revealsSensitiveContent: false
            )
            #expect(HistoryRowTextCache.preview(for: secondText) != nil)
            harness.coordinator.clearHistory()
            #expect(HistoryRowTextCache.preview(for: secondText) == nil)
        }

        @Test
        @MainActor
        func imageRowTitleCacheRetriesUnreadableAssetUntilFileIsReadable() throws {
            TestSupport.ensureAppKitInitialized()

            func visibleLabels(in root: NSView) -> [String] {
                var strings: [String] = []
                if let label = root as? HistoryFixedTextColorLabel, !label.isHidden, label.superview != nil {
                    strings.append(label.text)
                }
                for subview in root.subviews where !subview.isHidden {
                    strings.append(contentsOf: visibleLabels(in: subview))
                }
                return strings
            }

            try TestSupport.withTemporaryDirectory { tempDir in
                let assetURL = tempDir.appendingPathComponent("\(UUID().uuidString).png")
                let item = ClipboardItem.fixture(
                    kind: .image,
                    title: nil,
                    text: nil,
                    assetPath: assetURL.path,
                    byteSize: 2_048
                )

                let row = HistoryItemRowImageView(frame: NSRect(x: 0, y: 0, width: 480, height: 48))

                // Before the file exists on disk, the row shows "Image" without caching that fallback title.
                row.configure(item: item, quickPasteIndex: 1, tableWidth: 480)
                #expect(visibleLabels(in: row).contains("Image"))

                // Once the PNG exists at the same `assetPath`, reconfiguring reads and caches its pixel dimensions.
                let pngData = try TestSupport.makePNGData(
                    pixelWidth: 288,
                    pixelHeight: 144,
                    dpi: 72.0,
                    color: .systemBlue
                )
                try pngData.write(to: assetURL)

                row.configure(item: item, quickPasteIndex: 1, tableWidth: 480)
                #expect(visibleLabels(in: row).contains("Image (288x144)"))
            }
        }

        @Test
        @MainActor
        func historyReloadUpdatesHighlightsCompactRowsMutatedItemsAndShiftedSectionHeadersOffscreen() throws {
            TestSupport.ensureAppKitInitialized()

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.alphaValue = 0
            defer { window.orderOut(nil) }

            let history = History(frame: NSRect(x: 0, y: 0, width: 520, height: 360))
            window.contentView = history

            func findPreviewField(in root: NSView) -> HistoryTextPreviewField? {
                if let field = root as? HistoryTextPreviewField, !field.isHidden {
                    return field
                }
                for subview in root.subviews where !subview.isHidden {
                    if let found = findPreviewField(in: subview) {
                        return found
                    }
                }
                return nil
            }

            func hasHighlightedCharacter(in attributed: NSAttributedString) -> Bool {
                var found = false
                attributed.enumerateAttribute(
                    .foregroundColor,
                    in: NSRange(location: 0, length: attributed.length)
                ) { value, _, stop in
                    if (value as? NSColor) == HistorySearchMatchHighlighter.highlightColor {
                        found = true
                        stop.pointee = true
                    }
                }
                return found
            }

            func rowIndex(of itemID: UUID) throws -> Int {
                try #require(
                    history.tableRows.indices.first { history.tableRows.itemID(at: $0) == itemID }
                )
            }

            func reload(
                items: [ClipboardItem],
                tags: [ClipBook.Tag] = [],
                searchQuery: String = "",
                groupPinnedFavorites: Bool = false,
                sectionDate: ((ClipboardItem) -> Date?)? = nil,
                showsTiles: Bool = false,
                showsCompactRows: Bool = false
            ) {
                let firstID = items.first?.id
                history.reload(
                    items: items,
                    availableTags: tags,
                    selectedItemID: firstID,
                    selectedItemIDs: firstID.map { [$0] } ?? [],
                    searchQuery: searchQuery,
                    showCommandNumberShortcut: true,
                    showPreviewForLinks: true,
                    detectSensitiveContent: true,
                    showDividers: false,
                    preferPastingAsPlainText: true,
                    groupPinnedFavorites: groupPinnedFavorites,
                    sectionDate: sectionDate,
                    showsTiles: showsTiles,
                    showsCompactRows: showsCompactRows,
                    onSelectFirstItem: { _ in }
                )
                history.layoutSubtreeIfNeeded()
                history.tableView.layoutSubtreeIfNeeded()
                history.tileGrid.layoutSubtreeIfNeeded()
                history.displayIfNeeded()
            }

            let tagA = ClipBook.Tag(id: 1, name: "Work", color: "#3366FF")
            let tagB = ClipBook.Tag(id: 2, name: "Urgent", color: "#FF5533")
            let now = Date(timeIntervalSince1970: 1_700_050_000)

            let textAlpha = ClipboardItem.fixture(
                kind: .text,
                text: "Alpha needle item",
                copiedAt: now,
                tags: [tagA.id, tagB.id]
            )
            let textBeta = ClipboardItem.fixture(
                kind: .text,
                text: "Beta needle item",
                copiedAt: now.addingTimeInterval(-10)
            )
            let imageGamma = ClipboardItem.fixture(
                kind: .image,
                title: nil,
                text: nil,
                copiedAt: now.addingTimeInterval(-20),
                byteSize: 4_096,
                searchText: "Gamma picture"
            )

            // 1. Initial non-compact reload.
            reload(items: [textAlpha, textBeta, imageGamma], tags: [tagA, tagB])
            #expect(!history.showsCompactRows)
            #expect(history.tableView.rowHeight == HistoryRow.height)

            let initialAlphaRow = try rowIndex(of: textAlpha.id)
            let initialAlphaCell = try #require(
                history.tableView.view(atColumn: 0, row: initialAlphaRow, makeIfNecessary: false) as? HistoryItemRowTextView
            )
            let initialGammaRow = try rowIndex(of: imageGamma.id)
            let initialGammaCell = try #require(
                history.tableView.view(atColumn: 0, row: initialGammaRow, makeIfNecessary: false) as? HistoryItemRowImageView
            )
            #expect(!initialAlphaCell.isCompact)
            #expect(!initialGammaCell.isCompact)
            #expect(initialAlphaCell.searchQuery.isEmpty)
            let alphaFieldBeforeSearch = try #require(findPreviewField(in: initialAlphaCell))
            #expect(!hasHighlightedCharacter(in: alphaFieldBeforeSearch.attributedStringValue))

            // 2. Narrowing search (`removedRowIndexes != nil`) updates surviving cell highlights in place.
            reload(items: [textAlpha, textBeta], tags: [tagA, tagB], searchQuery: "needle")
            let narrowedAlphaRow = try rowIndex(of: textAlpha.id)
            let narrowedAlphaCell = try #require(
                history.tableView.view(atColumn: 0, row: narrowedAlphaRow, makeIfNecessary: false) as? HistoryItemRowTextView
            )
            #expect(narrowedAlphaCell === initialAlphaCell)
            #expect(narrowedAlphaCell.searchQuery == "needle")
            let alphaFieldDuringSearch = try #require(findPreviewField(in: narrowedAlphaCell))
            #expect(hasHighlightedCharacter(in: alphaFieldDuringSearch.attributedStringValue))

            // Clearing search (`insertedRowIndexes != nil`) clears highlight attributes in place.
            reload(items: [textAlpha, textBeta, imageGamma], tags: [tagA, tagB], searchQuery: "")
            #expect(narrowedAlphaCell.searchQuery.isEmpty)
            #expect(!hasHighlightedCharacter(in: alphaFieldDuringSearch.attributedStringValue))

            // 3. Mutating a surviving visible item alongside row removal/insertion reloads that cell.
            var mutatedAlpha = textAlpha
            mutatedAlpha.tags = [tagA.id]
            mutatedAlpha.title = "Renamed Alpha"
            reload(items: [mutatedAlpha, textBeta], tags: [tagA, tagB], searchQuery: "needle")
            let reloadedAlphaAfterRemoval = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: mutatedAlpha.id), makeIfNecessary: false) as? HistoryItemRowTextView
            )
            #expect(reloadedAlphaAfterRemoval.configuredItem == mutatedAlpha)
            #expect(reloadedAlphaAfterRemoval.configuredItem?.tags == [tagA.id])
            #expect(reloadedAlphaAfterRemoval.configuredItem?.title == "Renamed Alpha")

            mutatedAlpha.title = "Expanded Alpha"
            reload(items: [mutatedAlpha, textBeta, imageGamma], tags: [tagA, tagB], searchQuery: "")
            let reloadedAlphaAfterInsertion = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: mutatedAlpha.id), makeIfNecessary: false) as? HistoryItemRowTextView
            )
            #expect(reloadedAlphaAfterInsertion.configuredItem == mutatedAlpha)
            #expect(reloadedAlphaAfterInsertion.configuredItem?.title == "Expanded Alpha")

            // 4. Toggling `showsCompactRows` (`false -> true` while narrowing, `true -> false` while expanding).
            reload(items: [mutatedAlpha, imageGamma], tags: [tagA, tagB], showsCompactRows: true)
            #expect(history.showsCompactRows)
            #expect(history.tableView.showsCompactRows)
            #expect(history.tableView.rowHeight == HistoryRow.compactHeight)
            let compactAlphaCell = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: mutatedAlpha.id), makeIfNecessary: false) as? HistoryItemRowTextView
            )
            let compactImageCell = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: imageGamma.id), makeIfNecessary: false) as? HistoryItemRowImageView
            )
            #expect(compactAlphaCell.isCompact)
            #expect(compactImageCell.isCompact)

            reload(items: [mutatedAlpha, textBeta, imageGamma], tags: [tagA, tagB], showsCompactRows: false)
            #expect(!history.showsCompactRows)
            #expect(!history.tableView.showsCompactRows)
            #expect(history.tableView.rowHeight == HistoryRow.height)
            let expandedAlphaCell = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: mutatedAlpha.id), makeIfNecessary: false) as? HistoryItemRowTextView
            )
            let expandedImageCell = try #require(
                history.tableView.view(atColumn: 0, row: try rowIndex(of: imageGamma.id), makeIfNecessary: false) as? HistoryItemRowImageView
            )
            #expect(!expandedAlphaCell.isCompact)
            #expect(!expandedImageCell.isCompact)

            // 5. Inserting 2+ sections at index 0 updates displaced former row-0 section header
            // from `sectionHeaderFirstHeight` (28pt) to `sectionHeaderHeight` (36pt) even when pushed offscreen.
            window.setContentSize(NSSize(width: 520, height: 120))
            history.frame = NSRect(x: 0, y: 0, width: 520, height: 120)

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let todayDate = todayStart.addingTimeInterval(3_600)
            let yesterdayDate = try #require(calendar.date(byAdding: .day, value: -1, to: todayDate))

            let yesterdayItem = ClipboardItem.fixture(text: "Yesterday entry", copiedAt: yesterdayDate)
            reload(
                items: [yesterdayItem],
                groupPinnedFavorites: true,
                sectionDate: { $0.copiedAt }
            )
            #expect(history.tableRows.isSectionHeader(at: 0))
            #expect(history.tableView.rect(ofRow: 0).height == HistoryRow.sectionHeaderFirstHeight)

            let favoriteItems = (0..<3).map { index in
                ClipboardItem.fixture(
                    text: "Pinned favorite \(index)",
                    copiedAt: todayDate.addingTimeInterval(Double(100 - index)),
                    isFavorite: true
                )
            }
            let todayItems = (0..<3).map { index in
                ClipboardItem.fixture(
                    text: "Today item \(index)",
                    copiedAt: todayDate.addingTimeInterval(Double(50 - index)),
                    isFavorite: false
                )
            }

            reload(
                items: favoriteItems + todayItems + [yesterdayItem],
                groupPinnedFavorites: true,
                sectionDate: { $0.copiedAt }
            )
            // Favorites header (0) + 3 favorites (1..3) + Today header (4) + 3 today (5..7) + Yesterday header (8).
            let shiftedYesterdayHeaderRow = 8
            #expect(history.tableRows.isSectionHeader(at: 0))
            #expect(history.tableRows.isSectionHeader(at: 4))
            #expect(history.tableRows.isSectionHeader(at: shiftedYesterdayHeaderRow))
            #expect(history.tableView.rect(ofRow: 0).height == HistoryRow.sectionHeaderFirstHeight)
            #expect(history.tableView.rect(ofRow: 4).height == HistoryRow.sectionHeaderHeight)
            #expect(history.tableView.rect(ofRow: shiftedYesterdayHeaderRow).height == HistoryRow.sectionHeaderHeight)

            // 6. Switching to `showsTiles: true` populates `HistoryTileGridView` with section headers and tiles,
            // then switches cleanly back to `showsTiles: false`.
            window.setContentSize(NSSize(width: 520, height: 360))
            history.frame = NSRect(x: 0, y: 0, width: 520, height: 360)
            let tileItems = [
                favoriteItems[0],
                ClipboardItem.fixture(
                    kind: .image,
                    title: nil,
                    text: nil,
                    copiedAt: todayDate.addingTimeInterval(200),
                    byteSize: 2_048,
                    searchText: "Today tile image"
                ),
                todayItems[0],
                yesterdayItem
            ]
            reload(
                items: tileItems,
                groupPinnedFavorites: true,
                sectionDate: { $0.copiedAt },
                showsTiles: true
            )
            #expect(history.showsTiles)
            #expect(history.rowsView === history.tileGrid)
            #expect(history.tileGrid.rows.count == history.tableRows.count)
            #expect(history.tileGrid.rows.isSectionHeader(at: 0))
            #expect(history.tileGrid.line(ofRow: 0) == nil)
            #expect(history.tileGrid.line(ofRow: 1) == 0)
            let visibleTileViews = history.tileGrid.subviews.compactMap { $0 as? HistoryTileView }.filter { !$0.isHidden }
            let visibleTileHeaders = history.tileGrid.subviews.compactMap { $0 as? HistorySectionHeaderCellView }.filter { !$0.isHidden }
            #expect(visibleTileViews.count == tileItems.count)
            #expect(visibleTileHeaders.count == 3)

            reload(
                items: tileItems,
                groupPinnedFavorites: true,
                sectionDate: { $0.copiedAt },
                showsTiles: false
            )
            #expect(!history.showsTiles)
            #expect(history.rowsView === history.tableView)
            #expect(history.tableView.numberOfRows == history.tableRows.count)
        }
    }
}
