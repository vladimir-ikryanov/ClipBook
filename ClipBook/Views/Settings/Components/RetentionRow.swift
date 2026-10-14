import AppKit
import SwiftUI

enum RetentionClipType: CaseIterable {
    case text
    case richText
    case image
    case file
    case link
    case email
    case color

    var title: String {
        switch self {
        case .text: L10n.string("Texts")
        case .richText: L10n.string("Rich Texts")
        case .image: L10n.string("Images")
        case .file: L10n.string("Files & Folders")
        case .link: L10n.string("Links")
        case .email: L10n.string("Emails")
        case .color: L10n.string("Colors")
        }
    }

    var icon: String {
        switch self {
        case .text: "character.textbox"
        case .richText: "richtext.page"
        case .image: "photo"
        case .file: "folder"
        case .link: "link"
        case .email: "envelope"
        case .color: "paintpalette"
        }
    }

    init(kind: ClipboardKind) {
        switch kind {
        case .text: self = .text
        case .richText: self = .richText
        case .image: self = .image
        case .file: self = .file
        case .link: self = .link
        case .email: self = .email
        case .color: self = .color
        }
    }

    /// The clipboard kinds that share this retention period.
    var kinds: Set<ClipboardKind> {
        Set(ClipboardKind.allCases.filter { RetentionClipType(kind: $0) == self })
    }

    var preferenceKeyPath: WritableKeyPath<AppPreferences, Int> {
        switch self {
        case .text: \.textRetentionDays
        case .richText: \.richTextRetentionDays
        case .image: \.imageRetentionDays
        case .file: \.fileRetentionDays
        case .link: \.linkRetentionDays
        case .email: \.emailRetentionDays
        case .color: \.colorRetentionDays
        }
    }
}

enum RetentionPeriod {
    struct Step {
        let days: Int
        let label: String
    }

    private struct Segment {
        let startStep: Int
        let endStep: Int
        let startPosition: Double
        let endPosition: Double
    }

    static var steps: [Step] {
        [
            Step(days: AppPreferences.neverKeepRetentionDays, label: L10n.string("Never")),
            Step(days: 1, label: L10n.string("1 day")),
            Step(days: 2, label: L10n.string("2 days")),
            Step(days: 3, label: L10n.string("3 days")),
            Step(days: 4, label: L10n.string("4 days")),
            Step(days: 5, label: L10n.string("5 days")),
            Step(days: 6, label: L10n.string("6 days")),
            Step(days: 7, label: L10n.string("1 week")),
            Step(days: 14, label: L10n.string("2 weeks")),
            Step(days: 21, label: L10n.string("3 weeks")),
            Step(days: 30, label: L10n.string("1 month")),
            Step(days: 60, label: L10n.string("2 months")),
            Step(days: 90, label: L10n.string("3 months")),
            Step(days: 120, label: L10n.string("4 months")),
            Step(days: 150, label: L10n.string("5 months")),
            Step(days: 180, label: L10n.string("6 months")),
            Step(days: 210, label: L10n.string("7 months")),
            Step(days: 240, label: L10n.string("8 months")),
            Step(days: 270, label: L10n.string("9 months")),
            Step(days: 300, label: L10n.string("10 months")),
            Step(days: 330, label: L10n.string("11 months")),
            Step(days: 365, label: L10n.string("1 year")),
            Step(days: AppPreferences.unlimitedRetentionDays, label: L10n.string("Unlimited")),
        ]
    }

    /// The labels under the track. "Never" has no label of its own: it sits
    /// too close to "Day", and the row's value label already names it.
    static var keyPointLabels: [String] {
        [
            L10n.string("Day"),
            L10n.string("Week"),
            L10n.string("Month"),
            L10n.string("Year"),
            L10n.string("Forever"),
        ]
    }

    /// Where each label in `keyPointLabels` sits, in percent of the
    /// Day...Forever range.
    static let keyPointPositions: [Double] = [0, 25, 50, 75, 100]

    /// "Never" extends the track one day-step to the left of "Day", so the
    /// labels keep their quarter positions.
    static let minimumVisualPosition: Double = -25.0 / 6.0
    static let maximumVisualPosition: Double = 100

    private static let segments: [Segment] = [
        Segment(startStep: 0, endStep: 1, startPosition: minimumVisualPosition, endPosition: 0),
        Segment(startStep: 1, endStep: 7, startPosition: 0, endPosition: 25),
        Segment(startStep: 7, endStep: 10, startPosition: 25, endPosition: 50),
        Segment(startStep: 10, endStep: 21, startPosition: 50, endPosition: 75),
        Segment(startStep: 21, endStep: 22, startPosition: 75, endPosition: 100),
    ]

    static var stepCount: Int { steps.count }

    static var maxStepIndex: Int { steps.count - 1 }

    static func stepIndex(forDays days: Int) -> Int {
        if days < 0 {
            return maxStepIndex
        }

        if let index = steps.firstIndex(where: { $0.days == days }) {
            return index
        }

        return steps.enumerated().min(by: {
            abs($0.element.days - days) < abs($1.element.days - days)
        })?.offset ?? maxStepIndex
    }

    static func days(forStepIndex index: Int) -> Int {
        steps[min(max(index, 0), maxStepIndex)].days
    }

    static func label(forStepIndex index: Int) -> String {
        steps[min(max(index, 0), maxStepIndex)].label
    }

    static func visualPosition(forStepIndex index: Int) -> Double {
        let clampedIndex = min(max(index, 0), maxStepIndex)
        if clampedIndex <= 0 {
            return minimumVisualPosition
        }
        if clampedIndex >= maxStepIndex {
            return maximumVisualPosition
        }

        for segment in segments where clampedIndex >= segment.startStep && clampedIndex <= segment.endStep {
            let progress = Double(clampedIndex - segment.startStep)
                / Double(segment.endStep - segment.startStep)
            return segment.startPosition + progress * (segment.endPosition - segment.startPosition)
        }

        return minimumVisualPosition
    }

    static func stepIndex(forVisualPosition position: Double) -> Int {
        let clampedPosition = min(max(position, minimumVisualPosition), maximumVisualPosition)
        if clampedPosition <= minimumVisualPosition {
            return 0
        }
        if clampedPosition >= maximumVisualPosition {
            return maxStepIndex
        }

        for segment in segments where clampedPosition >= segment.startPosition && clampedPosition <= segment.endPosition {
            let progress = (clampedPosition - segment.startPosition)
                / (segment.endPosition - segment.startPosition)
            let valueRange = Double(segment.endStep - segment.startStep)
            return Int(round(Double(segment.startStep) + progress * valueRange))
        }

        return 0
    }

    /// How far along the track a visual position lies, from 0 to 1.
    static func trackFraction(forVisualPosition position: Double) -> Double {
        (position - minimumVisualPosition) / (maximumVisualPosition - minimumVisualPosition)
    }
}

struct RetentionRow: View {
    let clipType: RetentionClipType
    @Binding var value: Int
    @State private var stepIndex = RetentionPeriod.maxStepIndex
    @State private var isEditing = false

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { RetentionPeriod.visualPosition(forStepIndex: stepIndex) },
            set: { newPosition in
                let newStepIndex = RetentionPeriod.stepIndex(forVisualPosition: newPosition)
                if newStepIndex != stepIndex {
                    stepIndex = newStepIndex
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label {
                    Text(clipType.title)
                        .font(.subheadline.weight(.medium))
                } icon: {
                    Image(systemName: clipType.icon)
                        .font(.body)
                }

                Spacer()

                Text(RetentionPeriod.label(forStepIndex: stepIndex))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                ZStack {
                    RetentionStepMarks(filledUpToPosition: filledVisualPosition)
                        .padding(.horizontal, 10)
                        .allowsHitTesting(false)

                    Slider(
                        value: sliderBinding,
                        in: RetentionPeriod.minimumVisualPosition...RetentionPeriod.maximumVisualPosition
                    ) {
                        Text(clipType.title)
                    } minimumValueLabel: {
                        EmptyView()
                    } maximumValueLabel: {
                        EmptyView()
                    } onEditingChanged: { editing in
                        isEditing = editing
                        if !editing {
                            commitValueIfNeeded()
                        }
                    }
                    .labelsHidden()
                }

                RetentionKeyPointLabels()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            syncFromValue()
        }
        .onChange(of: value) { _ in
            guard !isEditing else {
                return
            }
            syncFromValue()
        }
    }

    private var filledVisualPosition: Double {
        RetentionPeriod.visualPosition(forStepIndex: stepIndex)
    }

    private func syncFromValue() {
        stepIndex = RetentionPeriod.stepIndex(forDays: value)
    }

    private func commitValueIfNeeded() {
        let days = RetentionPeriod.days(forStepIndex: stepIndex)
        guard days != value else {
            return
        }
        value = days
    }
}

private struct RetentionStepMarks: View {
    let filledUpToPosition: Double

    private static let filledColor = Color(red: 0, green: 0x6F / 255.0, blue: 1)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let centerY = geometry.size.height / 2

            ForEach(0..<RetentionPeriod.stepCount, id: \.self) { step in
                let position = RetentionPeriod.visualPosition(forStepIndex: step)
                Circle()
                    .fill(position <= filledUpToPosition ? Self.filledColor : Self.dotBackground)
                    .frame(width: 4, height: 4)
                    .position(x: markX(for: position, width: width), y: centerY)
            }
        }
        .frame(height: 16)
    }

    private func markX(for position: Double, width: CGFloat) -> CGFloat {
        if position <= RetentionPeriod.minimumVisualPosition {
            return 2
        }
        if position >= RetentionPeriod.maximumVisualPosition {
            return width - 2
        }
        return width * RetentionPeriod.trackFraction(forVisualPosition: position)
    }

    private static var dotBackground: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(red: 0x29 / 255.0, green: 0x29 / 255.0, blue: 0x29 / 255.0, alpha: 1.0)
                : NSColor(red: 0xFA / 255.0, green: 0xFA / 255.0, blue: 0xFA / 255.0, alpha: 1.0)
        })
    }
}

private struct RetentionKeyPointLabels: View {
    private static let yearLabelNudge: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width

            ZStack {
                ForEach(Array(RetentionPeriod.keyPointLabels.enumerated()), id: \.element) { index, label in
                    Text(label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .alignmentGuide(HorizontalAlignment.center) { dimensions in
                            horizontalAlignmentOffset(
                                for: index,
                                trackWidth: trackWidth,
                                labelWidth: dimensions.width
                            )
                        }
                }
            }
            .frame(width: trackWidth, height: geometry.size.height)
        }
        .frame(height: 16)
        .padding(.horizontal, 10)
    }

    private func horizontalAlignmentOffset(
        for index: Int,
        trackWidth: CGFloat,
        labelWidth: CGFloat
    ) -> CGFloat {
        let position = RetentionPeriod.keyPointPositions[index]
        var centerX = trackWidth * RetentionPeriod.trackFraction(forVisualPosition: position)

        switch index {
        case 0:
            centerX = labelWidth / 2
        case RetentionPeriod.keyPointLabels.count - 1:
            centerX = trackWidth - labelWidth / 2
        case 3:
            centerX += Self.yearLabelNudge
        default:
            break
        }

        return trackWidth / 2 - centerX
    }
}
