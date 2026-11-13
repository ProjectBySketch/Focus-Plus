//
//  SettingsSheet.swift
//  Focus Plus
//

import SwiftUI

/// Settings is an index now, not one long scroll: a header that says what the
/// app is set to, then one row per subject that opens its own page. Everything
/// that used to be a fourteen-section list is one tap away.
struct SettingsSheet: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var jit = JITManager.shared
    @ObservedObject private var flags = FlagsStore.shared
    @Environment(\.dismiss) private var dismiss
    /// The erase confirmation is presented with the sheet's own state: the
    /// manager's flag also drives a dialog behind this sheet, and the
    /// conflicting presentation stopped the dialog from ever appearing here.
    @State private var showEraseConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        SettingRow(symbol: "paintpalette.fill",
                                   title: "Appearance",
                                   subtitle: "\(customization.themePreset.displayName) look · \(customization.accent.displayName) accent")
                    }

                    NavigationLink {
                        StartPageSettingsView()
                    } label: {
                        SettingRow(symbol: "square.grid.2x2.fill",
                                   title: "Start page",
                                   subtitle: "Blocks and favorites")
                    }

                    NavigationLink {
                        CommandBarSettingsView()
                    } label: {
                        SettingRow(symbol: "rectangle.bottomhalf.filled",
                                   title: "Command bar",
                                   subtitle: "\(customization.chromePosition.displayName) · "
                                        + (customization.autoHideChrome ? "auto-hide on" : "always visible"))
                    }

                    NavigationLink {
                        SearchSettingsView()
                    } label: {
                        SettingRow(symbol: "magnifyingglass",
                                   title: "Search",
                                   subtitle: "\(customization.searchEngine.shortName) · new tabs, zoom")
                    }
                } header: {
                    Text("Interface")
                }

                Section {
                    Button {
                        dismiss()
                        manager.enterHistory()
                    } label: {
                        SettingRow(symbol: "clock.arrow.circlepath",
                                   title: "Browsing history",
                                   subtitle: "Opens as a page inside the tab")
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                        manager.enterFlags()
                    } label: {
                        SettingRow(symbol: "flag.checkered",
                                   title: "Flags",
                                   subtitle: "\(flags.changedCount) changed · experimental switches")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ExtensionsSettingsView(manager: manager)
                    } label: {
                        SettingRow(symbol: "puzzlepiece.extension.fill",
                                   title: "Extensions",
                                   subtitle: "Chrome-style and Lua extensions")
                    }
                } header: {
                    Text("Browsing")
                } footer: {
                    Text("History and Flags open as pages inside the current tab — each with its own header, search and a full list — not as sheets.")
                }

                Section {
                    NavigationLink {
                        PrivacySettingsView(manager: manager)
                    } label: {
                        SettingRow(symbol: "hand.raised.fill",
                                   title: "Privacy",
                                   subtitle: manager.isIncognito ? "Incognito is on" : "Pop-ups, cookies, encrypted DNS")
                    }

                    NavigationLink {
                        JITPairingView()
                    } label: {
                        SettingRow(symbol: "bolt.horizontal.circle.fill",
                                   title: "JIT & Pairing",
                                   subtitle: jit.isPaired
                                        ? "\(jit.pairing?.displayName ?? "Paired") · \(jit.tunnel.label)"
                                        : "Optional · no pairing file")
                    }

                    NavigationLink {
                        NetworkSettingsView()
                    } label: {
                        SettingRow(symbol: "lock.shield.fill",
                                   title: "Personal VPN",
                                   subtitle: "IKEv2 server you already have")
                    }
                } header: {
                    Text("Privacy & device")
                }

                Section {
                    TrackerCountRow(manager: manager)
                    LabeledRow("Pop-ups blocked", "\(manager.popupsBlocked)")
                    LabeledRow("Pages loaded", "\(manager.pagesVisited)")
                    LabeledRow("Erasures", "\(manager.erasures)")
                    Button(role: .destructive) {
                        showEraseConfirmation = true
                    } label: {
                        Label("Erase browsing data now", systemImage: "trash")
                    }
                } header: {
                    Text("This session")
                } footer: {
                    Text("Erasing also clears the pop-up count and site exceptions.")
                }

                if flags.isEnabled(.browserLogs) {
                    BrowserLogSettingsSection()
                }

                Section {
                    NavigationLink {
                        AboutSettingsView()
                    } label: {
                        SettingRow(symbol: "info.circle.fill",
                                   title: "About Focus Plus",
                                   subtitle: "Version 1.0 · ProjectBySketch™")
                    }
                } footer: {
                    HStack(spacing: 4) {
                        Spacer()
                        Text("made with")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(Color.pink)
                        Text("by ProjectBySketch™")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                customization.keepCookies
                    ? "Clear cookies and sign-ins too?"
                    : "Erase browsing data?",
                isPresented: $showEraseConfirmation,
                titleVisibility: .visible
            ) {
                if customization.keepCookies {
                    Button("Erase everything, including cookies and sign-ins", role: .destructive) {
                        manager.erase(clearCookies: true)
                    }
                    Button("Erase history only, keep cookies and sign-ins") {
                        manager.erase(clearCookies: false)
                    }
                } else {
                    Button("Erase everything", role: .destructive) {
                        manager.erase(clearCookies: true)
                    }
                    Button("Turn on Keep cookies and sign-ins") {
                        customization.keepCookies = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(customization.keepCookies
                     ? "Cookies and website sign-ins are set to stay on this device. Keep them, or wipe them along with the history."
                     : "Cookies and sign-ins die with every session. You can start keeping them instead.")
            }
        }
    }

    /// The card at the top: the mark, the version, and the three choices that
    /// decide how the app looks, in one line.
    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            AppLogo(style: .tile, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text("Focus Plus")
                    .font(.title3.bold())
                Text("\(customization.themePreset.displayName) look · \(customization.accent.displayName) · \(customization.searchEngine.shortName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    statusChip(symbol: "shippingbox.fill",
                               text: "1.0 (1)",
                               tint: .white.opacity(0.7))
                    statusChip(symbol: manager.isIncognito ? "eyeglasses" : "checkmark.shield.fill",
                               text: manager.isIncognito ? "Incognito" : "Saved browsing",
                               tint: manager.isIncognito ? Theme.incognito : Theme.accent)
                    if jit.isPaired {
                        statusChip(symbol: jit.tunnel.symbol,
                                   text: jit.tunnel == .reachable ? "JIT" : "JIT off",
                                   tint: jit.tunnel == .reachable ? Theme.accent : .white.opacity(0.5))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            ZStack {
                Theme.backdropGradient
                LinearGradient(
                    colors: [Theme.accent.opacity(0.30), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10))
        )
    }

    private func statusChip(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.10), in: Capsule())
    }
}

private struct TrackerCountRow: View {
    @ObservedObject var manager: TabManager

    var body: some View {
        if let model = manager.activeTab?.model {
            TrackerCount(model: model)
        }
    }
}

private struct TrackerCount: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        HStack {
            Text("Trackers seen")
            Spacer()
            Text("\(model.trackersSeen)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
