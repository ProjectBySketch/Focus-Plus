//
//  FlagsStore.swift
//  Focus Plus
//

import Combine
import Foundation

/// How finished a flag is. Stable flags ship on, beta and experimental ones
/// can still change shape or disappear between builds.
enum FlagStage: String, Comparable {
    case stable = "Stable"
    case beta = "Beta"
    case experimental = "Experimental"

    private var rank: Int {
        switch self {
        case .stable: return 0
        case .beta: return 1
        case .experimental: return 2
        }
    }

    static func < (lhs: FlagStage, rhs: FlagStage) -> Bool { lhs.rank < rhs.rank }
}

/// The sections the Flags page groups its switches under.
enum FlagGroup: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case browsing = "Browsing"
    case privacy = "Privacy & Network"
    case advanced = "Advanced"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .appearance: return "paintpalette"
        case .browsing: return "safari"
        case .privacy: return "hand.raised"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

/// One switch on the Flags page. The raw value is both the key it is saved
/// under and the name a page — or the user — can refer to it by.
enum BrowserFlag: String, CaseIterable, Identifiable {
    case floatingChrome = "ui.floatingChrome"
    case richStartPage = "ui.richStartPage"
    case tabPreviews = "ui.tabPreviews"
    case shieldCounter = "ui.shieldCounter"
    case springAnimations = "ui.springAnimations"

    case historyRecord = "history.record"
    case historySearch = "history.search"
    case restoreTabs = "browsing.restoreTabs"

    case incognitoCover = "privacy.incognitoCover"

    case browserLogs = "advanced.browserLogs"
    case internalPages = "advanced.internalPages"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .floatingChrome: return "Floating command bar"
        case .richStartPage: return "Rich start page"
        case .tabPreviews: return "Live tab thumbnails"
        case .shieldCounter: return "Tracker counter in the address bar"
        case .springAnimations: return "Spring animations"
        case .historyRecord: return "Record browsing history"
        case .historySearch: return "Search on the History page"
        case .restoreTabs: return "Restore tabs at launch"
        case .incognitoCover: return "Hide incognito pages in the app switcher"
        case .browserLogs: return "Show browser logs in Settings"
        case .internalPages: return "Focus internal pages"
        }
    }

    var summary: String {
        switch self {
        case .floatingChrome:
            return "Docks the address bar to the bottom as a floating glass panel instead of a full-width bar."
        case .richStartPage:
            return "Shows shortcuts, recent visits and the privacy card on the start page. Off leaves just the mark and the search field."
        case .tabPreviews:
            return "Draws a thumbnail of each open tab in the tab switcher. Off falls back to a coloured monogram, which uses less memory."
        case .shieldCounter:
            return "Turns the shield into a live counter of the tracking resources a page attempted to load."
        case .springAnimations:
            return "Switches the interface's transitions from a plain ease to a spring. Off is calmer and slightly cheaper."
        case .historyRecord:
            return "Saves every finished page to the History page. Incognito sessions are never recorded, whatever this says."
        case .historySearch:
            return "Adds a search field to the History page that matches titles and addresses."
        case .restoreTabs:
            return "Reopens the tabs of the last session at launch. The list is sealed with the app's Keychain key."
        case .incognitoCover:
            return "Covers the page with a privacy screen whenever the app leaves the foreground in incognito."
        case .browserLogs:
            return "Shows the in-memory browser log section at the bottom of Settings."
        case .internalPages:
            return "Lets the address bar open focus://flags and focus://history instead of searching for them."
        }
    }

    var group: FlagGroup {
        switch self {
        case .floatingChrome, .richStartPage, .tabPreviews, .shieldCounter, .springAnimations:
            return .appearance
        case .historyRecord, .historySearch, .restoreTabs:
            return .browsing
        case .incognitoCover:
            return .privacy
        case .browserLogs, .internalPages:
            return .advanced
        }
    }

    var stage: FlagStage {
        switch self {
        case .historySearch, .internalPages:
            return .beta
        case .springAnimations:
            return .experimental
        default:
            return .stable
        }
    }

    var defaultValue: Bool { true }
}

/// The user's switches from the Flags page, saved per flag in UserDefaults.
/// Anything unset reads as the flag's own default, so new flags arrive with
/// the value the build intends rather than off.
final class FlagsStore: ObservableObject {
    static let shared = FlagsStore()

    @Published private(set) var enabled: Set<BrowserFlag>

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var on: Set<BrowserFlag> = []
        for flag in BrowserFlag.allCases {
            let stored = defaults.object(forKey: Self.key(for: flag)) as? Bool
            if stored ?? flag.defaultValue { on.insert(flag) }
        }
        enabled = on
    }

    func isEnabled(_ flag: BrowserFlag) -> Bool { enabled.contains(flag) }

    func set(_ flag: BrowserFlag, enabled value: Bool) {
        if value {
            enabled.insert(flag)
        } else {
            enabled.remove(flag)
        }
        defaults.set(value, forKey: Self.key(for: flag))
    }

    func toggle(_ flag: BrowserFlag) { set(flag, enabled: !isEnabled(flag)) }

    /// Puts every switch back to what the build ships with.
    func reset() {
        for flag in BrowserFlag.allCases {
            defaults.removeObject(forKey: Self.key(for: flag))
        }
        enabled = Set(BrowserFlag.allCases.filter { $0.defaultValue })
    }

    /// Turns on everything that is not stable yet — the one-tap way to try
    /// the whole experimental surface.
    func enableAllExperimental() {
        for flag in BrowserFlag.allCases where flag.stage != .stable {
            set(flag, enabled: true)
        }
    }

    /// How many switches the user has moved away from their default.
    var changedCount: Int {
        BrowserFlag.allCases.reduce(into: 0) { total, flag in
            let stored = defaults.object(forKey: Self.key(for: flag)) as? Bool
            if let stored, stored != flag.defaultValue { total += 1 }
        }
    }

    private static func key(for flag: BrowserFlag) -> String { "flags." + flag.rawValue }
}
