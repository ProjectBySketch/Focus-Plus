//
//  SettingsSheet.swift
//  Focus Plus
//

import NetworkExtension
import UIKit
import SwiftUI

/// The pages Settings can open in a sheet of its own.
private enum SettingsSubSheet: String, Identifiable {
    case history
    case flags

    var id: String { rawValue }
}

struct SettingsSheet: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var extManager = ExtensionManager.shared
    @ObservedObject private var dnsManager = EncryptedDNSManager.shared
    @ObservedObject private var vpnManager = PersonalVPNManager.shared
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var flags = FlagsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var subSheet: SettingsSubSheet?
    @State private var vpnPassword = ""
    @State private var activeIcon: String? = UIApplication.shared.alternateIconName
    @ObservedObject private var favorites = FavoritesStore.shared
    @State private var showAddFavorite = false
    @State private var newFavoriteTitle = ""
    @State private var newFavoriteURL = ""
    /// The erase confirmation is presented with the sheet's own state: the
    /// manager's flag also drives a dialog behind this sheet, and the
    /// conflicting presentation stopped the dialog from ever appearing here.
    @State private var showEraseConfirmation = false

    private var vpnFieldsLocked: Bool {
        switch vpnManager.connectionStatus {
        case .connecting, .connected, .reasserting, .disconnecting: return true
        default: return false
        }
    }

    private var vpnStatusColor: Color {
        switch vpnManager.connectionStatus {
        case .connected: return Theme.accent
        case .connecting, .reasserting, .disconnecting: return .orange
        case .invalid: return .red
        default: return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(extManager.extensions) { ext in
                        extensionRow(ext)
                    }
                    Button {
                        extManager.reload()
                        manager.refreshAllExtensions()
                    } label: {
                        Label("Rescan extensions folder", systemImage: "arrow.clockwise")
                    }
                } header: {
                    Text("Chrome-style extensions")
                } footer: {
                    Text("Add your own: create a folder in Files → Focus Plus → Extensions containing a Chrome manifest.json (MV2 or MV3) with content scripts or a background script written in JavaScript or Lua (.lua files run on an embedded Lua VM and use the global focus table), then rescan. Toggles apply to the next page load.")
                }

                Section {
                    ForEach(StartPageSection.allCases) { section in
                        Toggle(isOn: Binding(
                            get: { customization.startPageSections.contains(section) },
                            set: { on in
                                if on {
                                    customization.startPageSections.insert(section)
                                } else {
                                    customization.startPageSections.remove(section)
                                }
                            }
                        )) {
                            Label(section.title, systemImage: section.symbol)
                        }
                    }
                    Button("Show every block again") {
                        customization.startPageSections = Set(StartPageSection.allCases)
                    }
                } header: {
                    Text("Start page")
                } footer: {
                    Text("Which blocks the start page draws: the greeting and live clock, the favorites grid you can add to and long-press to prune, the other open tabs, the pages you read last, shortcuts to History, Flags and Settings, and the session read-out. Turn any of them off for a quieter page; everything stays saved on this device.")
                }

                Section {
                    ForEach(favorites.sites) { site in
                        HStack(spacing: 10) {
                            Image(systemName: site.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(site.title).font(.subheadline)
                                Text(site.host)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Button(role: .destructive) {
                                favorites.remove(site.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        showAddFavorite = true
                    } label: {
                        Label("Add a favorite…", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Favorites")
                } footer: {
                    Text("The grid at the top of the start page. Add a name and an address here or from the page itself, remove one with the bin, or long-press a tile on the start page to prune it there.")
                }

                Section {
                    Button {
                        dismiss()
                        manager.enterHistory()
                    } label: {
                        Label("Browsing history", systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        dismiss()
                        manager.enterFlags()
                    } label: {
                        Label("Flags · experimental switches", systemImage: "flag.checkered")
                    }
                } header: {
                    Text("Browsing")
                } footer: {
                    Text("Both open as pages inside the current tab, not as sheets: each has its own header, a back button, search and a full list. History keeps every visit on this device, grouped by day, and you can delete one visit, one day or one site at a time. Flags gathers every switch that changes how the browser behaves, including the ones still being tried out. Both pages are also reachable as focus://history and focus://flags from the address bar.")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ThemePreset.allCases) { preset in
                                themeCard(preset)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Each look paints the chrome, the start page and the tab switcher; the pages themselves are unaffected. The accent color below sits on top of whichever one you pick. Christmas is one look among them: it adds the pine-green night, the falling snow and the holiday greeting, and you can switch it off by picking any other.")
                }

                Section {
                    Picker("Position", selection: $customization.chromePosition) {
                        ForEach(ChromePosition.allCases) { position in
                            Label(position.displayName, systemImage: position.symbol).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Auto-hide while scrolled", isOn: $customization.autoHideChrome)
                } header: {
                    Text("Command bar")
                } footer: {
                    Text("The bar stays wherever you put it — no dragging it around. With auto-hide on it tucks itself away while you scroll down and returns as soon as you scroll up or tap the address field. It always steps aside for the keyboard, so the space bar is never covered while you search.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent color")
                        HStack(spacing: 12) {
                            ForEach(Accent.allCases) { choice in
                                Button {
                                    withAnimation { customization.accent = choice }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(choice.color)
                                            .frame(width: 34, height: 34)
                                        if customization.accent == choice {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.black.opacity(0.65))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Picker("Search engine", selection: $customization.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    if customization.searchEngine == .custom {
                        TextField("Search URL template with %s", text: $customization.customSearchTemplate)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    Toggle("Verify domains over encrypted DNS", isOn: $customization.verifyDomains)

                    Toggle("Open homepage in new tabs", isOn: $customization.homepageEnabled)
                    if customization.homepageEnabled {
                        TextField("Homepage address", text: $customization.homepageText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }

                    Toggle("Minimalistic mode", isOn: $customization.minimalisticMode)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Page zoom")
                            Spacer()
                            Text("\(Int((customization.pageZoom * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $customization.pageZoom, in: 0.5...2.0, step: 0.05)
                    }
                } header: {
                    Text("Customize")
                } footer: {
                    Text("The accent colors the interface, the engine the address bar sends searches to, and the zoom of every page. The homepage opens in tabs created afterwards. A custom search template is an http(s) URL containing %s where the search term goes. Focus Search is Focus Plus's own engine and the default: it loads a clean results page with Web and Images tabs right in the tab, and its optional domain verification uses the encrypted DNS resolver chosen in Privacy. Minimalistic mode hides the start-page shortcuts and the incognito and erase buttons — those stay available in Settings. These choices are saved on this device.")
                }

                Section {
                    HStack(spacing: 12) {
                        iconButton(title: "Default", symbol: "shield.lefthalf.filled", name: nil)
                        iconButton(title: "Minimal", symbol: "shield", name: "Minimal")
                    }
                } header: {
                    Text("App icon")
                } footer: {
                    Text("The icon shown on the Home Screen. iOS asks for confirmation in its own dialog before the icon changes.")
                }

                Section {
                    Toggle(isOn: Binding(
                        get: { manager.isIncognito },
                        set: { _ in manager.toggleIncognito() }
                    )) {
                        Label("Incognito mode", systemImage: "eyeglasses")
                            .foregroundStyle(manager.isIncognito ? Theme.incognito : .primary)
                    }

                    Toggle(isOn: $manager.popupBlockerEnabled) {
                        Label("Block pop-ups", systemImage: "hand.raised")
                    }

                    Toggle(isOn: $customization.keepCookies) {
                        Label("Keep cookies and sign-ins", systemImage: "person.badge.key")
                    }

                    Toggle(isOn: Binding(
                        get: { dnsManager.isEnabled },
                        set: { _ in dnsManager.toggle() }
                    )) {
                        Label("Encrypted DNS", systemImage: "lock.shield")
                            .foregroundStyle(dnsManager.isEnabled ? Theme.accent : .primary)
                    }
                    if dnsManager.isEnabled {
                        Picker("Resolver", selection: $dnsManager.resolver) {
                            ForEach(EncryptedDNSManager.Resolver.allCases) { resolver in
                                Text(resolver.rawValue).tag(resolver)
                            }
                        }
                    }
                    if let host = manager.activeTab?.model.displayedURL?.host {
                        Button {
                            manager.togglePopupAllowance(for: host)
                        } label: {
                            Label(
                                manager.isPopupSiteAllowed(host)
                                    ? "Stop allowing pop-ups for \(host)"
                                    : "Allow pop-ups for \(host)",
                                systemImage: manager.isPopupSiteAllowed(host) ? "xmark.circle" : "checkmark.circle"
                            )
                        }
                        .disabled(!manager.popupBlockerEnabled && !manager.isPopupSiteAllowed(host))
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Incognito tints the interface and hides page content in the app switcher; switching modes wipes the session. Pop-ups from script-opened windows are blocked by default, while tapped links stay in the current tab. Keep cookies and sign-ins is on by default, so browsing outside incognito is saved on this device and website logins survive erases and relaunches; erasing always asks first whether to clear them too, and you can turn keeping off entirely. Incognito never saves anything. Encrypted DNS protects lookups from the local network, but the resolver can see them; it is not a VPN.")
                }

                if !manager.allowedPopupSites.isEmpty {
                    Section {
                        ForEach(manager.allowedPopupSites.sorted(), id: \.self) { site in
                            HStack {
                                Label(site, systemImage: "globe")
                                    .lineLimit(1)
                                Spacer()
                                Button("Remove") {
                                    manager.togglePopupAllowance(for: site)
                                }
                                .font(.subheadline)
                            }
                        }
                    } header: {
                        Text("Allowed pop-up sites · this session")
                    } footer: {
                        Text("These exceptions are held in memory only and are cleared when browsing data is erased or incognito mode changes.")
                    }
                }

                JITPairingSection()

                Section {
                    HStack {
                        Text("Connection")
                        Spacer()
                        Circle()
                            .fill(vpnStatusColor)
                            .frame(width: 8, height: 8)
                        Text(vpnManager.statusDescription)
                            .foregroundStyle(vpnStatusColor)
                    }
                    TextField("VPN server host or IP", text: $vpnManager.serverAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(vpnFieldsLocked)
                    TextField("IKEv2 remote identifier", text: $vpnManager.remoteIdentifier)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(vpnFieldsLocked)
                    TextField("Username", text: $vpnManager.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(vpnFieldsLocked)
                    SecureField("VPN password (saved to Keychain)", text: $vpnPassword)
                        .disabled(vpnFieldsLocked)

                    if let error = vpnManager.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if vpnManager.isActiveOrConnecting {
                        Button(role: .destructive) {
                            vpnManager.disconnect()
                        } label: {
                            Label("Disconnect VPN", systemImage: "stop.circle")
                        }
                    } else {
                        Button {
                            vpnManager.connect(password: vpnPassword)
                            vpnPassword = ""
                        } label: {
                            if vpnManager.isWorking {
                                HStack {
                                    ProgressView()
                                    Text("Saving VPN settings…")
                                }
                            } else {
                                Label("Connect to my VPN", systemImage: "lock.shield")
                            }
                        }
                        .disabled(!vpnManager.isReady || vpnManager.isWorking)
                    }
                } header: {
                    Text("Personal VPN · IKEv2")
                } footer: {
                    Text("Use a compatible VPN server and credentials you already have. iOS may ask you to approve the VPN configuration. Focus Plus does not provide a VPN server; connection status reflects the actual iOS tunnel. Setup also requires the Personal VPN entitlement and matching signing.")
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
                    Text("Erasing browsing data also clears the pop-up count and site exceptions.")
                }

                if flags.isEnabled(.browserLogs) {
                    BrowserLogSettingsSection()
                }

                Section("About") {
                    LabeledRow("Version", "1.0")
                    Text("Focus Plus blocks known trackers with WebKit content rules, keeps the data store ephemeral, browses in tabs with a dedicated iPad layout, and runs Chrome-style extensions through a lightweight WebExtensions bridge.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Developers note") {
                    Text("I like to code stuff because I feel little interest fot stock ios for it's a little flat and unpleasent I just see everyone making cool stuff for it codding cool PoCs and just wipping the floor with the sandbox it just makes me think woa I want to do that once I get skilled enough to apple better watch out")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
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
            .alert("Add a favorite", isPresented: $showAddFavorite) {
                TextField("Name", text: $newFavoriteTitle)
                TextField("Address, e.g. example.com", text: $newFavoriteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Button("Add") {
                    favorites.add(title: newFavoriteTitle, url: newFavoriteURL)
                    newFavoriteTitle = ""
                    newFavoriteURL = ""
                }
                Button("Cancel", role: .cancel) {
                    newFavoriteTitle = ""
                    newFavoriteURL = ""
                }
            } message: {
                Text("The site appears in the start page's favorites grid.")
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                CustomizationStore.shared.keepCookies
                    ? "Clear cookies and sign-ins too?"
                    : "Erase browsing data?",
                isPresented: $showEraseConfirmation,
                titleVisibility: .visible
            ) {
                if CustomizationStore.shared.keepCookies {
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
                        CustomizationStore.shared.keepCookies = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(CustomizationStore.shared.keepCookies
                     ? "Cookies and website sign-ins are set to stay on this device. Keep them, or wipe them along with the history."
                     : "Cookies and sign-ins die with every session. You can start keeping them instead.")
            }
        }
    }

    /// One of the palette cards in Appearance: a swatch of the look, its name
    /// and a check when it is the one in use.
    private func themeCard(_ preset: ThemePreset) -> some View {
        let selected = customization.themePreset == preset
        return Button {
            withAnimation(Theme.animation) { customization.themePreset = preset }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [preset.backdropTop, preset.backdropBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    HStack(spacing: 6) {
                        Image(systemName: preset.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(8)
                }
                .frame(width: 96, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Theme.accent : Color.white.opacity(0.08),
                                      lineWidth: selected ? 2 : 1)
                )
                Text(preset.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(selected ? Theme.accent : .secondary)
            }
        }
        .buttonStyle(.plain)
    }

    /// Switches between the bundled icons. iOS itself asks the user to confirm
/// the change, so the completion only refreshes which tile is marked active.
    private func iconButton(title: String, symbol: String, name: String?) -> some View {
        Button {
            guard UIApplication.shared.supportsAlternateIcons else { return }
            UIApplication.shared.setAlternateIconName(name) { _ in
                activeIcon = UIApplication.shared.alternateIconName
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(activeIcon == name ? Theme.accent : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                activeIcon == name ? Theme.accent.opacity(0.6) : Color.white.opacity(0.08),
                                lineWidth: activeIcon == name ? 2 : 1
                            )
                    )
                Text(title)
                    .font(.subheadline)
            }
        }
        .buttonStyle(.plain)
    }

    private func extensionRow(_ ext: BrowserExtension) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ext.name).font(.headline)
                    Text("v\(ext.version) · \(ext.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { extManager.isEnabled(ext.id) },
                    set: { enabled in
                        extManager.setEnabled(ext.id, enabled)
                        manager.refreshAllExtensions()
                    }
                ))
                .labelsHidden()
            }
            if !ext.descriptionText.isEmpty {
                Text(ext.descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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

private struct LabeledRow: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
