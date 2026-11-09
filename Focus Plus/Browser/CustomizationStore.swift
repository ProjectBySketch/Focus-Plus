//
//  CustomizationStore.swift
//  Focus Plus
//

import SwiftUI

/// The interface's dressed-up looks. Each preset is one calm wash behind the
/// chrome, the start page and the tab switcher; the accent stays the user's
/// own choice. Christmas is one preset among them, so the festive look is
/// never forced on anyone and every other look stays just as complete.
enum ThemePreset: String, CaseIterable, Identifiable {
    case midnight, evergreen, aurora, sand, mono, ocean

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return "Midnight"
        case .evergreen: return "Christmas"
        case .aurora: return "Aurora"
        case .sand: return "Sand"
        case .mono: return "Mono"
        case .ocean: return "Ocean"
        }
    }

    var summary: String {
        switch self {
        case .midnight: return "Deep indigo, quiet and neutral."
        case .evergreen: return "Pine green, falling snow, a holiday greeting."
        case .aurora: return "Indigo into teal, like a night sky."
        case .sand: return "Warm earth tones for daylight reading."
        case .mono: return "Graphite with no colour cast at all."
        case .ocean: return "Cold blue, deep and calm."
        }
    }

    var symbol: String {
        switch self {
        case .midnight: return "moon.stars.fill"
        case .evergreen: return "snowflake"
        case .aurora: return "sparkles"
        case .sand: return "sun.haze.fill"
        case .mono: return "circle.lefthalf.filled"
        case .ocean: return "water.waves"
        }
    }

    /// The two ends of the wash behind the chrome and the start page.
    var backdropTop: Color {
        switch self {
        case .midnight: return Color(red: 0.11, green: 0.11, blue: 0.27)
        case .evergreen: return Color(red: 0.05, green: 0.21, blue: 0.15)
        case .aurora: return Color(red: 0.10, green: 0.14, blue: 0.34)
        case .sand: return Color(red: 0.27, green: 0.22, blue: 0.17)
        case .mono: return Color(red: 0.15, green: 0.15, blue: 0.16)
        case .ocean: return Color(red: 0.04, green: 0.18, blue: 0.31)
        }
    }

    var backdropBottom: Color {
        switch self {
        case .midnight: return Color(red: 0.04, green: 0.04, blue: 0.10)
        case .evergreen: return Color(red: 0.02, green: 0.09, blue: 0.07)
        case .aurora: return Color(red: 0.03, green: 0.20, blue: 0.23)
        case .sand: return Color(red: 0.12, green: 0.09, blue: 0.07)
        case .mono: return Color(red: 0.05, green: 0.05, blue: 0.06)
        case .ocean: return Color(red: 0.01, green: 0.07, blue: 0.14)
        }
    }

    /// Only the Christmas preset draws the snow and the greeting.
    var isFestive: Bool { self == .evergreen }
}

/// The blocks the start page can show. Everything is on by default; turning
/// one off leaves a quieter page without taking the feature away.
enum StartPageSection: String, CaseIterable, Identifiable {
    case greeting, clock, favorites, continueBrowsing, recent, quickActions, stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .greeting: return "Greeting and tagline"
        case .clock: return "Live clock"
        case .favorites: return "Favorites grid"
        case .continueBrowsing: return "Continue browsing · open tabs"
        case .recent: return "Recently visited"
        case .quickActions: return "History, Flags and Settings shortcuts"
        case .stats: return "Session stats"
        }
    }

    var symbol: String {
        switch self {
        case .greeting: return "text.alignleft"
        case .clock: return "clock"
        case .favorites: return "square.grid.2x2.fill"
        case .continueBrowsing: return "rectangle.on.rectangle"
        case .recent: return "clock.arrow.circlepath"
        case .quickActions: return "bolt.fill"
        case .stats: return "chart.bar.fill"
        }
    }
}

/// Where the phone's command bar sits. A preset, not a drag: the bar stays
/// exactly where it was put.
enum ChromePosition: String, CaseIterable, Identifiable {
    case bottom, top

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottom: return "Bottom"
        case .top: return "Top"
        }
    }

    var symbol: String {
        switch self {
        case .bottom: return "arrow.down.to.line"
        case .top: return "arrow.up.to.line"
        }
    }
}

/// The accent colors the app ships with. The raw value is the string the
/// choice is persisted under.
enum Accent: String, CaseIterable, Identifiable {
    case purple, tangerine, coral, amber, mint, sky, violet, rose

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .purple: return Color(red: 0.61, green: 0.38, blue: 0.99)
        case .tangerine: return Color(red: 1.0, green: 0.545, blue: 0.235)
        case .coral: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .amber: return Color(red: 1.0, green: 0.78, blue: 0.25)
        case .mint: return Color(red: 0.34, green: 0.85, blue: 0.6)
        case .sky: return Color(red: 0.35, green: 0.65, blue: 1.0)
        case .violet: return Color(red: 0.66, green: 0.5, blue: 0.95)
        case .rose: return Color(red: 1.0, green: 0.45, blue: 0.7)
        }
    }

    var displayName: String { rawValue.capitalized }
}

/// The engines the address bar can send a plain search term to. The query is
/// passed through URLComponents, so it is encoded correctly for each engine.
enum SearchEngine: String, CaseIterable, Identifiable {
    case focus, duckduckgo, google, bing, brave, startpage, ecosia, qwant, custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focus: return "Focus Search · built-in"
        case .duckduckgo: return "DuckDuckGo"
        case .google: return "Google"
        case .bing: return "Bing"
        case .brave: return "Brave Search"
        case .startpage: return "Startpage"
        case .ecosia: return "Ecosia"
        case .qwant: return "Qwant"
        case .custom: return "Custom…"
        }
    }

    func searchURL(for query: String) -> URL? {
        var components: URLComponents?
        switch self {
        case .focus:
            return nil // Handled by BrowserModel, which renders the results page in the tab.
        case .duckduckgo:
            components = URLComponents(string: "https://duckduckgo.com/")
        case .google:
            components = URLComponents(string: "https://www.google.com/search")
        case .bing:
            components = URLComponents(string: "https://www.bing.com/search")
        case .brave:
            components = URLComponents(string: "https://search.brave.com/search")
        case .startpage:
            components = URLComponents(string: "https://www.startpage.com/sp/search")
        case .ecosia:
            components = URLComponents(string: "https://www.ecosia.org/search")
        case .qwant:
            components = URLComponents(string: "https://www.qwant.com/")
        case .custom:
            return nil // Handled by CustomizationStore, which owns the template.
        }
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}

/// The user's look-and-feel and search preferences. Only the choices
/// themselves are saved on device — nothing here describes browsing activity,
/// so the choices survive an erase like the pop-up blocker setting does.
final class CustomizationStore: ObservableObject {
    static let shared = CustomizationStore()

    @Published var accent: Accent {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }
    @Published var searchEngine: SearchEngine {
        didSet { defaults.set(searchEngine.rawValue, forKey: Keys.searchEngine) }
    }
    @Published var customSearchTemplate: String {
        didSet { defaults.set(customSearchTemplate, forKey: Keys.customSearchTemplate) }
    }
    @Published var homepageEnabled: Bool {
        didSet { defaults.set(homepageEnabled, forKey: Keys.homepageEnabled) }
    }
    @Published var homepageText: String {
        didSet { defaults.set(homepageText, forKey: Keys.homepageText) }
    }
    /// WebKit page zoom as a fraction of the default size (1.0 = 100%).
    @Published var pageZoom: Double {
        didSet { defaults.set(pageZoom, forKey: Keys.pageZoom) }
    }
    /// Strips the interface down: no start-page shortcuts or tagline, a
    /// single-row bar on iPhone, and the incognito/erase buttons move to
    /// Settings only.
    @Published var minimalisticMode: Bool {
        didSet { defaults.set(minimalisticMode, forKey: Keys.minimalisticMode) }
    }
    /// Whether website cookies and sign-ins are kept. On (the default),
    /// normal browsing uses the persistent store, so logins survive
    /// erases that spare them and relaunches; off, every session is
    /// ephemeral, like incognito.
    @Published var keepCookies: Bool {
        didSet { defaults.set(keepCookies, forKey: Keys.keepCookies) }
    }
    /// Where the phone's command bar lives. It no longer moves by dragging:
    /// pick top or bottom once and it stays there.
    @Published var chromePosition: ChromePosition {
        didSet { defaults.set(chromePosition.rawValue, forKey: Keys.chromePosition) }
    }
    /// Tucks the command bar away while a page is scrolled down, and brings it
    /// back the moment you scroll up or tap the address field.
    @Published var autoHideChrome: Bool {
        didSet { defaults.set(autoHideChrome, forKey: Keys.autoHideChrome) }
    }
    /// The interface's look. Christmas is the evergreen preset, so the festive
    /// theme and the rest are the same setting seen from two sides.
    @Published var themePreset: ThemePreset {
        didSet {
            defaults.set(themePreset.rawValue, forKey: Keys.themePreset)
            defaults.set(themePreset.isFestive, forKey: Keys.christmasMode)
        }
    }
    /// Kept for the views and flags that predate the preset list: reading it
    /// says whether the festive theme is on, writing it picks evergreen or
    /// falls back to midnight.
    var christmasMode: Bool {
        get { themePreset.isFestive }
        set { themePreset = newValue ? .evergreen : .midnight }
    }
    /// Focus Search's optional DNS check for typed domains. Off by default:
    /// plenty of small and open-source sites aren't registered with the big
    /// public resolvers, so verification is only for people who want it.
    @Published var verifyDomains: Bool {
        didSet { defaults.set(verifyDomains, forKey: Keys.verifyDomains) }
    }
    /// Which blocks the start page draws, so the page can be as full or as
    /// spare as the user wants.
    @Published var startPageSections: Set<StartPageSection> {
        didSet {
            defaults.set(startPageSections.map(\.rawValue), forKey: Keys.startPageSections)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Purple is the app's own colour. Anyone who never picked an accent —
        // or who still has the old default — is moved onto it once, so the
        // change shows up on an existing install rather than only a fresh one.
        let storedAccent = defaults.string(forKey: Keys.accent)
        if !defaults.bool(forKey: Keys.accentSeededPurple),
           storedAccent == nil || storedAccent == Accent.tangerine.rawValue {
            accent = .purple
            defaults.set(true, forKey: Keys.accentSeededPurple)
        } else {
            accent = Accent(rawValue: storedAccent ?? "") ?? .purple
        }
        searchEngine = SearchEngine(rawValue: defaults.string(forKey: Keys.searchEngine) ?? "") ?? .focus
        customSearchTemplate = defaults.string(forKey: Keys.customSearchTemplate) ?? "https://duckduckgo.com/?q=%s"
        homepageEnabled = defaults.bool(forKey: Keys.homepageEnabled)
        homepageText = defaults.string(forKey: Keys.homepageText) ?? ""
        pageZoom = defaults.object(forKey: Keys.pageZoom) as? Double ?? 1.0
        minimalisticMode = defaults.bool(forKey: Keys.minimalisticMode)
        keepCookies = defaults.object(forKey: Keys.keepCookies) as? Bool ?? true
        chromePosition = ChromePosition(rawValue: defaults.string(forKey: Keys.chromePosition) ?? "") ?? .bottom
        autoHideChrome = defaults.object(forKey: Keys.autoHideChrome) as? Bool ?? true
        themePreset = ThemePreset(rawValue: defaults.string(forKey: Keys.themePreset) ?? "")
            ?? ((defaults.object(forKey: Keys.christmasMode) as? Bool ?? true) ? .evergreen : .midnight)
        verifyDomains = defaults.bool(forKey: Keys.verifyDomains)
        let storedSections = defaults.stringArray(forKey: Keys.startPageSections)
        startPageSections = Set(
            (storedSections ?? StartPageSection.allCases.map(\.rawValue))
                .compactMap(StartPageSection.init(rawValue:))
        )

    }

    private enum Keys {
        static let accent = "customization.accent"
        static let searchEngine = "customization.searchEngine"
        static let customSearchTemplate = "customization.customSearchTemplate"
        static let homepageEnabled = "customization.homepageEnabled"
        static let homepageText = "customization.homepageText"
        static let pageZoom = "customization.pageZoom"
        static let minimalisticMode = "customization.minimalisticMode"
        static let keepCookies = "customization.keepCookies"
        static let chromePosition = "customization.chromePosition"
        static let autoHideChrome = "customization.autoHideChrome"
        static let accentSeededPurple = "customization.accentSeededPurple"
        static let christmasMode = "customization.christmasMode"
        static let themePreset = "customization.themePreset"
        static let verifyDomains = "customization.verifyDomains"
        static let startPageSections = "customization.startPageSections"

    }

    var accentColor: Color { accent.color }

    /// Where the address bar sends a plain search term. A custom template is
    /// an absolute http(s) URL containing %s where the encoded term goes.
    func searchURL(for query: String) -> URL? {
        switch searchEngine {
        case .custom:
            let template = customSearchTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard template.lowercased().hasPrefix("http"), template.contains("%s") else { return nil }
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query
            return URL(string: template.replacingOccurrences(of: "%s", with: encoded))
        default:
            return searchEngine.searchURL(for: query)
        }
    }

    /// The page a new tab opens with when homepage mode is on. Addresses
    /// typed without a scheme get https; an empty field means the start screen.
    func homepageURL() -> URL? {
        guard homepageEnabled else { return nil }
        let text = homepageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let scheme = URL(string: text)?.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return URL(string: text)
        }
        return URL(string: "https://" + text)
    }
}