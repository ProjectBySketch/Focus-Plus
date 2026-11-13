//
//  SettingsPages.swift
//  Focus Plus
//

import NetworkExtension
import SwiftUI

// MARK: - Shared rows

/// One navigable row on the Settings index: a tinted glyph, a title and one
/// line saying what lives behind it.
struct SettingRow: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil
    var tint: Color? = nil

    private var color: Color { tint ?? Theme.accent }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsView: View {
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var flags = FlagsStore.shared

    private let lookColumns = [GridItem(.adaptive(minimum: 132), spacing: 12)]
    private let accentColumns = [GridItem(.adaptive(minimum: 50), spacing: 12)]

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: lookColumns, spacing: 12) {
                    ForEach(ThemePreset.allCases) { preset in
                        lookCard(preset)
                    }
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            } header: {
                Text("Looks")
            } footer: {
                Text("Each look paints the chrome, the start page and the tab switcher; the pages themselves stay the site's own. Christmas is one of them: it adds the pine-green night, the falling snow and the holiday greeting, and picking any other switches it off.")
            }

            Section {
                LazyVGrid(columns: accentColumns, spacing: 12) {
                    ForEach(Accent.allCases) { choice in
                        accentSwatch(choice)
                    }
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            } header: {
                Text("Accent")
            } footer: {
                Text("Purple is the app's own colour. The accent paints the mark, the controls and the highlights on top of whichever look you pick.")
            }

            Section {
                Toggle("Accent glow", isOn: $customization.showBackdropGlow)
                Toggle("Spring animations", isOn: Binding(
                    get: { flags.isEnabled(.springAnimations) },
                    set: { flags.set(.springAnimations, enabled: $0) }
                ))
                Toggle("Minimalistic mode", isOn: $customization.minimalisticMode)
            } header: {
                Text("Interface")
            } footer: {
                Text("The glow is the blurred colour wash behind the start page and the tab switcher; turning it off leaves the plain gradient. Spring animations give every transition its bounce; off is calmer. Minimalistic mode hides the start-page shortcuts and the incognito and erase buttons from the bar — both stay available in Settings.")
            }

            Section {
                LabeledRow("Look", customization.themePreset.displayName)
                LabeledRow("Accent", customization.accent.displayName)
            } header: {
                Text("In use now")
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func lookCard(_ preset: ThemePreset) -> some View {
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
                .frame(height: 62)
                .frame(maxWidth: .infinity)
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

    private func accentSwatch(_ choice: Accent) -> some View {
        let selected = customization.accent == choice
        return Button {
            withAnimation(Theme.animation) { customization.accent = choice }
        } label: {
            ZStack {
                Circle()
                    .fill(choice.color)
                    .frame(width: 34, height: 34)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black.opacity(0.65))
                }
            }
            .overlay(Circle().strokeBorder(Color.white.opacity(selected ? 0.5 : 0.0), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.displayName)
    }
}

// MARK: - Start page

struct StartPageSettingsView: View {
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared
    @State private var showAddFavorite = false
    @State private var newTitle = ""
    @State private var newURL = ""

    var body: some View {
        Form {
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
                Text("Blocks")
            } footer: {
                Text("Which blocks the start page draws: the greeting and live clock, the favorites grid, the other open tabs, the pages you read last, shortcuts to History, Flags and Settings, and the session read-out. Turn any of them off for a quieter page.")
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
        }
        .navigationTitle("Start page")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add a favorite", isPresented: $showAddFavorite) {
            TextField("Name", text: $newTitle)
            TextField("Address, e.g. example.com", text: $newURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("Add") {
                favorites.add(title: newTitle, url: newURL)
                newTitle = ""
                newURL = ""
            }
            Button("Cancel", role: .cancel) {
                newTitle = ""
                newURL = ""
            }
        } message: {
            Text("The site appears in the start page's favorites grid.")
        }
    }
}

// MARK: - Command bar

struct CommandBarSettingsView: View {
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var flags = FlagsStore.shared

    var body: some View {
        Form {
            Section {
                Picker("Position", selection: $customization.chromePosition) {
                    ForEach(ChromePosition.allCases) { position in
                        Label(position.displayName, systemImage: position.symbol).tag(position)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Auto-hide while scrolled", isOn: $customization.autoHideChrome)
            } header: {
                Text("Placement")
            } footer: {
                Text("The bar stays wherever you put it — no dragging it around. With auto-hide on it tucks itself away while you scroll down and returns as soon as you scroll up or tap the address field. It always steps aside for the keyboard, so the space bar is never covered.")
            }

            Section {
                Toggle("Floating glass panel", isOn: Binding(
                    get: { flags.isEnabled(.floatingChrome) },
                    set: { flags.set(.floatingChrome, enabled: $0) }
                ))
                Toggle("Loading bar", isOn: $customization.showProgressBar)
                Toggle("Tracker counter in the address bar", isOn: Binding(
                    get: { flags.isEnabled(.shieldCounter) },
                    set: { flags.set(.shieldCounter, enabled: $0) }
                ))
            } header: {
                Text("Bar contents")
            } footer: {
                Text("Floating puts the bar in a rounded glass panel instead of a full-width strip. The loading bar is the thin accent line above the page. The tracker counter turns the shield into a live count of what a page tried to load.")
            }

            Section {
                LabeledRow("Position", customization.chromePosition.displayName)
                LabeledRow("Auto-hide", customization.autoHideChrome ? "On" : "Off")
                LabeledRow("Loading bar", customization.showProgressBar ? "On" : "Off")
            } header: {
                Text("In use now")
            }
        }
        .navigationTitle("Command bar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Search

struct SearchSettingsView: View {
    @ObservedObject private var customization = CustomizationStore.shared

    var body: some View {
        Form {
            Section {
                Picker("Engine", selection: $customization.searchEngine) {
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
            } header: {
                Text("Search")
            } footer: {
                Text("Focus Search is Focus Plus's own engine and the default: it renders a clean results page with Web and Images tabs right in the tab. A custom template is an http(s) URL containing %s where the search term goes. Verification only matters for Focus Search and uses the encrypted resolver you pick in Privacy.")
            }

            Section {
                Toggle("Open homepage in new tabs", isOn: $customization.homepageEnabled)
                if customization.homepageEnabled {
                    TextField("Homepage address", text: $customization.homepageText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
            } header: {
                Text("New tabs")
            } footer: {
                Text("Off opens the start page in every new tab, which is what most people want. An address typed without a scheme gets https.")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
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
                Text("Pages")
            } footer: {
                Text("Applies to every open tab straight away, and to every page loaded afterwards.")
            }
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy

struct PrivacySettingsView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var dnsManager = EncryptedDNSManager.shared

    var body: some View {
        Form {
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
            } header: {
                Text("Browsing")
            } footer: {
                Text("Incognito tints the interface and hides page content in the app switcher; switching modes wipes the session. With Keep cookies and sign-ins on, browsing outside incognito is saved on this device and logins survive relaunches. Incognito never saves anything.")
            }

            if let host = manager.activeTab?.model.displayedURL?.host {
                Section {
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
                } footer: {
                    Text("Pop-ups from script-opened windows are blocked by default, while tapped links stay in the current tab.")
                }
            }

            if !manager.allowedPopupSites.isEmpty {
                Section {
                    ForEach(manager.allowedPopupSites.sorted(), id: \.self) { site in
                        HStack {
                            Label(site, systemImage: "globe").lineLimit(1)
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
                    Text("Held in memory only; cleared when browsing data is erased or incognito mode changes.")
                }
            }

            Section {
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
            } header: {
                Text("DNS")
            } footer: {
                Text("Routes every lookup on this device over DNS-over-HTTPS, so the local network cannot see which sites you visit. The resolver itself can, which is why an open one is the better choice. It is not a VPN.")
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Extensions

struct ExtensionsSettingsView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var extManager = ExtensionManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(extManager.extensions) { ext in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ext.name).font(.subheadline.weight(.semibold))
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
                Button {
                    extManager.reload()
                    manager.refreshAllExtensions()
                } label: {
                    Label("Rescan extensions folder", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Installed")
            } footer: {
                Text("Add your own: put a folder in Files → Focus Plus → Extensions holding a Chrome manifest.json (MV2 or MV3) with content scripts or a background script written in JavaScript or Lua — .lua files run on an embedded Lua VM and get the global focus table — then rescan. Toggles apply to the next page load.")
            }
        }
        .navigationTitle("Extensions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Network

struct NetworkSettingsView: View {
    @ObservedObject private var vpnManager = PersonalVPNManager.shared
    @State private var vpnPassword = ""

    private var fieldsLocked: Bool {
        switch vpnManager.connectionStatus {
        case .connecting, .connected, .reasserting, .disconnecting: return true
        default: return false
        }
    }

    private var statusColor: Color {
        switch vpnManager.connectionStatus {
        case .connected: return Theme.accent
        case .connecting, .reasserting, .disconnecting: return .orange
        case .invalid: return .red
        default: return .secondary
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Connection")
                    Spacer()
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(vpnManager.statusDescription)
                        .foregroundStyle(statusColor)
                }
            } header: {
                Text("Status")
            }

            Section {
                TextField("VPN server host or IP", text: $vpnManager.serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(fieldsLocked)
                TextField("IKEv2 remote identifier", text: $vpnManager.remoteIdentifier)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(fieldsLocked)
                TextField("Username", text: $vpnManager.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(fieldsLocked)
                SecureField("VPN password (saved to Keychain)", text: $vpnPassword)
                    .disabled(fieldsLocked)
                if let error = vpnManager.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Server")
            } footer: {
                Text("Use a compatible IKEv2 server and credentials you already have. iOS may ask you to approve the VPN configuration. Focus Plus does not provide a VPN server; the status reflects the real iOS tunnel.")
            }

            Section {
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
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Saving VPN settings…")
                            }
                        } else {
                            Label("Connect to my VPN", systemImage: "lock.shield")
                        }
                    }
                    .disabled(!vpnManager.isReady || vpnManager.isWorking)
                }
            } footer: {
                Text("Requires the Personal VPN entitlement and matching signing.")
            }
        }
        .navigationTitle("Personal VPN")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AppLogo(style: .tile, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Focus Plus").font(.title3.bold())
                        Text("Version 1.0 (1)").font(.caption).foregroundStyle(.secondary)
                        Text("ProjectBySketch™").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section {
                Text("Focus Plus is a privacy-first browser: it blocks known trackers with WebKit content rules, keeps browsing in a saved store unless you are in incognito, browses in tabs with a dedicated iPad layout, and runs Chrome-style extensions through a lightweight WebExtensions bridge with an embedded Lua VM.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("What it is")
            }

            Section {
                LabeledRow("License", "MIT")
                LabeledRow("Forked from", "Focus Lite")
                LabeledRow("Front end", "WebKit")
                LabeledRow("Extensions", "Chrome + Lua")
            } header: {
                Text("Details")
            } footer: {
                Text("MIT — see LICENSE. Focus Lite's notice is kept in THIRD-PARTY-NOTICES.md, and the Lua engine (fengari) keeps its own license with the bundle.")
            }

            Section {
                HStack(spacing: 4) {
                    Spacer()
                    Text("made with").font(.footnote).foregroundStyle(.secondary)
                    Image(systemName: "heart.fill").font(.caption2).foregroundStyle(Color.pink)
                    Text("by ProjectBySketch™").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Small shared rows

struct LabeledRow: View {
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
