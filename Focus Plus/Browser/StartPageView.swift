//
//  StartPageView.swift
//  Focus Plus
//

import Combine
import SwiftUI

/// The start page: the browser's front door. A decorated wash, a live clock,
/// the search field with suggestions, a favorites grid you can edit, the tabs
/// still open, what was read last, shortcuts to the app's own pages and a
/// session read-out. Every block can be switched off in Settings.
struct StartPageView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject var model: BrowserModel
    let incognito: Bool

    @ObservedObject private var history = HistoryStore.shared
    @ObservedObject private var customization = CustomizationStore.shared
    @ObservedObject private var favorites = FavoritesStore.shared
    @StateObject private var suggestions = SearchSuggestionsController()

    @FocusState private var searchFocused: Bool
    @State private var draft = ""
    @State private var showAddFavorite = false
    @State private var newFavoriteTitle = ""
    @State private var newFavoriteURL = ""
    @State private var clock = Date()

    private var sections: Set<StartPageSection> { customization.startPageSections }
    private var festive: Bool { customization.themePreset.isFestive && !incognito }
    private var recentEntries: [HistoryEntry] { Array(history.entries.prefix(4)) }
    private var otherTabs: [Tab] {
        manager.tabs.filter { $0.id != manager.activeTabID && !$0.model.isStart }
    }

    var body: some View {
        ZStack {
            backdrop
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    topBar
                    if sections.contains(.greeting) {
                        greeting
                    }
                    searchField
                    if sections.contains(.favorites) && !customization.minimalisticMode {
                        favoritesGrid
                    }
                    if sections.contains(.continueBrowsing) && !otherTabs.isEmpty {
                        continueBrowsing
                    }
                    if sections.contains(.quickActions) {
                        quickActions
                    }
                    if sections.contains(.recent) && !recentEntries.isEmpty {
                        recentSection
                    }
                    if sections.contains(.stats) {
                        statsRow
                    }
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 170)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(.white)
        .onChange(of: draft) { _, text in
            suggestions.update(for: text)
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now in
            clock = now
        }
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
            Text("The site appears in your favorites grid on this device.")
        }
    }
}


extension StartPageView {
    // MARK: - Backdrop

    private var backdrop: some View {
        ZStack {
            Theme.backdropGradient
            Circle()
                .fill(Theme.accent.opacity(0.22))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: -90, y: -210)
            Circle()
                .fill((festive ? Theme.christmasRed : Theme.accent).opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 130)
                .offset(x: 140, y: 250)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: festive ? "snowflake" : "shield.lefthalf.filled")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("FOCUS PLUS")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
            if sections.contains(.clock) {
                Text(clock.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }
            Button {
                manager.showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var title: String {
        if incognito { return "Private session" }
        if festive { return "Merry Christmas" }
        let hour = Calendar.current.component(.hour, from: clock)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var subtitle: String {
        if incognito {
            return "Nothing you open here is saved — pages, cookies and tabs go when you leave."
        }
        if festive {
            return "A quieter browser for the season. Trackers are refused before a page loads."
        }
        return "Search the web, or type an address. Trackers are refused before a page loads."
    }
}


extension StartPageView {
    // MARK: - Search

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                TextField("Search or enter address", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .onSubmit { run(draft) }

                if !draft.isEmpty {
                    Button {
                        draft = ""
                        suggestions.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(searchFocused ? Theme.accent.opacity(0.5) : Color.white.opacity(0.08))
            )

            if searchFocused && !suggestions.items.isEmpty {
                suggestionList
            }
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.items.enumerated()), id: \.element.id) { index, item in
                Button {
                    run(item.text)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.kind == .url ? "globe" : "magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .frame(width: 18)
                        Text(item.text)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer(minLength: 0)
                        Image(systemName: item.kind == .url ? "arrow.right" : "arrow.up.left")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < suggestions.items.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.leading, 42)
                }
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07))
        )
    }

    private func run(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchFocused = false
            return
        }
        model.load(trimmed)
        draft = ""
        suggestions.clear()
        searchFocused = false
    }
}


extension StartPageView {
    // MARK: - Favorites

    private var favoritesGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("FAVORITES", trailing: "Long-press to remove")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 12) {
                ForEach(favorites.sites) { site in
                    Button {
                        model.load(site.url)
                    } label: {
                        favoriteTile(site)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            favorites.remove(site.id)
                        } label: {
                            Label("Remove Favorite", systemImage: "trash")
                        }
                    }
                }

                Button {
                    showAddFavorite = true
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 46, height: 46)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            )
                        Text("Add")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func favoriteTile(_ site: FavoriteSite) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accent.opacity(0.16))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.22))
                Text(site.monogram)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
            .frame(height: 46)
            Text(site.title)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}


extension StartPageView {
    // MARK: - Continue browsing

    private var continueBrowsing: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("CONTINUE BROWSING", trailing: "\(otherTabs.count) other tab\(otherTabs.count == 1 ? "" : "s")")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(otherTabs) { tab in
                        Button {
                            manager.select(tab.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                    Text(tab.model.displayedURL?.host ?? "Tab")
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                }
                                Text(tab.model.pageTitle.isEmpty
                                     ? (tab.model.displayedURL?.absoluteString ?? "")
                                     : tab.model.pageTitle)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(2)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(12)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.07))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 10) {
            actionTile("History", symbol: "clock.arrow.circlepath") { manager.enterHistory() }
            actionTile("Flags", symbol: "flag.checkered") { manager.enterFlags() }
            actionTile(incognito ? "Leave" : "Private",
                       symbol: incognito ? "eyeglasses" : "eyeglasses") { manager.toggleIncognito() }
            actionTile("Settings", symbol: "slider.horizontal.3") { manager.showSettings = true }
        }
    }

    private func actionTile(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }
}


extension StartPageView {
    // MARK: - Recently visited

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("RECENTLY VISITED", trailing: "\(history.visitCount) visits")

            VStack(spacing: 0) {
                ForEach(Array(recentEntries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        model.load(entry.url)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                Circle().fill(Theme.accent.opacity(0.16))
                                Text(entry.monogram)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.accent)
                            }
                            .frame(width: 28, height: 28)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.displayTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(1)
                                Text(entry.host)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < recentEntries.count - 1 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)
                            .padding(.leading, 51)
                    }
                }
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07))
            )
        }
    }

    // MARK: - Stats and footer

    private var statsRow: some View {
        HStack(spacing: 10) {
            statPill("\(manager.pagesVisited)", "pages", symbol: "doc.text")
            statPill("\(history.visitCount)", "visits", symbol: "clock")
            statPill("\(manager.popupsBlocked)", "pop-ups", symbol: "hand.raised")
        }
    }

    private func statPill(_ value: String, _ label: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.07))
        )
    }

    private func sectionTitle(_ text: String, trailing: String? = nil) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var footer: some View {
        Text("Focus Plus · ProjectBySketch™")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}
