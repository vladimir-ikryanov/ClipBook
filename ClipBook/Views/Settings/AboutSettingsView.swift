import AppKit
import SwiftUI

struct AboutSettingsView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            backgroundDecoration

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 0) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable()
                        .frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    Text("ClipBook")
                        .font(.system(size: 28, weight: .semibold))
                        .padding(.top, 4)

                    Text(versionText)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)

                    Button(L10n.string("Check for Updates...")) {
                        coordinator.checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.top, 16)
                }

                Spacer()

                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        aboutLink(L10n.string("Website"), url: "https://clipbook.app?utm_source=app")
                        aboutLink(L10n.string("Support"), url: "https://clipbook.app/contacts/")
                        aboutLink(L10n.string("Changelog"), url: "https://clipbook.app/changelog/")
                        aboutLink(L10n.string("Feedback"), url: "https://feedback.clipbook.app/board/all")
                    }

                    Text(copyrightText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var copyrightText: String {
        let year = Calendar.current.component(.year, from: Date())
        return L10n.string("© %@ ClipBook. All rights reserved.", String(year))
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? ReleaseConfiguration.marketingVersion
        return L10n.string("Version %@ (%@)", version, Self.architectureName)
    }

    #if arch(arm64)
    private static var architectureName: String { L10n.string("Apple Silicon") }
    #else
    private static var architectureName: String { L10n.string("Intel") }
    #endif

    private var backgroundDecoration: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let blob1 = Self.blobTransform(for: Self.blob1Keyframes, progress: (time / 20).truncatingRemainder(dividingBy: 1))
            let blob2 = Self.blobTransform(for: Self.blob2Keyframes, progress: (time / 15).truncatingRemainder(dividingBy: 1))

            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 288, height: 288)
                    .blur(radius: 60)
                    .scaleEffect(blob1.scale)
                    .offset(x: -120 + blob1.x, y: -80 + blob1.y)

                Circle()
                    .fill(Color.blue.opacity(0.05))
                    .frame(width: 208, height: 208)
                    .blur(radius: 60)
                    .scaleEffect(blob2.scale)
                    .offset(x: 180 + blob2.x, y: 120 + blob2.y)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }

    private struct BlobTransform {
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
    }

    private static let blob1Keyframes: [(Double, BlobTransform)] = [
        (0.0, BlobTransform(x: 0, y: 0, scale: 1)),
        (0.25, BlobTransform(x: -20, y: 200, scale: 1.5)),
        (0.5, BlobTransform(x: 200, y: 250, scale: 1.1)),
        (0.75, BlobTransform(x: 250, y: 150, scale: 1.3)),
        (1.0, BlobTransform(x: 0, y: 0, scale: 1)),
    ]

    private static let blob2Keyframes: [(Double, BlobTransform)] = [
        (0.0, BlobTransform(x: 0, y: 0, scale: 1)),
        (0.25, BlobTransform(x: -50, y: -150, scale: 1.3)),
        (0.5, BlobTransform(x: 100, y: -200, scale: 1)),
        (0.75, BlobTransform(x: 100, y: 200, scale: 1.3)),
        (1.0, BlobTransform(x: 0, y: 0, scale: 1)),
    ]

    private static func blobTransform(for keyframes: [(Double, BlobTransform)], progress: Double) -> BlobTransform {
        let clampedProgress = progress - floor(progress)

        guard clampedProgress < 1 else {
            return keyframes.last?.1 ?? BlobTransform(x: 0, y: 0, scale: 1)
        }

        guard let endIndex = keyframes.firstIndex(where: { $0.0 > clampedProgress }) else {
            return keyframes.last?.1 ?? BlobTransform(x: 0, y: 0, scale: 1)
        }

        let start = keyframes[endIndex - 1]
        let end = keyframes[endIndex]
        let segmentProgress = (clampedProgress - start.0) / (end.0 - start.0)
        let easedProgress = easeInOut(segmentProgress)

        return BlobTransform(
            x: lerp(start.1.x, end.1.x, easedProgress),
            y: lerp(start.1.y, end.1.y, easedProgress),
            scale: lerp(start.1.scale, end.1.scale, easedProgress)
        )
    }

    private static func lerp(_ start: CGFloat, _ end: CGFloat, _ progress: Double) -> CGFloat {
        start + (end - start) * progress
    }

    private static func easeInOut(_ progress: Double) -> Double {
        progress < 0.5
            ? 2 * progress * progress
            : 1 - pow(-2 * progress + 2, 2) / 2
    }

    private func aboutLink(_ title: String, url: String) -> some View {
        Button(title) {
            guard let url = URL(string: url) else {
                return
            }
            NSWorkspace.shared.open(url)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.callout)
    }
}
