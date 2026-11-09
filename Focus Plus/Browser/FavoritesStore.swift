//
//  FavoritesStore.swift
//  Focus Plus
//

import Combine
import Foundation
import SwiftUI

/// One favourite on the start page: a name, an address and a symbol.
struct FavoriteSite: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var url: String
    var symbol: String

    var host: String {
        URL(string: url)?.host?.lowercased() ?? url
    }

    var monogram: String {
        String((title.isEmpty ? host : title).prefix(1)).uppercased()
    }
}

/// The favourites grid the start page shows. Kept on device in UserDefaults,
/// small enough to save whole on every edit. A few sensible sites are there
/// on first launch so the grid is never an empty void.
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var sites: [FavoriteSite] = []

    private let defaults: UserDefaults
    private static let key = "start.favorites.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([FavoriteSite].self, from: data) {
            sites = decoded
        } else {
            sites = Self.defaults
        }
    }

    func add(title: String, url: String) {
        let trimmedURL = normalize(url)
        guard !trimmedURL.isEmpty else { return }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let site = FavoriteSite(
            title: name.isEmpty ? (URL(string: trimmedURL)?.host ?? trimmedURL) : name,
            url: trimmedURL,
            symbol: "globe"
        )
        sites.append(site)
        save()
    }

    func remove(_ id: FavoriteSite.ID) {
        sites.removeAll { $0.id == id }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        sites.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func normalize(_ url: String) -> String {
        var text = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        if !text.lowercased().hasPrefix("http") {
            text = "https://" + text
        }
        return text
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sites) else { return }
        defaults.set(data, forKey: Self.key)
    }

    private static var defaults: [FavoriteSite] {
        [
            FavoriteSite(title: "Wikipedia", url: "https://en.wikipedia.org", symbol: "book.fill"),
            FavoriteSite(title: "Hacker News", url: "https://news.ycombinator.com", symbol: "newspaper.fill"),
            FavoriteSite(title: "GitHub", url: "https://github.com", symbol: "chevron.left.forwardslash.chevron.right"),
            FavoriteSite(title: "YouTube", url: "https://youtube.com", symbol: "play.rectangle.fill"),
            FavoriteSite(title: "Reddit", url: "https://reddit.com", symbol: "bubble.left.and.bubble.right.fill"),
            FavoriteSite(title: "DuckDuckGo", url: "https://duckduckgo.com", symbol: "magnifyingglass.circle.fill"),
            FavoriteSite(title: "Archive", url: "https://archive.org", symbol: "building.columns.fill"),
            FavoriteSite(title: "Mail", url: "https://mail.proton.me", symbol: "envelope.fill")
        ]
    }
}
