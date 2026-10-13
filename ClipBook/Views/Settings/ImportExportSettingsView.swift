import SwiftUI

struct ImportExportSettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var operationProgress: ArchiveOperationProgress?

    private var isProgressSheetPresented: Binding<Bool> {
        Binding(
            get: { operationProgress != nil },
            set: { _ in }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("Move ClipBook history and tags between ClipBook installations. Settings are not included."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            SettingsSectionGroup(L10n.string("Export")) {
                SettingsRow(
                    title: L10n.string("Export history and tags"),
                    description: L10n.string("Create a ClipBook archive containing history items, tags, and copied image assets.")
                ) {
                    Button(L10n.string("Export...")) {
                        exportArchive()
                    }
                    .disabled(operationProgress != nil)
                }
            }

            SettingsSectionGroup(L10n.string("Import")) {
                SettingsRow(
                    title: L10n.string("Import history and tags"),
                    description: L10n.string("Import a ClipBook archive. Existing matching items are updated, and existing tags are reused by name.")
                ) {
                    Button(L10n.string("Import...")) {
                        importArchive()
                    }
                    .disabled(operationProgress != nil)
                }
            }

        }
        .sheet(isPresented: isProgressSheetPresented) {
            if let operationProgress {
                ArchiveProgressSheet(
                    progress: operationProgress,
                    close: {
                        self.operationProgress = nil
                    }
                )
                    .interactiveDismissDisabled(true)
            }
        }
    }

    private func exportArchive() {
        let didStart = coordinator.beginExportHistoryArchive(
            progress: { progress in
                updateProgress(kind: .exportArchive, progress: progress)
            },
            completion: { result in
                switch result {
                case .success(let exportResult):
                    operationProgress = ArchiveOperationProgress(
                        kind: .exportArchive,
                        completedItemCount: exportResult.itemCount,
                        totalItemCount: exportResult.itemCount,
                        result: .success(
                            L10n.string(
                                "Exported %d items and %d tags to %@.",
                                exportResult.itemCount,
                                exportResult.tagCount,
                                exportResult.url.lastPathComponent
                            )
                        )
                    )
                case .failure(let error):
                    operationProgress = operationProgress?.completed(with: .failure(error.localizedDescription))
                }
            }
        )
        if didStart {
            operationProgress = ArchiveOperationProgress(
                kind: .exportArchive,
                completedItemCount: 0,
                totalItemCount: model.items.count
            )
        }
    }

    private func importArchive() {
        let didStart = coordinator.beginImportHistoryArchive(
            progress: { progress in
                updateProgress(kind: .importArchive, progress: progress)
            },
            completion: { result in
                switch result {
                case .success(let importResult):
                    operationProgress = ArchiveOperationProgress(
                        kind: .importArchive,
                        completedItemCount: importResult.itemCount,
                        totalItemCount: importResult.itemCount,
                        result: .success(
                            L10n.string("Imported %d items and %d tags.", importResult.itemCount, importResult.tagCount)
                        )
                    )
                case .failure(let error):
                    operationProgress = operationProgress?.completed(with: .failure(error.localizedDescription))
                }
            }
        )
        if didStart {
            operationProgress = ArchiveOperationProgress(
                kind: .importArchive,
                completedItemCount: 0,
                totalItemCount: 0
            )
        }
    }

    private func updateProgress(kind: ArchiveOperationKind, progress: ClipBookArchiveProgress) {
        operationProgress = ArchiveOperationProgress(
            kind: kind,
            completedItemCount: progress.completedItemCount,
            totalItemCount: progress.totalItemCount,
            result: operationProgress?.result
        )
    }
}

private enum ArchiveOperationKind {
    case importArchive
    case exportArchive

    var title: String {
        switch self {
        case .importArchive:
            return L10n.string("Importing History")
        case .exportArchive:
            return L10n.string("Exporting History")
        }
    }

    var completedTitle: String {
        switch self {
        case .importArchive:
            return L10n.string("History Imported")
        case .exportArchive:
            return L10n.string("History Exported")
        }
    }

    var failedTitle: String {
        switch self {
        case .importArchive:
            return L10n.string("Import Failed")
        case .exportArchive:
            return L10n.string("Export Failed")
        }
    }
}

private enum ArchiveOperationResult {
    case success(String)
    case failure(String)
}

private struct ArchiveOperationProgress {
    var kind: ArchiveOperationKind
    var completedItemCount: Int
    var totalItemCount: Int
    var result: ArchiveOperationResult?

    var isCompleted: Bool {
        result != nil
    }

    var title: String {
        switch result {
        case .success:
            return kind.completedTitle
        case .failure:
            return kind.failedTitle
        case nil:
            return kind.title
        }
    }

    var fractionCompleted: Double? {
        guard totalItemCount > 0 else {
            return isCompleted ? 1 : nil
        }
        return Double(completedItemCount) / Double(totalItemCount)
    }

    var itemCountText: String {
        L10n.string("(%d/%d)", completedItemCount, totalItemCount)
    }

    var resultText: String? {
        switch result {
        case .success(let message), .failure(let message):
            return message
        case nil:
            return nil
        }
    }

    func completed(with result: ArchiveOperationResult) -> ArchiveOperationProgress {
        ArchiveOperationProgress(
            kind: kind,
            completedItemCount: completedItemCount,
            totalItemCount: totalItemCount,
            result: result
        )
    }
}

private struct ArchiveProgressSheet: View {
    let progress: ArchiveOperationProgress
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(progress.title)
                .font(.headline)

            if let fractionCompleted = progress.fractionCompleted {
                ProgressView(value: fractionCompleted, total: 1)
            } else {
                ProgressView()
            }

            HStack(alignment: .center, spacing: 12) {
                statusLabel

                Spacer()

                if progress.isCompleted {
                    Button(L10n.string("Close"), action: close)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .frame(width: 400)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch progress.result {
        case .success(let message):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(message)
            }
            .font(.body)
        case .failure(let message):
            Text(message)
                .font(.body)
        case nil:
            Text(progress.itemCountText)
                .font(.body)
        }
    }
}
