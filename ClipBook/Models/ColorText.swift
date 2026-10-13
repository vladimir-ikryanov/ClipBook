import Foundation

/// A color read from copied text, as sRGB components in 0...1.
///
/// Colors outside the sRGB gamut, which lab(), lch(), oklab() and oklch() can
/// describe, are clamped to its nearest edge.
struct ColorText: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

extension ColorText {
    /// Reads six and eight digit hex colors and the CSS color functions rgb(),
    /// rgba(), hsl(), hsla(), hwb(), lab(), lch(), oklab() and oklch(), in both
    /// the comma separated and the space separated syntax that CSS allows for
    /// them. Hex without a leading number sign is read only when
    /// `allowsBareHex` is set.
    init?(_ text: String, allowsBareHex: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let color: ColorText?
        if trimmed.hasPrefix("#") {
            color = Self.hexColor(trimmed.dropFirst())
        } else if trimmed.hasSuffix(")") {
            color = Self.functionColor(trimmed)
        } else if allowsBareHex {
            color = Self.hexColor(Substring(trimmed))
        } else {
            color = nil
        }
        guard let color else {
            return nil
        }
        self = color
    }

    private typealias RGB = (red: Double, green: Double, blue: Double)

    private static func make(_ rgb: RGB, alpha: Double) -> ColorText {
        func clamped(_ value: Double) -> Double {
            min(max(value, 0), 1)
        }
        return ColorText(red: clamped(rgb.red), green: clamped(rgb.green), blue: clamped(rgb.blue), alpha: clamped(alpha))
    }

    // MARK: - Hex

    private static func hexColor(_ hex: Substring) -> ColorText? {
        let digits = hex.compactMap(\.hexDigitValue)
        guard hex.count == 6 || hex.count == 8, digits.count == hex.count else {
            return nil
        }

        let channels = stride(from: 0, to: digits.count, by: 2).map {
            Double(digits[$0] * 16 + digits[$0 + 1]) / 255
        }
        return make((channels[0], channels[1], channels[2]), alpha: channels.count == 4 ? channels[3] : 1)
    }

    // MARK: - Color functions

    private static func functionColor(_ text: String) -> ColorText? {
        guard let open = text.firstIndex(of: "(") else {
            return nil
        }
        let name = text[..<open]
        let body = text[text.index(after: open)..<text.index(before: text.endIndex)]

        // Only the functions that predate CSS Color 4 accept commas.
        let allowsCommas = ["rgb", "rgba", "hsl", "hsla"].contains(name)
        guard let arguments = Arguments(body, allowsCommas: allowsCommas) else {
            return nil
        }
        var alpha = 1.0
        if let alphaToken = arguments.alpha {
            guard let value = alphaToken.value(percentScale: 1) else {
                return nil
            }
            alpha = value
        }
        let (first, second, third) = (arguments.channels[0], arguments.channels[1], arguments.channels[2])

        let rgb: RGB?
        switch name {
        case "rgb", "rgba":
            rgb = rgbColor(red: first, green: second, blue: third)
        case "hsl", "hsla":
            rgb = hslColor(hue: first, saturation: second, lightness: third)
        case "hwb":
            rgb = hwbColor(hue: first, whiteness: second, blackness: third)
        case "lab":
            rgb = labColor(lightness: first, a: second, b: third)
        case "lch":
            rgb = lchColor(lightness: first, chroma: second, hue: third)
        case "oklab":
            rgb = oklabColor(lightness: first, a: second, b: third)
        case "oklch":
            rgb = oklchColor(lightness: first, chroma: second, hue: third)
        default:
            rgb = nil
        }
        guard let rgb else {
            return nil
        }
        return make(rgb, alpha: alpha)
    }

    private static func rgbColor(red: Token, green: Token, blue: Token) -> RGB? {
        guard let red = red.value(percentScale: 255),
              let green = green.value(percentScale: 255),
              let blue = blue.value(percentScale: 255) else {
            return nil
        }
        return (red / 255, green / 255, blue / 255)
    }

    private static func hslColor(hue: Token, saturation: Token, lightness: Token) -> RGB? {
        guard let hue = hue.hueDegrees,
              let saturation = saturation.value(percentScale: 100),
              let lightness = lightness.value(percentScale: 100) else {
            return nil
        }
        return hslToRGB(hue: hue, saturation: max(saturation, 0) / 100, lightness: lightness / 100)
    }

    private static func hwbColor(hue: Token, whiteness: Token, blackness: Token) -> RGB? {
        guard let hue = hue.hueDegrees,
              let whiteness = whiteness.value(percentScale: 100),
              let blackness = blackness.value(percentScale: 100) else {
            return nil
        }
        let white = max(whiteness, 0) / 100
        let black = max(blackness, 0) / 100
        if white + black >= 1 {
            let gray = white / (white + black)
            return (gray, gray, gray)
        }

        let base = hslToRGB(hue: hue, saturation: 1, lightness: 0.5)
        let scale = 1 - white - black
        return (base.red * scale + white, base.green * scale + white, base.blue * scale + white)
    }

    private static func labColor(lightness: Token, a: Token, b: Token) -> RGB? {
        guard let lightness = lightness.value(percentScale: 100),
              let a = a.value(percentScale: 125),
              let b = b.value(percentScale: 125) else {
            return nil
        }
        return labToRGB(lightness: min(max(lightness, 0), 100), a: a, b: b)
    }

    private static func lchColor(lightness: Token, chroma: Token, hue: Token) -> RGB? {
        guard let lightness = lightness.value(percentScale: 100),
              let chroma = chroma.value(percentScale: 150),
              let hue = hue.hueDegrees else {
            return nil
        }
        let (a, b) = polarToRectangular(chroma: max(chroma, 0), hue: hue)
        return labToRGB(lightness: min(max(lightness, 0), 100), a: a, b: b)
    }

    private static func oklabColor(lightness: Token, a: Token, b: Token) -> RGB? {
        guard let lightness = lightness.value(percentScale: 1),
              let a = a.value(percentScale: 0.4),
              let b = b.value(percentScale: 0.4) else {
            return nil
        }
        return oklabToRGB(lightness: min(max(lightness, 0), 1), a: a, b: b)
    }

    private static func oklchColor(lightness: Token, chroma: Token, hue: Token) -> RGB? {
        guard let lightness = lightness.value(percentScale: 1),
              let chroma = chroma.value(percentScale: 0.4),
              let hue = hue.hueDegrees else {
            return nil
        }
        let (a, b) = polarToRectangular(chroma: max(chroma, 0), hue: hue)
        return oklabToRGB(lightness: min(max(lightness, 0), 1), a: a, b: b)
    }

    // MARK: - Conversions
    //
    // The formulas and matrices follow the sample code in CSS Color Module
    // Level 4.

    private static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> RGB {
        func channel(_ n: Double) -> Double {
            let k = (n + hue / 30).truncatingRemainder(dividingBy: 12)
            let amount = saturation * min(lightness, 1 - lightness)
            return lightness - amount * max(-1, min(k - 3, 9 - k, 1))
        }
        return (channel(0), channel(8), channel(4))
    }

    private static func polarToRectangular(chroma: Double, hue: Double) -> (Double, Double) {
        let radians = hue * .pi / 180
        return (chroma * cos(radians), chroma * sin(radians))
    }

    /// CIE Lab uses the D50 white point, so the color is adapted to the D65
    /// white point of sRGB on the way.
    private static func labToRGB(lightness: Double, a: Double, b: Double) -> RGB {
        let kappa = 24389.0 / 27
        let epsilon = 216.0 / 24389

        let f1 = (lightness + 16) / 116
        let f0 = a / 500 + f1
        let f2 = f1 - b / 200
        let x = pow(f0, 3) > epsilon ? pow(f0, 3) : (116 * f0 - 16) / kappa
        let y = lightness > kappa * epsilon ? pow(f1, 3) : lightness / kappa
        let z = pow(f2, 3) > epsilon ? pow(f2, 3) : (116 * f2 - 16) / kappa
        let xyzD50 = (x * 0.3457 / 0.3585, y, z * (1 - 0.3457 - 0.3585) / 0.3585)

        let xyzD65 = multiply([
            [0.955473421488075, -0.02309845494876471, 0.06325924320057072],
            [-0.0283697093338637, 1.0099953980813041, 0.021041441191917323],
            [0.012314014864481998, -0.020507649298898964, 1.330365926242124],
        ], xyzD50)
        let linear = multiply([
            [3.2409699419045226, -1.537383177570094, -0.4986107602930034],
            [-0.9692436362808796, 1.8759675015077202, 0.04155505740717559],
            [0.05563007969699366, -0.20397695888897652, 1.0569715142428786],
        ], xyzD65)
        return gammaEncoded(linear)
    }

    private static func oklabToRGB(lightness: Double, a: Double, b: Double) -> RGB {
        let lms = multiply([
            [1, 0.3963377773761749, 0.2158037573099136],
            [1, -0.1055613458156586, -0.0638541728258133],
            [1, -0.0894841775298119, -1.2914855480194092],
        ], (lightness, a, b))
        let linear = multiply([
            [4.0767416360759583, -3.3077115392580629, 0.2309699031821043],
            [-1.2684379732850315, 2.6097573492876882, -0.3413193760026570],
            [-0.0041960761386756, -0.7034186179359362, 1.7076146940746117],
        ], (pow(lms.0, 3), pow(lms.1, 3), pow(lms.2, 3)))
        return gammaEncoded(linear)
    }

    private static func multiply(_ matrix: [[Double]], _ vector: (Double, Double, Double)) -> (Double, Double, Double) {
        func row(_ index: Int) -> Double {
            matrix[index][0] * vector.0 + matrix[index][1] * vector.1 + matrix[index][2] * vector.2
        }
        return (row(0), row(1), row(2))
    }

    private static func gammaEncoded(_ linear: (Double, Double, Double)) -> RGB {
        func encode(_ value: Double) -> Double {
            let magnitude = abs(value)
            let encoded = magnitude > 0.0031308 ? 1.055 * pow(magnitude, 1 / 2.4) - 0.055 : 12.92 * magnitude
            return value < 0 ? -encoded : encoded
        }
        return (encode(linear.0), encode(linear.1), encode(linear.2))
    }

    // MARK: - Arguments

    private struct Arguments {
        var channels: [Token]
        var alpha: Token?

        /// Reads either `a, b, c[, alpha]` or `a b c[ / alpha]`.
        init?(_ body: Substring, allowsCommas: Bool) {
            if body.contains(",") {
                guard allowsCommas, !body.contains("/") else {
                    return nil
                }
                let tokens = body.split(separator: ",", omittingEmptySubsequences: false).map {
                    Token($0.trimmingCharacters(in: .whitespaces))
                }
                // The comma syntax has no "none" keyword.
                guard tokens.count == 3 || tokens.count == 4,
                      tokens.allSatisfy({ $0 != nil && $0 != .missing }) else {
                    return nil
                }
                channels = tokens.prefix(3).compactMap { $0 }
                alpha = tokens.count == 4 ? tokens[3] : nil
                return
            }

            let halves = body.split(separator: "/", omittingEmptySubsequences: false)
            guard halves.count <= 2 else {
                return nil
            }
            let channelTokens = halves[0].split(whereSeparator: \.isWhitespace).map { Token($0) }
            guard channelTokens.count == 3, channelTokens.allSatisfy({ $0 != nil }) else {
                return nil
            }
            channels = channelTokens.compactMap { $0 }

            if halves.count == 2 {
                let alphaTokens = halves[1].split(whereSeparator: \.isWhitespace)
                guard alphaTokens.count == 1, let alphaToken = Token(alphaTokens[0]) else {
                    return nil
                }
                alpha = alphaToken
            }
        }
    }

    private enum Token: Equatable {
        case number(Double)
        case percentage(Double)
        case angle(degrees: Double)
        /// The "none" keyword of the space separated syntax.
        case missing

        init?(_ text: some StringProtocol) {
            if text == "none" {
                self = .missing
                return
            }

            let unitStart = text.firstIndex { !"0123456789.+-e".contains($0) } ?? text.endIndex
            guard let value = Double(String(text[..<unitStart])), value.isFinite else {
                return nil
            }
            switch text[unitStart...] {
            case "":
                self = .number(value)
            case "%":
                self = .percentage(value)
            case "deg":
                self = .angle(degrees: value)
            case "grad":
                self = .angle(degrees: value * 360 / 400)
            case "rad":
                self = .angle(degrees: value * 180 / .pi)
            case "turn":
                self = .angle(degrees: value * 360)
            default:
                return nil
            }
        }

        /// The value of a number or percentage, with 100% equal to `percentScale`.
        /// "none" means zero.
        func value(percentScale: Double) -> Double? {
            switch self {
            case .number(let value):
                return value
            case .percentage(let value):
                return value / 100 * percentScale
            case .missing:
                return 0
            case .angle:
                return nil
            }
        }

        /// A hue in 0..<360. A bare number is read as degrees.
        var hueDegrees: Double? {
            let degrees: Double
            switch self {
            case .number(let value), .angle(let value):
                degrees = value
            case .missing:
                degrees = 0
            case .percentage:
                return nil
            }
            let normalized = degrees.truncatingRemainder(dividingBy: 360)
            return normalized < 0 ? normalized + 360 : normalized
        }
    }
}
