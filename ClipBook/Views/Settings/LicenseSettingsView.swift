import AppKit
import SwiftUI

struct LicenseStatusBadge: View {
    let state: LicensingService.State

    var body: some View {
        Text(title)
            .font(.subheadline)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(statusBadgeColor)
            .overlay {
                Capsule(style: .continuous)
                    .stroke(statusBadgeColor, lineWidth: 1)
            }
    }

    private var title: String {
        switch state {
        case .activated:
            return L10n.string("Activated")
        case .trial(let daysLeft):
            return L10n.string("Trial: %@ days left", String(daysLeft))
        case .trialExpired:
            return L10n.string("Trial expired")
        case .unavailable:
            return L10n.string("Unavailable")
        }
    }

    private var statusBadgeColor: Color {
        if state == .activated {
            return Color(red: 0x15 / 255.0, green: 0xCF / 255.0, blue: 0x20 / 255.0)
        }

        if state == .trialExpired {
            return Color.red
        }

        return Color.accentColor
    }
}

struct LicenseSettingsView: View {
    private static let licenseKeyPattern = #"(?<![A-Za-z0-9])(?:[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}|[A-Za-z0-9]{4}(?:-[A-Za-z0-9]{4}){3}-[A-Za-z0-9]{16})(?![A-Za-z0-9])"#

    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var showActivationError = false
    @State private var activationErrorMessage = ""
    @State private var draftLicenseKey = ""
    @State private var isRequestInProgress = false

    private var isLicenseKeyInvalid: Bool {
        Self.extractLicenseKey(from: draftLicenseKey) != draftLicenseKey
    }

    private var isActivated: Bool {
        coordinator.licenseState.isActivated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !isActivated {
                trialDescription
            }

            Text(L10n.string("License key:"))

            TextField("XXXX-0000-0000-0000-0000000000000000", text: licenseKeyBinding)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .disabled(isActivated || isRequestInProgress)
                .onChange(of: draftLicenseKey) { _ in
                    sanitizeDraftLicenseKey()
                    coordinator.updateUnactivatedLicenseKey(draftLicenseKey)
                }

            if !isActivated {
                Text(L10n.string("You can find your license key in the email you received after purchasing ClipBook."))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !isActivated {
                HStack(spacing: 12) {
                    Button(L10n.string("Activate")) {
                        handleActivate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLicenseKeyInvalid || isRequestInProgress)

                    Button(L10n.string("Buy License")) {
                        coordinator.openBuyLicenseURL()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                HStack(spacing: 12) {
                    Button(L10n.string("Deactivate")) {
                        handleDeactivate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRequestInProgress)

                    Button(L10n.string("Copy Key")) {
                        copyLicenseKey()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(draftLicenseKey.isEmpty)
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            draftLicenseKey = model.preferences.licenseKey
            fillLicenseKeyFromClipboardIfNeeded()
            coordinator.refreshLicensingState()
        }
        .alert(L10n.string("The license key cannot be activated :("), isPresented: $showActivationError) {
            Button(L10n.string("Help me")) {
                openActivationHelp()
            }
            Button(L10n.string("Close"), role: .cancel) {}
        } message: {
            Text(activationErrorMessage)
        }
    }

    private var trialDescription: some View {
        Text(trialDescriptionText)
            .font(.body)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }

    private var trialDescriptionText: String {
        switch coordinator.licenseState {
        case .trial(let daysLeft):
            return L10n.string("You have %@ days left in your ClipBook trial. To continue using ClipBook after the trial ends, please purchase a license key from the online store and activate it.", String(daysLeft))
        case .trialExpired:
            return L10n.string("Your ClipBook trial has expired. Please purchase a license key from the online store and activate it to continue using clipboard history.")
        case .unavailable:
            return L10n.string("Licensing is not available in this build.")
        case .activated:
            return ""
        }
    }

    private var licenseKeyBinding: Binding<String> {
        Binding(
            get: { draftLicenseKey },
            set: { newValue in
                draftLicenseKey = newValue
            }
        )
    }

    private func sanitizeDraftLicenseKey() {
        let sanitized = draftLicenseKey
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard sanitized != draftLicenseKey else {
            return
        }

        draftLicenseKey = sanitized
    }

    private func fillLicenseKeyFromClipboardIfNeeded() {
        guard draftLicenseKey.isEmpty,
              let clipboardValue = NSPasteboard.general.string(forType: .string),
              let licenseKey = Self.extractLicenseKey(from: clipboardValue)
        else {
            return
        }

        draftLicenseKey = licenseKey
    }

    private static func extractLicenseKey(from value: String) -> String? {
        guard let range = value.range(of: licenseKeyPattern, options: .regularExpression) else {
            return nil
        }

        return String(value[range])
    }

    private func handleActivate() {
        isRequestInProgress = true
        Task {
            do {
                try await coordinator.activateLicenseKey(draftLicenseKey)
                draftLicenseKey = model.preferences.licenseKey
            } catch {
                activationErrorMessage = error.localizedDescription
                showActivationError = true
            }
            isRequestInProgress = false
        }
    }

    private func handleDeactivate() {
        isRequestInProgress = true
        Task {
            do {
                try await coordinator.deactivateLicenseKey()
            } catch {
                activationErrorMessage = error.localizedDescription
                showActivationError = true
            }
            isRequestInProgress = false
        }
    }

    private func copyLicenseKey() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(draftLicenseKey, forType: .string)
    }

    private func openActivationHelp() {
        let subject = L10n.string("ClipBook Activation Error")
        let body = L10n.string("License Key: %@", draftLicenseKey)
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "vladimir.ikryanov@clipbook.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]
        guard let url = components.url else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
