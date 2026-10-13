import Foundation
import Combine

#if CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)
import ClipBookCommercialLicensing
#endif

@MainActor
final class LicensingService: ObservableObject {
    enum State: Equatable {
        case unavailable
        case trial(daysLeft: Int)
        case trialExpired
        case activated

        var isActivated: Bool {
            self == .activated
        }

        // An expired trial keeps the history on screen, but read-only: it is
        // browsed and organized, not copied, pasted or changed.
        var isTrialExpired: Bool {
            self == .trialExpired
        }
    }

    enum LicensingError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Licensing is not available in this build."
            }
        }
    }

    protocol Backend {
        func refresh(licenseKey: String) -> State
        func recordTrialUsage(licenseKey: String)
        func activate(licenseKey: String) async throws
        func deactivate(licenseKey: String) async throws
        func sendFeedback(text: String) async
    }

    @Published private(set) var state: State = .unavailable

    private let backend: any Backend

    init(backend: (any Backend)? = nil) {
        self.backend = backend ?? Self.makeDefaultBackend()
    }

    private static func makeDefaultBackend() -> any Backend {
        #if CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)
        return ClipBookCommercialLicensingBackend()
        #elseif CLIPBOOK_COMMERCIAL_IN_TREE
        return ClipBookCommercialLicensingBackend()
        #else
        return UnavailableLicensingBackend()
        #endif
    }

    func refresh(licenseKey: String) {
        #if DEBUG
        // Launching with `-DebugTrialDaysLeft <days>` previews the trial UI in
        // builds without the commercial licensing backend.
        if UserDefaults.standard.object(forKey: "DebugTrialDaysLeft") != nil {
            let daysLeft = UserDefaults.standard.integer(forKey: "DebugTrialDaysLeft")
            state = daysLeft > 0 ? .trial(daysLeft: daysLeft) : .trialExpired
            return
        }
        #endif
        state = backend.refresh(licenseKey: licenseKey)
    }

    // The trial runs for a number of days the app was used, so this is called
    // when the user actually opens the history, not when the app merely runs.
    func recordTrialUsage(licenseKey: String) {
        backend.recordTrialUsage(licenseKey: licenseKey)
        refresh(licenseKey: licenseKey)
    }

    func activate(licenseKey: String) async throws {
        try await backend.activate(licenseKey: licenseKey)
        refresh(licenseKey: licenseKey)
    }

    func deactivate(licenseKey: String) async throws {
        try await backend.deactivate(licenseKey: licenseKey)
        refresh(licenseKey: "")
    }

    func sendFeedback(text: String) async {
        await backend.sendFeedback(text: text)
    }
}

private struct UnavailableLicensingBackend: LicensingService.Backend {
    func refresh(licenseKey: String) -> LicensingService.State {
        .unavailable
    }

    func recordTrialUsage(licenseKey: String) {}

    func activate(licenseKey: String) async throws {
        throw LicensingService.LicensingError.unavailable
    }

    func deactivate(licenseKey: String) async throws {
        throw LicensingService.LicensingError.unavailable
    }

    func sendFeedback(text: String) async {}
}

#if (CLIPBOOK_COMMERCIAL && canImport(ClipBookCommercialLicensing)) || CLIPBOOK_COMMERCIAL_IN_TREE
private struct ClipBookCommercialLicensingBackend: LicensingService.Backend {
    private let client = CommercialLicensingClient()

    func refresh(licenseKey: String) -> LicensingService.State {
        switch client.refresh(licenseKey: licenseKey) {
        case .activated:
            return .activated
        case .trial(let daysLeft):
            return daysLeft > 0 ? .trial(daysLeft: daysLeft) : .trialExpired
        case .trialExpired:
            return .trialExpired
        }
    }

    func recordTrialUsage(licenseKey: String) {
        client.recordTrialUsage(licenseKey: licenseKey)
    }

    func activate(licenseKey: String) async throws {
        try await client.activate(licenseKey: licenseKey)
    }

    func deactivate(licenseKey: String) async throws {
        try await client.deactivate(licenseKey: licenseKey)
    }

    func sendFeedback(text: String) async {
        await client.sendFeedback(text: text)
    }
}
#endif
