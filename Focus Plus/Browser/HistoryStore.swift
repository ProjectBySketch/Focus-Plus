//
//  HistoryStore.swift
//  Focus Plus
//

import Combine
import Foundation

/// One finished visit. Addresses are kept in full here — the History page is
/// the one place the browser is meant to remember where you have been.
struct HistoryEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var url: String
    var title: String
    var visitedAt: Date

    var host: String {
        URL(string: url)?.host?.lowercased() ?? url
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? host : trimmed
    }

    /// The letter shown in the row's coloured circle.
    var monogram: String {
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return String(bare.first ?? "?").uppercased()
    }
}

/// A day's worth of visits, newest day first.
struct HistorySection: Identifiable {
    let id: Date
    let title: String
    let entries: [HistoryEntry]
}

/// Every visit the browser has kept, newest first, written to a JSON file in
/// Application Support. Nothing in an incognito session ever reaches it.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let fileURL: URL
    private let saveQueue = DispatchQueue(label: "com.projectbysketch.focusplus.history", qos: .utility)

    init(fileURL: URL? = nil) {
        let resolved = fileURL ?? Self.defaultFileURL()
        self.fileURL = resolved
        self.entries = Self.load(from: resolved)
    }

    // MARK: - Recording

    /// Adds a finished page. Only web addresses count; the browser's own pages
    /// and HTML-string search results have no address to save. A repeat visit
    /// to the page already at the top moves its time forward instead of
    /// stacking a duplicate row.
    func record(url: URL, title: String) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        let entry = HistoryEntry(url: url.absoluteString, title: title, visitedAt: Date())
        if Thread.isMainThread {
            insert(entry)
        } else {
            DispatchQueue.main.async { [weak self] in self?.insert(entry) }
        }
    }

    private func insert(_ entry: HistoryEntry) {
        if let index = entries.firstIndex(where: { $0.url == entry.url }),
           entry.visitedAt.timeIntervalSince(entries[index].visitedAt) < 120 {
            entries[index].visitedAt = entry.visitedAt
            if !entry.title.isEmpty { entries[index].title = entry.title }
        } else {
            entries.insert(entry, at: 0)
        }
        scheduleSave()
    }

    // MARK: - Editing

    func remove(_ id: HistoryEntry.ID) {
        entries.removeAll { $0.id == id }
        scheduleSave()
    }

    /// Removes every visit made on one day, so today can be cleared without
    /// touching the rest of the history.
    func remove(on day: Date, calendar: Calendar = .current) {
        entries.removeAll { calendar.isDate($0.visitedAt, inSameDayAs: day) }
        scheduleSave()
    }

    /// Removes every visit to one host — a single site's trail, gone.
    func removeAll(from host: String) {
        let needle = host.lowercased()
        entries.removeAll { $0.host == needle }
        scheduleSave()
    }

    func eraseAll() {
        entries.removeAll(keepingCapacity: false)
        scheduleSave()
    }

    // MARK: - Reading

    var visitCount: Int { entries.count }

    var siteCount: Int { Set(entries.map(\.host)).count }

    func visits(on day: Date = Date(), calendar: Calendar = .current) -> Int {
        entries.filter { calendar.isDate($0.visitedAt, inSameDayAs: day) }.count
    }

    /// Visits grouped by day for the History page, filtered by a search term
    /// matched against the title and the address.
    func sections(matching query: String = "", calendar: Calendar = .current) -> [HistorySection] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [HistoryEntry]
        if needle.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter {
                $0.url.lowercased().contains(needle) || $0.title.lowercased().contains(needle)
            }
        }

        var buckets: [(day: Date, entries: [HistoryEntry])] = []
        for entry in filtered {
            let day = calendar.startOfDay(for: entry.visitedAt)
            if let last = buckets.last, last.day == day {
                buckets[buckets.count - 1].entries.append(entry)
            } else {
                buckets.append((day, [entry]))
            }
        }
        return buckets.map { bucket in
            HistorySection(
                id: bucket.day,
                title: Self.title(for: bucket.day, calendar: calendar),
                entries: bucket.entries
            )
        }
    }

    private static func title(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        return day.formatted(.dateTime.day().month(.wide).year())
    }

    // MARK: - Storage

    private func scheduleSave() {
        let snapshot = entries
        let destination = fileURL
        saveQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: destination, options: .atomic)
        }
    }

    private static func load(from url: URL) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return [] }
        return decoded
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("FocusPlus", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }
}
