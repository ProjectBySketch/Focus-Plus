//
//  StartPageView.swift
//  Focus Plus
//

import SwiftUI

/// The page a new tab opens with. One mark, one search field with live
/// suggestions, a compact list of what was read last and the state of the
/// shield — no more than that, so the page stays quiet.
struct StartPageView: View {
    @ObservedObject var model: BrowserModel
    let incognito: Bool

    @ObservedObject private var flags = FlagsStore.shared
    @ObservedObject private var history = HistoryStore.shared
    @ObservedObject private var customization = CustomizationStore.shared
    @StateObject private var suggestions = SearchSuggestionsController()

    @FocusState private var searchFocused: Bool
    @State private var draft = ""

    private var rich: Bool { flags.isEnabled(.richStartPage) }
    private var minimal: Bool { customization.minimalisticMode }
    private var festive: Bool { customization.themePreset.isFestive && !incognito }
    private var recentEntries: [HistoryEntry] { Array(history.entries.prefix(4)) }

    var body: some View {
        ZStack {
            Theme.backdropGradient
                .ignoresSafeArea()

            if festive {
                Snowfall()
                    .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    mark
                    greeting
                    searchField
                    if rich && !minimal && !recentEntries.isEmpty {
                        recentSection
                    }
                    if !minimal {
                        privacyNote
                    }
                    footer
                }
                .padding(.horizontal, 22)
                .padding(.top, 36)
                .padding(.bottom, 170)
                .frame(maxWidth: 620, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .foregroundStyle(.white)
        .onChange(of: draft) { _, text in
            suggestions.update(for: text)
        }
    }

    // MARK: - Mark

    private var mark: some View {
        HStack(spacing: 9) {
            Image(systemName: festive ? "snowflake" : "shield.lefthalf.filled")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text("FOCUS PLUS")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.55))
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
        return festive ? "Merry Christmas" : "Where to?"
    }

    private var subtitle: String {
        if incognito {
            return "Nothing you open here is saved — pages, cookies and tabs go when you leave."
        }
        if festive {
            return "A quiet browser for the season. Trackers are refused before pages load."
        }
        return "Search the web or type an address. Known trackers are refused before pages load."
    }

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
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(searchFocused ? Theme.accent.opacity(0.5) : Color.white.opacity(0.08))
            )

            if searchFocused && !suggestions.items.isEmpty {
                suggestionList
                    .transition(.opacity.combined(with: .move(edge: .top)))
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

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RECENTLY VISITED")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text("\(history.visitCount) visits")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.3))
            }

            VStack(spacing: 0) {
                ForEach(Array(recentEntries.enumerated()), id: \.element.id) { index, entry in
                    Button {
                        model.load(entry.url)
                    } label: {
                        HStack(spacing: 11) {
                            ZStack {
                                Circle().fill(Theme.accent.opacity(0.16))
                                Text(String(entry.host.prefix(1)).uppercased())
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

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(spacing: 10) {
            Image(systemName: incognito ? "eyeglasses" : "checkmark.shield.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(incognito ? Theme.incognito : Theme.accent)
            Text(incognito
                 ? "Incognito: nothing is written to this device while you are here."
                 : "Tracker blocking is on. Ads, analytics and known scam hosts are refused before they load.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06))
        )
    }

    private var footer: some View {
        Text("Focus Plus · ProjectBySketch™")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.3))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}
