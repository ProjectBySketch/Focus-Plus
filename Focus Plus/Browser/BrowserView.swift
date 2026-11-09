//
//  BrowserView.swift
//  Focus Plus
//

import SwiftUI
import WebKit
import UIKit

enum Theme {
    /// The accent follows the user's choice in Settings; views re-render
    /// because TabManager forwards the customization store's changes.
    static var accent: Color { CustomizationStore.shared.accentColor }
    static let deepIndigo = Color(red: 0.09, green: 0.09, blue: 0.24)
    static let incognito = Color(red: 0.66, green: 0.5, blue: 0.95)
    static let incognitoDeep = Color(red: 0.04, green: 0.02, blue: 0.10)
    static let christmasRed = Color(red: 0.85, green: 0.16, blue: 0.19)
    static let pineNight = Color(red: 0.04, green: 0.16, blue: 0.11)
    /// The raised surface every control sits on.
    static let surface = Color.white.opacity(0.07)
    static let hairline = Color.white.opacity(0.10)
    /// The look chosen in Settings → Appearance.
    static var preset: ThemePreset { CustomizationStore.shared.themePreset }
    /// The app's night color: the bottom of the chosen preset's wash.
    static var baseBackground: Color { preset.backdropBottom }
    /// The full wash behind the start page, the tab switcher and the chrome.
    static var backdropGradient: LinearGradient {
        LinearGradient(
            colors: [preset.backdropTop, preset.backdropBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    /// The interface's motion: springy when the flag is on, a plain ease
    /// otherwise, so motion can be calmed without touching every view.
    static var animation: Animation {
        FlagsStore.shared.isEnabled(.springAnimations)
            ? .spring(response: 0.38, dampingFraction: 0.82)
            : .easeInOut(duration: 0.22)
    }
}

/// The sheets the browser can present. History and Flags are pages inside the
/// tab, not sheets, so Settings is the only one left.
enum BrowserSheet: String, Identifiable {
    case settings

    var id: String { rawValue }
}

struct BrowserView: View {
    @StateObject private var manager = TabManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var flags = FlagsStore.shared

    /// Settings is the only sheet; the browser's own pages are drawn inside
    /// the tab, so nothing here can fight over the sheet slot.
    private var sheetBinding: Binding<BrowserSheet?> {
        Binding(
            get: { manager.showSettings ? .settings : nil },
            set: { value in
                guard value == nil else { return }
                manager.showSettings = false
            }
        )
    }

    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                IPadBrowserLayout(manager: manager)
            } else {
                PhoneBrowserLayout(manager: manager)
            }
        }
        .background(
            (manager.isIncognito ? Theme.incognitoDeep : Theme.baseBackground)
                .ignoresSafeArea()
        )
        .overlay {
            if flags.isEnabled(.incognitoCover) && manager.isIncognito && scenePhase != .active {
                IncognitoPrivacyScreen()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.isIncognito)
        .sheet(item: sheetBinding) { sheet in
            switch sheet {
            case .settings:
                SettingsSheet(manager: manager)
            }
        }
        .confirmationDialog(
            CustomizationStore.shared.keepCookies
                ? "Clear cookies and sign-ins too?"
                : "Erase browsing data?",
            isPresented: $manager.showEraseConfirmation,
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass == .regular {
                    manager.captureTabPreviews()
                }
            } else {
                manager.clearTabPreviews()
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Tab content

/// Every tab's web view stays mounted so pages keep their state across tab
/// switches; only the active tab is visible and interactive.
struct TabContentView: View {
    @ObservedObject var manager: TabManager

    var body: some View {
        ZStack {
            ForEach(manager.tabs) { tab in
                WebViewContainer(webView: tab.model.webView)
                    // Bottom edge runs under the home indicator, but the top
                    // stays below the status bar / Dynamic Island.
                    .ignoresSafeArea(edges: [.bottom])
                    .opacity(tab.id == manager.activeTabID ? 1 : 0)
                    .allowsHitTesting(tab.id == manager.activeTabID)
            }
            if let active = manager.activeTab {
                if let page = active.model.internalPage {
                    InternalPageHost(manager: manager, page: page)
                        .transition(.opacity)
                }
                StartOverlay(manager: manager, model: active.model, incognito: manager.isIncognito)
            }
        }
        .animation(Theme.animation, value: manager.activeTabID)
    }
}

/// Draws one of the browser's own pages — History or Flags — inside the tab,
/// with the web view still mounted behind it.
private struct InternalPageHost: View {
    @ObservedObject var manager: TabManager
    let page: InternalPage

    var body: some View {
        ZStack {
            Theme.backdropGradient.ignoresSafeArea()
            switch page {
            case .history:
                HistoryView(manager: manager)
            case .flags:
                FlagsView(manager: manager)
            case .start:
                EmptyView()
            }
        }
    }
}

private struct StartOverlay: View {
    @ObservedObject var manager: TabManager
    @ObservedObject var model: BrowserModel
    let incognito: Bool

    var body: some View {
        if model.isStart {
            ZStack {
                (incognito ? Theme.incognitoDeep : Theme.baseBackground)
                    .ignoresSafeArea()
                StartPageView(manager: manager, model: model, incognito: incognito)
                if CustomizationStore.shared.christmasMode && !incognito {
                    Snowfall()
                        .ignoresSafeArea()
                }
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Shared chrome pieces

struct ProgressBar: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if model.isLoading {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(12, geo.size.width * model.progress))
                        .shadow(color: Theme.accent.opacity(0.7), radius: 6)
                }
            }
        }
        .frame(height: 3)
        .animation(.linear(duration: 0.15), value: model.progress)
    }
}

struct TrackerTip: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        Text(model.trackersSeen > 0
             ? "\(model.trackersSeen) tracking resource\(model.trackersSeen == 1 ? "" : "s") seen on this page — known trackers are blocked by the engine."
             : "No trackers seen on this page. Known trackers are blocked by the engine.")
            .font(.caption)
            .multilineTextAlignment(.center)
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .frame(maxWidth: 320)
    }
}

struct IncognitoPill: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "eyeglasses")
            Text("Incognito")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.incognito)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Theme.incognito.opacity(0.15), in: Capsule())
    }
}

/// The address capsule: the shield, the address itself, and the reload or
/// stop control. The shield doubles as the tracker counter when the flag for
/// it is on.
struct AddressField: View {
    @ObservedObject var model: BrowserModel
    @Binding var showTrackerTip: Bool
    var addressFocused: FocusState<Bool>.Binding
    @ObservedObject private var flags = FlagsStore.shared

    var body: some View {
        HStack(spacing: 8) {
            shield

            TextField("Search or enter address", text: $model.addressText)
                .textFieldStyle(.plain)
                .submitLabel(.go)
                .focused(addressFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .onSubmit {
                    model.load(model.addressText)
                    addressFocused.wrappedValue = false
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { addressFocused.wrappedValue = false }
                    }
                }

            if addressFocused.wrappedValue && !model.addressText.isEmpty {
                Button {
                    model.addressText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }

    private var shield: some View {
        Button {
            withAnimation(Theme.animation) { showTrackerTip.toggle() }
        } label: {
            ZStack {
                if flags.isEnabled(.shieldCounter) && model.trackersSeen > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(model.trackersSeen)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7)
                    .frame(height: 22)
                    .background(Theme.accent.opacity(0.18), in: Capsule())
                } else {
                    Image(systemName: model.isStart ? "magnifyingglass" : "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
            }
            .frame(height: 22)
        }
        .buttonStyle(.plain)
    }
}

/// A single icon in the command bar, with an optional count badge.
private struct ChromeIcon: View {
    let symbol: String
    var badge: Int? = nil
    var tint: Color? = nil
    var dimmed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint ?? .white)
                .frame(width: 40, height: 34)
                .opacity(dimmed ? 0.35 : 1)
            if let badge, badge > 1 {
                Text("\(badge)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.deepIndigo)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Theme.accent, in: Capsule())
                    .offset(x: 2, y: -1)
            }
        }
    }
}

// MARK: - Phone layout

struct PhoneBrowserLayout: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var flags = FlagsStore.shared
    @ObservedObject private var customization = CustomizationStore.shared
    @FocusState private var addressFocused: Bool
    @State private var showTrackerTip = false

    private var floating: Bool { flags.isEnabled(.floatingChrome) }
    private var top: Bool { customization.chromePosition == .top }

    /// Tucks the bar away while the page is scrolled down, and brings it back
    /// the moment you scroll up or tap the address field. It never hides while
    /// the keyboard is up, so nothing sits on the space bar.
    private var tucked: Bool {
        guard customization.autoHideChrome, !addressFocused else { return false }
        return (manager.activeTab?.model.scrollOffset ?? 0) > 60
    }

    var body: some View {
        ZStack {
            TabContentView(manager: manager)

            VStack(spacing: 8) {
                if top {
                    if manager.isIncognito {
                        IncognitoPill()
                    }
                    chrome
                    Spacer(minLength: 0)
                } else {
                    if manager.isIncognito {
                        IncognitoPill()
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                    chrome
                }
            }
            .animation(Theme.animation, value: top)

            if manager.showTabSwitcher {
                TabSwitcher(manager: manager)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(Theme.animation, value: manager.showTabSwitcher)
        .animation(.snappy(duration: 0.28), value: tucked)
        .onChange(of: manager.showTabSwitcher) { _, isShowing in
            if !isShowing { manager.clearTabPreviews() }
        }
    }

    private var chrome: some View {
        VStack(spacing: 10) {
            if showTrackerTip, let model = manager.activeTab?.model {
                TrackerTip(model: model)
                    .padding(.horizontal, 24)
                    .onTapGesture { withAnimation(Theme.animation) { showTrackerTip = false } }
                    .transition(.opacity.combined(with: .move(edge: top ? .top : .bottom)))
            }
            if let toastText = manager.toastText {
                StatusToast(text: toastText, symbol: manager.toastSymbol,
                            actionTitle: manager.toastActionTitle) {
                    manager.allowPopupsForLastBlockedSite()
                }
                .transition(.move(edge: top ? .top : .bottom).combined(with: .opacity))
            }
            if let model = manager.activeTab?.model {
                PhoneChrome(manager: manager, model: model,
                            showTrackerTip: $showTrackerTip,
                            addressFocused: $addressFocused,
                            floating: floating,
                            top: top)
            }
        }
        .opacity(tucked ? 0 : 1)
        .offset(y: tucked ? (top ? -170 : 170) : 0)
        .allowsHitTesting(!tucked)
    }
}

private struct PhoneChrome: View {
    @ObservedObject var manager: TabManager
    @ObservedObject var model: BrowserModel
    @Binding var showTrackerTip: Bool
    var addressFocused: FocusState<Bool>.Binding
    let floating: Bool
    let top: Bool

    private var focused: Bool { addressFocused.wrappedValue }

    var body: some View {
        VStack(spacing: 8) {
            if !top {
                ProgressBar(model: model)
                    .padding(.horizontal, 4)
            }

            HStack(spacing: 8) {
                AddressField(model: model, showTrackerTip: $showTrackerTip,
                             addressFocused: addressFocused)
                if !model.isStart {
                    Button(action: model.toggleReload) {
                        ChromeIcon(symbol: model.isLoading ? "xmark" : "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }

            if focused {
                AddressSuggestionList(model: model, addressFocused: addressFocused)
                    .transition(.opacity.combined(with: .move(edge: top ? .bottom : .top)))
            }

            // While the keyboard is up the second row goes away entirely, so
            // the space bar and the rest of the keyboard are never covered.
            if !focused {
                actionRow
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .center)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, focused ? 7 : 10)
        .background {
            if floating {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Theme.hairline)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 18, y: top ? -8 : 8)
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(alignment: top ? .bottom : .top) {
                        Rectangle().fill(Theme.hairline).frame(height: 1)
                    }
            }
        }
        .padding(.horizontal, floating ? 12 : 0)
        .padding(.top, floating && top ? 4 : 0)
        .padding(.bottom, floating && !top ? 4 : 0)
        .foregroundStyle(.white)
        .animation(Theme.animation, value: focused)
    }

    private var actionRow: some View {
        HStack(spacing: 2) {
            Button(action: model.goBack) {
                ChromeIcon(symbol: "chevron.left", dimmed: !model.canGoBack)
            }
            .buttonStyle(.plain)
            .disabled(!model.canGoBack)

            Button {
                withAnimation(Theme.animation) { manager.openTabSwitcher() }
            } label: {
                ChromeIcon(symbol: "square.on.square", badge: manager.tabs.count)
            }
            .buttonStyle(.plain)

            Button {
                manager.enterHistory()
            } label: {
                ChromeIcon(symbol: "clock.arrow.circlepath")
            }
            .buttonStyle(.plain)

            Button {
                manager.enterFlags()
            } label: {
                ChromeIcon(symbol: "flag.checkered")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            menuButton
        }
        .padding(.horizontal, 4)
    }

    private var menuButton: some View {
        Menu {
            Button {
                withAnimation(Theme.animation) { _ = manager.addTab() }
            } label: {
                Label("New Tab", systemImage: "plus.square")
            }
            Button {
                manager.enterHistory()
            } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            Button {
                manager.enterFlags()
            } label: {
                Label("Flags", systemImage: "flag.checkered")
            }
            Divider()
            Button {
                withAnimation(Theme.animation) { manager.toggleIncognito() }
            } label: {
                Label(manager.isIncognito ? "Leave Incognito" : "Incognito Mode",
                      systemImage: "eyeglasses")
            }
            Button {
                manager.showSettings = true
            } label: {
                Label("Settings & Extensions", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button(role: .destructive) {
                manager.requestErase()
            } label: {
                Label("Erase Browsing Data", systemImage: "trash")
            }
        } label: {
            ChromeIcon(symbol: "ellipsis")
        }
    }
}

// MARK: - Tab switcher (iPhone)

private struct TabSwitcher: View {
    @ObservedObject var manager: TabManager

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        ZStack {
            (manager.isIncognito ? Theme.incognitoDeep : Theme.baseBackground)
                .ignoresSafeArea()
                .opacity(0.99)

            if CustomizationStore.shared.christmasMode && !manager.isIncognito {
                Snowfall()
                    .ignoresSafeArea()
            }

            VStack(alignment: .leading, spacing: 14) {
                header
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        newTabCard
                        ForEach(manager.tabs) { tab in
                            TabCard(manager: manager, model: tab.model, tabID: tab.id)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(16)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Tabs")
                    .font(.title3.bold())
                Text(manager.isIncognito
                     ? "Incognito · nothing saved"
                     : "\(manager.tabs.count) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                withAnimation(Theme.animation) { manager.closeAll() }
            } label: {
                Text("Close All")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red)
            }
            Button {
                manager.showTabSwitcher = false
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(Theme.surface, in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private var newTabCard: some View {
        Button {
            withAnimation(Theme.animation) {
                _ = manager.addTab()
                manager.showTabSwitcher = false
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("New Tab")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 168)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.75))
    }
}

private struct TabCard: View {
    @ObservedObject var manager: TabManager
    @ObservedObject var model: BrowserModel
    let tabID: Tab.ID
    @ObservedObject private var flags = FlagsStore.shared

    private var isActive: Bool { tabID == manager.activeTabID }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayedURL?.host ?? (model.isStart ? "Start Page" : "New Tab"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(model.isStart ? "Ready when you are"
                         : (model.displayedURL?.absoluteString ?? ""))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isActive ? 0.13 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isActive ? Theme.accent.opacity(0.7) : Theme.hairline,
                                  lineWidth: isActive ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture {
                withAnimation(Theme.animation) {
                    manager.select(tabID)
                    manager.showTabSwitcher = false
                }
            }

            Button {
                withAnimation(Theme.animation) { manager.close(tabID) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 22, height: 22)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
        .frame(height: 168)
    }

    @ViewBuilder
    private var preview: some View {
        if flags.isEnabled(.tabPreviews), let image = model.previewImage, !model.isStart {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.hairline)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                if model.isStart {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isActive ? Theme.accent : Color.secondary)
                } else {
                    Text(String((model.displayedURL?.host ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? Theme.accent : Color.secondary)
                }
            }
            .frame(height: 100)
        }
    }
}

// MARK: - Web view container

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Festive logo & snow

/// The in-app logo: the shield mark in full Christmas dress — a Santa hat,
/// snow-capped pine sprigs, holly berries and snowflakes, matching the icon.
struct FestiveLogo: View {
    private let pine = Color(red: 0.16, green: 0.45, blue: 0.28)

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 132, height: 132)

            PineSprig()
                .stroke(pine, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 54, height: 44)
                .rotationEffect(.degrees(-36))
                .offset(x: -46, y: 36)

            PineSprig()
                .stroke(pine, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 54, height: 44)
                .scaleEffect(x: -1)
                .rotationEffect(.degrees(-36))
                .offset(x: 46, y: 36)

            ForEach([-46.0, 46.0], id: \.self) { x in
                HStack(spacing: 3) {
                    Circle().fill(Theme.christmasRed).frame(width: 7, height: 7)
                    Circle().fill(Theme.christmasRed).frame(width: 7, height: 7)
                    Circle().fill(Theme.christmasRed).frame(width: 7, height: 7)
                }
                .offset(x: x, y: 52)
            }

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Theme.accent)
                .overlay(alignment: .top) {
                    SantaHat()
                        .rotationEffect(.degrees(8), anchor: .bottom)
                        .offset(x: 4, y: -24)
                }

            Image(systemName: "snowflake")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .offset(x: -56, y: -44)
            Image(systemName: "snowflake")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .offset(x: 60, y: -32)
        }
        .frame(height: 132)
    }
}

/// A pine sprig: a diagonal stem with needles, drawn as one stroked path.
struct PineSprig: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w, y: 0))
        let needlePairs = 6
        for step in 1...needlePairs {
            let t = CGFloat(step) / CGFloat(needlePairs + 1)
            let x = w * t, y = h * (1 - t)
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + 10, y: y - 5))
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 4, y: y - 11))
        }
        return path
    }
}

/// A small Santa hat drawn with shapes: red cap, white trim, pompom.
/// Everything is laid out in one 48×33 frame so the pieces can't drift apart.
struct SantaHat: View {
    var body: some View {
        ZStack {
            SantaHatCap()
                .fill(Theme.christmasRed)
                .frame(width: 48, height: 33)
            SantaHatTrim()
                .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 48, height: 33)
            Circle()
                .fill(.white)
                .frame(width: 11, height: 11)
                .offset(x: 18, y: -6)
        }
        .frame(width: 48, height: 33)
    }
}

/// The cap: a smooth dome whose tip droops over to the right at (42, 10).
/// All curves stay inside the 48×33 frame, so nothing is clipped or spiky.
struct SantaHatCap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 27))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 22, y: rect.minY),
            control: CGPoint(x: rect.minX + 8, y: rect.minY + 1)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 42, y: rect.minY + 10),
            control: CGPoint(x: rect.minX + 34, y: rect.minY + 1)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 36, y: rect.minY + 27),
            control: CGPoint(x: rect.minX + 42, y: rect.minY + 20)
        )
        path.closeSubpath()
        return path
    }
}

/// The trim: a white arc stroked across the cap's base, rising slightly in
/// the middle so it hugs the dome and covers the base line.
struct SantaHatTrim: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + 30))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + 37, y: rect.minY + 30),
            control: CGPoint(x: rect.minX + 19, y: rect.minY + 22)
        )
        return path
    }
}

/// Gentle falling snow for Christmas mode, redrawn every frame with Canvas.
struct Snowfall: View {
    private let flakeCount = 60

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<flakeCount {
                    let seed = Double(index)
                    let baseX = (seed * 0.6180339887).truncatingRemainder(dividingBy: 1)
                    let speed = 18 + (seed * 0.317).truncatingRemainder(dividingBy: 1) * 32
                    let drift = sin(t * 0.5 + seed) * 9
                    let travel = t * speed + seed * 173.0
                    let y = travel.truncatingRemainder(dividingBy: size.height + 60) - 30
                    let x = baseX * size.width + drift
                    let radius = 1.2 + (seed * 0.271).truncatingRemainder(dividingBy: 1) * 2.2
                    let opacity = 0.2 + (seed * 0.113).truncatingRemainder(dividingBy: 1) * 0.55
                    let frame = CGRect(x: x - radius, y: y - radius,
                                       width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: frame), with: .color(.white.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Status toast

struct StatusToast: View {
    let text: String
    var symbol = "checkmark.circle.fill"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
            Text(text)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
    }
}

// MARK: - Incognito privacy screen

/// Covers all content while the app is in the app switcher or backgrounded in
/// incognito mode, so page content never shows in task switcher snapshots.
private struct IncognitoPrivacyScreen: View {
    var body: some View {
        ZStack {
            Theme.incognitoDeep.ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 40, weight: .bold))
                Text("Incognito")
                    .font(.headline)
            }
            .foregroundStyle(Theme.incognito)
        }
    }
}
