//
//  InternalPage.swift
//  Focus Plus
//

import Foundation

/// Pages the browser draws for itself rather than loading from the web. The
/// address bar recognises them and the tab manager presents them, so nothing
/// ever navigates to a scheme WebKit cannot load.
enum InternalPage: String, CaseIterable, Identifiable {
    case flags
    case history
    case start

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flags: return "Flags"
        case .history: return "History"
        case .start: return "New Tab"
        }
    }

    var symbol: String {
        switch self {
        case .flags: return "flag.checkered"
        case .history: return "clock.arrow.circlepath"
        case .start: return "plus.square"
        }
    }

    /// The address to type to reach a page. Shown in Settings and on the
    /// Flags page so the scheme is discoverable.
    var address: String {
        switch self {
        case .flags: return "focus://flags"
        case .history: return "focus://history"
        case .start: return "focus://start"
        }
    }

    /// Recognises "focus://flags", "focus:flags" and "about:flags" — the forms
    /// a browser user is likely to try. Anything else is not an internal page,
    /// so a search for the word "flags" still searches.
    static func parse(_ text: String) -> InternalPage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let prefix = ["focus://", "focus:", "about:"].first(where: { trimmed.hasPrefix($0) }) else {
            return nil
        }
        var path = String(trimmed.dropFirst(prefix.count))
        while path.hasPrefix("/") { path.removeFirst() }
        while path.hasSuffix("/") { path.removeLast() }

        switch path {
        case "flags", "focus-flags", "experiments": return .flags
        case "history": return .history
        case "start", "home", "newtab", "new-tab": return .start
        default: return nil
        }
    }
}
