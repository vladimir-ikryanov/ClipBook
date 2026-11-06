@testable import ClipBook
import AppKit
import Foundation
import Testing

@Suite
enum DomainAndSensitiveContentTests {
    @Suite
    struct ClipboardItemClassificationTests {
        @Test
        func htmlDigestDifferentiationAndCodingRoundTrip() throws {
            let itemOne = ClipboardItem.fixture(
                kind: .richText,
                text: "Hello",
                html: "<b>Bold Hello</b>"
            )
            let itemTwo = ClipboardItem.fixture(
                kind: .richText,
                text: "Hello",
                html: "<i>Italic Hello</i>"
            )

            #expect(itemOne.htmlDigest != nil)
            #expect(itemTwo.htmlDigest != nil)
            #expect(itemOne.htmlDigest != itemTwo.htmlDigest)
            #expect(itemOne.contentKey != itemTwo.contentKey)
            #expect(!itemOne.hasSameContent(as: itemTwo))

            let unloadedOne = itemOne.unloadingFormatting()
            let unloadedTwo = itemTwo.unloadingFormatting()
            #expect(!unloadedOne.isFormattingLoaded)
            #expect(unloadedOne.hasFormatting)
            #expect(unloadedOne.htmlDigest == itemOne.htmlDigest)
            #expect(unloadedOne.contentKey == itemOne.contentKey)
            #expect(!unloadedOne.hasSameContent(as: unloadedTwo))

            let encoded = try JSONEncoder().encode(unloadedOne)
            let decoded = try JSONDecoder().decode(ClipboardItem.self, from: encoded)
            #expect(decoded.htmlDigest == itemOne.htmlDigest)
            #expect(decoded.contentKey == itemOne.contentKey)

            var stripped = itemOne
            stripped.removeFormatting()
            #expect(!stripped.hasFormatting)
            #expect(stripped.htmlDigest == nil)
        }

        @Test
        func normalizedLinkContentKeyIgnoresFragmentAndCase() throws {
            let introURL = try #require(URL(string: "HTTPS://Example.COM/docs#intro"))
            let apiURL = try #require(URL(string: "https://example.com/docs#api"))

            #expect(ClipboardItem.normalizedLinkContentKey(for: introURL) == "https://example.com/docs")
            #expect(ClipboardItem.normalizedLinkContentKey(for: apiURL) == "https://example.com/docs")

            let introItem = ClipboardItem.fixture(kind: .link, text: "https://example.com/docs#intro")
            let apiItem = ClipboardItem.fixture(kind: .link, text: "https://example.com/docs#api")
            #expect(introItem.hasSameContent(as: apiItem))
        }

        @Test(
            arguments: [
                ("https://example.com/path?x=1#sec", true),
                ("http://localhost:8080/health", true),
                ("http://127.0.0.1:3000", true),
                ("http://[::1]:8080/test", true),
                ("https://example.com/with space", false),
                ("   ", false),
            ]
        )
        func linkURLValidation(input: String, isValid: Bool) {
            if isValid {
                #expect(ClipboardItem.linkURL(from: input) != nil)
            } else {
                #expect(ClipboardItem.linkURL(from: input) == nil)
            }
        }

        @Test(
            arguments: [
                ("@scope/pkg@1.0.0", false, ClipboardKind.text),
                ("user@localhost", false, ClipboardKind.text),
                ("user@example.com", false, ClipboardKind.email),
                ("first.last+tag@mail.example.co.uk", false, ClipboardKind.email),
                ("müller@example.de", false, ClipboardKind.email),
                ("mu\u{308}ller@example.de", false, ClipboardKind.email),
                ("info@münchen.de", false, ClipboardKind.email),
                ("user@例え.jp", false, ClipboardKind.email),
                ("https://clipbook.app/docs", false, ClipboardKind.link),
                ("#ff8800", false, ClipboardKind.color),
                ("ff8800", false, ClipboardKind.text),
                ("ff8800", true, ClipboardKind.color),
                ("rgb(12, 34, 56)", false, ClipboardKind.color),
            ]
        )
        func classifyText(
            input: String,
            treatDigitNumbersAsColor: Bool,
            expected: ClipboardKind
        ) {
            #expect(
                ClipboardKind.classifyText(input, treatDigitNumbersAsColor: treatDigitNumbersAsColor) == expected
            )
        }
    }

    @Suite
    struct PreferencesIgnoredAppAndRetentionTests {
        @Test
        func isApplicationIgnoredMatching() throws {
            let entries = [
                "/Applications/Safari.app",
                "1Password",
                "Keychain Access",
            ]

            #expect(
                AppPreferences.isApplicationIgnored(
                    bundlePath: "/Applications/Safari.app",
                    localizedName: "Safari",
                    entries: entries
                )
            )
            #expect(
                AppPreferences.isApplicationIgnored(
                    bundlePath: "/Applications/1Password.app",
                    localizedName: "1Password",
                    entries: entries
                )
            )
            #expect(
                !AppPreferences.isApplicationIgnored(
                    bundlePath: "/Applications/Notes.app",
                    localizedName: "Notes",
                    entries: entries
                )
            )

            var preferences = AppPreferences()
            preferences.ignoredAppsText = "/Applications/Safari.app\n1Password\n"
            #expect(preferences.ignoredApps == Set(["1Password"]))
        }

        @Test
        func ignoredApplicationMatching() throws {
            try TestSupport.withTemporaryDirectory { tempDir in
                let appURL = tempDir.appendingPathComponent("CustomVault.app", isDirectory: true)
                let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
                try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)

                let infoPlist: [String: Any] = [
                    "CFBundleIdentifier": "com.example.customvault",
                    "CFBundleName": "CustomVaultName",
                ]
                let plistData = try PropertyListSerialization.data(
                    fromPropertyList: infoPlist,
                    format: .xml,
                    options: 0
                )
                try plistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

                let ignoredApp = IgnoredApplication(path: appURL.path)
                #expect(ignoredApp.path == appURL.path)
                #expect(ignoredApp.name == "CustomVaultName")

                let matchingByBundleID = ClipboardItem.fixture(
                    kind: .text,
                    text: "secret",
                    sourceAppName: "OtherName",
                    sourceBundleIdentifier: "com.example.customvault"
                )
                #expect(ignoredApp.matches(matchingByBundleID))

                let matchingByName = ClipboardItem.fixture(
                    kind: .text,
                    text: "secret",
                    sourceAppName: "customvaultname",
                    sourceBundleIdentifier: nil
                )
                #expect(ignoredApp.matches(matchingByName))

                let otherApp = ClipboardItem.fixture(
                    kind: .text,
                    text: "secret",
                    sourceAppName: "OtherName",
                    sourceBundleIdentifier: "com.example.other"
                )
                #expect(!ignoredApp.matches(otherApp))
            }
        }

        private static let retentionNow = Date(timeIntervalSince1970: 1_750_000_000)

        private static func retentionPolicy() -> HistoryRetentionPolicy {
            var preferences = AppPreferences()
            preferences.textRetentionDays = AppPreferences.neverKeepRetentionDays
            preferences.richTextRetentionDays = AppPreferences.unlimitedRetentionDays
            preferences.linkRetentionDays = 7
            preferences.keepFavoritesOnClearHistory = true
            return HistoryRetentionPolicy(preferences: preferences, now: retentionNow)
        }

        @Test
        func retentionCutoffsFollowThePreferences() {
            let policy = Self.retentionPolicy()
            #expect(policy.cutoffsByKind[.text] == Self.retentionNow)
            #expect(policy.cutoffsByKind[.richText] == nil)
            #expect(policy.cutoffsByKind[.link] != nil)
        }

        @Test(arguments: [
            (kind: ClipboardKind.text, ageDays: 30.0, isFavorite: false, tags: [Int](), isExpired: true),
            (kind: ClipboardKind.link, ageDays: 10.0, isFavorite: false, tags: [Int](), isExpired: true),
            (kind: ClipboardKind.link, ageDays: 2.0, isFavorite: false, tags: [Int](), isExpired: false),
            (kind: ClipboardKind.link, ageDays: 10.0, isFavorite: true, tags: [Int](), isExpired: false),
            (kind: ClipboardKind.link, ageDays: 10.0, isFavorite: false, tags: [1], isExpired: false),
            (kind: ClipboardKind.richText, ageDays: 3_650.0, isFavorite: false, tags: [Int](), isExpired: false)
        ])
        func retentionExpiresItemsOlderThanTheirKindsCutoffUnlessKept(
            kind: ClipboardKind,
            ageDays: Double,
            isFavorite: Bool,
            tags: [Int],
            isExpired: Bool
        ) {
            let item = ClipboardItem.fixture(
                kind: kind,
                text: "retained text",
                copiedAt: Self.retentionNow.addingTimeInterval(-ageDays * 86_400),
                isFavorite: isFavorite,
                tags: tags
            )
            #expect(Self.retentionPolicy().isExpired(item) == isExpired)
        }

        @Test
        func retentionPeriodStepRoundTrips() {
            #expect(RetentionPeriod.stepCount == 23)
            for index in 0..<RetentionPeriod.stepCount {
                let days = RetentionPeriod.days(forStepIndex: index)
                let roundTrippedIndex = RetentionPeriod.stepIndex(forDays: days)
                #expect(roundTrippedIndex == index)

                let position = RetentionPeriod.visualPosition(forStepIndex: index)
                let indexFromPosition = RetentionPeriod.stepIndex(forVisualPosition: position)
                #expect(indexFromPosition == index)

                let fraction = RetentionPeriod.trackFraction(forVisualPosition: position)
                #expect((0.0...1.0).contains(fraction))
                #expect(!RetentionPeriod.label(forStepIndex: index).isEmpty)
            }
        }
    }

    @Suite
    struct SensitiveContentTests {
        nonisolated private static let openAITokenSample = ["sk", "-proj-", "1234567890", "abcdefghijklmnop"].joined()
        nonisolated private static let githubClassicTokenSample = ["ghp", "_", "1234567890abcdefghijklmnopqrstuvwxyz", "ABCD"].joined()
        nonisolated private static let githubFineGrainedTokenSample = ["github", "_pat_", "11ABCDEF0123456789abcdef", "_0123456789abcdef"].joined()
        nonisolated private static let gitlabTokenSample = ["glpat", "-", "1234567890", "abcdefghijkl"].joined()
        nonisolated private static let awsAccessKeySample = ["AK", "IA", "1234567890", "ABCDEF"].joined()
        nonisolated private static let slackBotTokenSample = ["xox", "b-", "1234567890-1234567890-", "abcdefghijklmnop"].joined()
        nonisolated private static let googleAPIKeySample = ["AI", "zaSyA", "1234567890", "abcdefghijklmnopqrstuvwx"].joined()
        nonisolated private static let stripeLiveKeySample = ["sk", "_live_", "1234567890", "abcdefghijklmn"].joined()
        nonisolated private static let jwtTokenSample = [
            "eyJ", "hbGciOiJIUzI1NiJ9.",
            "eyJ", "zdWIiOiIxMjM0NTY3ODkwIn0.",
            "signature12345",
        ].joined()
        nonisolated private static let rsaPrivateKeySample = [
            "-----BEGIN ", "RSA PRIVATE KEY-----\n",
            "MIIEpAIBAA", "KCAQEA1234567890\n",
            "-----END ", "RSA PRIVATE KEY-----",
        ].joined()
        nonisolated private static let basicAuthURLSample = [
            "https://admin", ":", "superSecretPass123", "@example.com/login",
        ].joined()
        nonisolated private static let bearerHeaderSample = [
            "Authori", "zation: ", "Bea", "rer ",
            String(repeating: "ab12", count: 5),
        ].joined()

        /// Whether the item counts as sensitive, and the text its row shows.
        private static func shown(
            _ text: String,
            kind: ClipboardKind = .text,
            characterLimit: Int? = nil
        ) -> (isMasked: Bool, text: String) {
            let item = ClipboardItem.fixture(kind: kind, text: text)
            let masked = characterLimit.map {
                SensitiveContent.maskedText(text, for: item, detectsAutomatically: true, characterLimit: $0)
            } ?? SensitiveContent.maskedText(text, for: item, detectsAutomatically: true)
            return (SensitiveContent.isMasked(item, detectsAutomatically: true), masked)
        }

        @Test(
            arguments: [
                Self.openAITokenSample,
                Self.githubClassicTokenSample,
                Self.githubFineGrainedTokenSample,
                Self.gitlabTokenSample,
                Self.awsAccessKeySample,
                Self.slackBotTokenSample,
                Self.googleAPIKeySample,
                Self.stripeLiveKeySample,
                Self.jwtTokenSample,
                Self.rsaPrivateKeySample,
                Self.basicAuthURLSample,
                Self.bearerHeaderSample,
            ]
        )
        func detectsKnownSecretFormats(sample: String) {
            let result = Self.shown(sample)
            #expect(result.isMasked)
            #expect(result.text != sample)
            #expect(result.text.contains(SensitiveContent.inlineMask))
        }

        /// The last group is what the valid card number's mask leaves visible.
        @Test(arguments: [
            (lastGroup: " 0366", isValid: true),
            (lastGroup: " 0367", isValid: false)
        ])
        func creditCardNumbersAreMaskedOnlyWhenTheyPassTheLuhnCheck(lastGroup: String, isValid: Bool) {
            let card = ["Card: 4532", " 0151", " 1283", lastGroup].joined()
            let result = Self.shown(card)
            #expect(result.isMasked == isValid)
            if isValid {
                #expect(result.text.hasSuffix(lastGroup))
                #expect(!result.text.contains("4532"))
            } else {
                #expect(result.text == card)
            }
        }

        @Test
        func secretsBeyond4000CharactersAreMaskedInThePreview() {
            let text = String(repeating: "a", count: 4_100) + " " + Self.openAITokenSample
            let result = Self.shown(text, characterLimit: SensitiveContent.previewCharacterLimit)
            #expect(result.isMasked)
            #expect(!result.text.contains(Self.openAITokenSample))
            #expect(result.text.contains(SensitiveContent.inlineMask))
        }

        @Test
        func tokensStraddlingTheRowLimitAreMaskedCompletely() {
            let text = String(repeating: "b", count: 3_990) + " " + Self.githubClassicTokenSample + " trailing text"
            let result = Self.shown(text)
            #expect(result.isMasked)
            #expect(!result.text.contains(["ghp", "_1234"].joined()))
            #expect(!result.text.contains("uvwxyzABCD"))
        }

        @Test
        func privateKeysStraddlingTheRowLimitAreMaskedCompletely() {
            let pemBlock = [
                "-----BEGIN ", "PRIVATE KEY-----\n",
                "MIIEvQIBADAN", "BgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC1234567890\n",
                "-----END ", "PRIVATE KEY-----",
            ].joined()
            let result = Self.shown(String(repeating: "b", count: 3_990) + " " + pemBlock)
            #expect(result.isMasked)
            #expect(!result.text.contains(["BEGIN ", "PRIVATE KEY"].joined()))
            #expect(!result.text.contains("MIIEvQIBADAN"))
        }

        @Test
        func queryParametersInALinkAreMaskedButItsFragmentIsNot() {
            let url = [
                "https://api.example.com/callback?token=", "abc12345",
                "&api_key=", "xyz98765", "#section(1)",
            ].joined()
            let result = Self.shown(url, kind: .link)
            #expect(result.isMasked)
            #expect(!result.text.contains("abc12345"))
            #expect(!result.text.contains("xyz98765"))
            #expect(result.text.contains("#section(1)"))
        }

        @Test
        func tokensInAnOAuthFragmentAreMasked() {
            let url = [
                "https://app.example.com/auth#access_token=", "abc12345",
                "&refresh_token=", "xyz98765",
            ].joined()
            let result = Self.shown(url, kind: .link)
            #expect(result.isMasked)
            #expect(!result.text.contains("abc12345"))
            #expect(!result.text.contains("xyz98765"))
        }

        @Test
        func anAssignmentRightAfterAnEmojiIsMasked() {
            let result = Self.shown(["🔑api_key=", "secret12345"].joined())
            #expect(result.isMasked)
            #expect(result.text.hasPrefix("🔑api_key="))
            #expect(!result.text.contains("secret12345"))
        }

        @Test(
            arguments: [
                ["password: ", "ab#cdefgh"],
                ["password=", "P&ss1234xyz"],
                ["pwd=", "hunter#2024"],
                ["DB_PASSWORD=", "hunter2#Secret99"],
            ]
        )
        func masksWholePasswordsWithAmpersandOrHash(parts: [String]) {
            let result = Self.shown(parts.joined())
            #expect(result.isMasked)
            #expect(result.text == parts[0] + SensitiveContent.inlineMask)
        }

        @Test(arguments: [
            (body: "password=hunter22&remember=1", masked: "password=MASK&remember=1"),
            (body: "token=abc12345&grant_type=refresh", masked: "token=MASK&grant_type=refresh"),
            (body: "user=ann&password=hunter22&remember=1", masked: "user=ann&password=MASK&remember=1")
        ])
        func aFormBodyKeepsTheFieldsAroundTheSecret(body: String, masked: String) {
            let expected = masked.replacingOccurrences(of: "MASK", with: SensitiveContent.inlineMask)
            #expect(Self.shown(body).text == expected)
        }

        @Test
        func masksEveryQueryParameterAndStopsAtItsSeparator() {
            let url = [
                "https://x.example.com/p?a=1&password=", "hunter2x",
                "&b=2&token=", "abc12345", "#frag",
            ].joined()
            let mask = SensitiveContent.inlineMask
            let maskedURL = "https://x.example.com/p?a=1&password=\(mask)&b=2&token=\(mask)#frag"
            #expect(Self.shown(url, kind: .link).text == maskedURL)

            // A URL followed by a password that has a "#" in it: each keeps its own rule.
            let mixed = [url, " ", "password: ", "ab#cdefgh"].joined()
            #expect(Self.shown(mixed).text == "\(maskedURL) password: \(mask)")
        }

        @Test
        func whitespaceARowDoesNotShowDoesNotCountAgainstItsReach() {
            let token = Self.openAITokenSample
            #expect(!Self.shown(String(repeating: " ", count: 6_000) + token).text.contains(token))
        }

        @Test
        func aSecretFarIntoALongItemMasksTheItem() {
            let token = Self.openAITokenSample
            let farText = String(repeating: "a", count: 50_000) + " " + token
            let far = Self.shown(farText)
            #expect(far.isMasked)
            // A row shows only the beginning, so its text is searched no further than that.
            #expect(far.text == farText)
            #expect(!Self.shown(farText, characterLimit: SensitiveContent.previewCharacterLimit).text.contains(token))
        }

        private static func maskedRichText(_ text: String) -> NSAttributedString {
            let item = ClipboardItem.fixture(kind: .richText, text: text)
            let attributed = NSAttributedString(string: text, attributes: [.toolTip: "kept"])
            return SensitiveContent.maskedAttributedText(attributed, for: item, detectsAutomatically: true)
        }

        @Test
        func maskedAttributedTextMasksLateAndStraddlingSecrets() {
            let whitespaceLead = String(repeating: " ", count: 6_000) + String(repeating: "a", count: 198_000) + " "
            let lateToken = Self.openAITokenSample
            let late = Self.maskedRichText(whitespaceLead + lateToken + " tail")
            #expect(!late.string.contains(lateToken))
            #expect(late.string == whitespaceLead + SensitiveContent.inlineMask + " tail")
            // The dots keep the formatting of the text they replace.
            #expect(late.attribute(.toolTip, at: whitespaceLead.utf16.count, effectiveRange: nil) as? String == "kept")

            let straddlingLead = String(repeating: "b", count: SensitiveContent.previewCharacterLimit - 10) + " "
            let straddlingToken = Self.githubClassicTokenSample
            let straddling = Self.maskedRichText(straddlingLead + straddlingToken + " trailing text")
            #expect(!straddling.string.contains(["ghp", "_1234"].joined()))
            #expect(!straddling.string.contains("uvwxyzABCD"))
            #expect(straddling.string == straddlingLead + SensitiveContent.inlineMask + " trailing text")
        }

        @Test
        func maskedAttributedTextLeavesTextWithoutSecretsAlone() {
            let text = "Nothing to hide here"
            #expect(Self.maskedRichText(text).string == text)

            let item = ClipboardItem.fixture(kind: .richText, text: Self.openAITokenSample, sensitivity: .notSensitive)
            let shown = SensitiveContent.maskedAttributedText(
                NSAttributedString(string: Self.openAITokenSample),
                for: item,
                detectsAutomatically: true
            )
            #expect(shown.string == Self.openAITokenSample)
        }
    }
}
