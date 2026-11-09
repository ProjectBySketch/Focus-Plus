//
//  SearchSuggestions.swift
//  Focus Plus
//

import Combine
import Foundation
import SwiftUI

/// One row in a suggestion list: either a plain search term or an address the
/// text looks like it resolves to.
struct SearchSuggestion: Identifiable, Hashable {
    enum Kind {
        case query
        case url
    }

    let id = UUID()
    let text: String
    let kind: Kind
}

/// Live search suggestions for the start page and the address bar. Queries go
/// to DuckDuckGo's key-less autocomplete endpoint — the same service the Focus
/// engine already uses for results — with a short debounce so typing never
/// fires a request per keystroke. Nothing is stored: the client is ephemeral,
/// so suggestions die with the view.
@MainActor
final class SearchSuggestionsController: ObservableObject {
    @Published private(set) var items: [SearchSuggestion] = []

    private var task: Task<Void, Never>?
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    /// Called on every keystroke. Cancels the request in flight, waits out the
    /// debounce, then replaces the list with what came back.
    func update(for text: String) {
        task?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 120 else {
            if !items.isEmpty { items = [] }
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self else { return }
            let remote = await Self.fetch(trimmed, session: session)
            guard !Task.isCancelled else { return }
            let merged = Self.merge(local: trimmed, remote: remote)
            if merged.map(\.text) != items.map(\.text) {
                items = merged
            }
        }
    }

    func clear() {
        task?.cancel()
        if !items.isEmpty { items = [] }
    }

    /// The address the text looks like, first when it is domain-shaped, then
    /// the engine's own completions, de-duplicated and capped at eight.
    nonisolated static func merge(local: String, remote: [String]) -> [SearchSuggestion] {
        var results: [SearchSuggestion] = []
        var seen = Set<String>()
        if let site = FocusSearchService.directSiteURL(for: local) {
            let address = site.absoluteString
            seen.insert(address.lowercased())
            results.append(SearchSuggestion(text: address, kind: .url))
        }
        for phrase in remote {
            let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            results.append(SearchSuggestion(text: trimmed, kind: .query))
            if results.count >= 8 { break }
        }
        return results
    }

    private static func fetch(_ query: String, session: URLSession) async -> [String] {
        var components = URLComponents(string: "https://duckduckgo.com/ac/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "list"),
            URLQueryItem(name: "kl", value: "wt-wt")
        ]
        guard let url = components?.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
            if let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return list
            }
            if let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return rows.compactMap { $0["phrase"] as? String }
            }
            return []
        } catch {
            return []
        }
    }
}

/// The suggestion card that opens under the address bar while it is focused.
/// Tapping a row loads it in the current tab and closes the keyboard.
struct AddressSuggestionList: View {
    @ObservedObject var model: BrowserModel
    var addressFocused: FocusState<Bool>.Binding
    @StateObject private var suggestions = SearchSuggestionsController()

    var body: some View {
        Group {
            if !suggestions.items.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestions.items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            model.addressText = item.text
                            model.load(item.text)
                            addressFocused.wrappedValue = false
                            suggestions.clear()
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        if index < suggestions.items.count - 1 {
                            Rectangle()
                                .fill(Theme.hairline)
                                .frame(height: 1)
                                .padding(.leading, 38)
                        }
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.hairline)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: model.addressText) { _, text in
            suggestions.update(for: text)
        }
        .onAppear { suggestions.update(for: model.addressText) }
    }

    private func row(_ item: SearchSuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind == .url ? "globe" : "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(item.text)
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: item.kind == .url ? "arrow.right" : "arrow.up.left")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}
