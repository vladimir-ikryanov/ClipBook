import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @EnvironmentObject private var coordinator: AppCoordinator

    private var sidebarSelection: Binding<SettingsSection> {
        Binding(
            get: { coordinator.settingsSection },
            set: { newValue in
                guard newValue != coordinator.settingsSection else { return }
                coordinator.settingsSection = newValue
            }
        )
    }

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: sidebarSelection)
                .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 170)
        } detail: {
            if #available(macOS 27.0, *) {
                // On macOS 27 a custom title item in the navigation placement
                // drifts towards the sidebar toggle and gets truncated when an
                // accessory is present, so the detail column uses the system
                // navigation title, which always sits at the column's leading
                // edge, and keeps its accessories at the trailing edge.
                detailView
                    .navigationTitle(coordinator.settingsSection.detailTitle)
                    .toolbar {
                        trailingAccessories
                            .sharedBackgroundVisibility(.hidden)
                    }
            } else {
                detailView
            }
        }
        .background(.regularMaterial)
        .toolbar {
            // macOS 26 and earlier render the custom title item correctly, so
            // they keep the original toolbar with the title next to the
            // sidebar and the license badge next to the title.
            if #unavailable(macOS 27.0) {
                if #available(macOS 26.0, *) {
                    navigationTitle
                        .sharedBackgroundVisibility(.hidden)
                    sectionAccessory
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    navigationTitle
                    sectionAccessory
                }
            }
        }
        .onDisappear {
            coordinator.savePreferences()
        }
    }

    private var detailView: some View {
        SettingsDetailView(
            selection: coordinator.settingsSection,
            model: model
        )
        .environmentObject(coordinator)
    }

    /// Custom title used on macOS 26 and earlier.
    private var navigationTitle: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(alignment: .center, spacing: 12) {
                Text(coordinator.settingsSection.detailTitle)
                    .font(.system(size: 16, weight: .semibold))

                if coordinator.settingsSection == .license {
                    LicenseStatusBadge(state: coordinator.licenseState)
                }
            }
            .padding(.leading, 12)
        }
    }

    /// Accessories used on macOS 26 and earlier, where the license badge is
    /// part of the title item.
    @ToolbarContentBuilder
    private var sectionAccessory: some ToolbarContent {
        if coordinator.settingsSection == .sounds {
            soundEffectsToggle
        }
    }

    /// Accessories used on macOS 27 and later. They sit at the trailing edge
    /// of the detail column, aligned with the trailing edge of the section
    /// groups, which are inset by 20 points in SettingsDetailView.
    @ToolbarContentBuilder
    private var trailingAccessories: some ToolbarContent {
        if coordinator.settingsSection == .license {
            ToolbarItem(placement: .primaryAction) {
                LicenseStatusBadge(state: coordinator.licenseState)
                    .padding(.trailing, 8)
            }
        }

        if coordinator.settingsSection == .sounds {
            soundEffectsToggle
        }
    }

    private var soundEffectsToggle: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Toggle(
                L10n.string("Enable sound effects"),
                isOn: $model.preferences.soundEffectsEnabled
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(L10n.string("Enable sound effects"))
            // Aligns the switch with the trailing edge of the section groups,
            // which are inset by 20 points in SettingsDetailView.
            .padding(.trailing, 8)
        }
    }
}
