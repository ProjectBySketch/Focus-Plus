//
//  HistoryView.swift
//  Focus Plus
//

import SwiftUI
import UIKit

/// The History page. It is a page, not a sheet: the tab shows it like any
/// other page, with its own header and a way back, and every visit stays
/// available — by day, by site, one by one — with a delete for each.
struct HistoryView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var store = HistoryStore.shared
    @ObservedObject private var flags = FlagsStore.shared

    @State private var query = ""
    @State private var showClearConfirmation = false
    @State private var dayToClear: Date?

    private var sections: [HistorySection] { store.sections(matching: query) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            header
            if flags.isEnabled(.historySearch) {
                searchField
            }
            content
        }
        .background(Theme.backdropGradient.ignoresSafeArea())
        .confirmationDialog(
            "Clear all browsing history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) { store.eraseAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every saved visit from this device. Open tabs, cookies and sign-ins are left alone.")
        }
        .confirmationDialog(
            "Clear this day's visits?",
            isPresented: Binding(
                get: { dayToClear != nil },
                set: { if !$0 { dayToClear = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear This Day", role: .destructive) {
                if let day = dayToClear { store.remove(on: day) }
                dayToClear = nil
            }
            Button("Cancel", role: .cancel) { dayToClear = nil }
        } message: {
            Text("Only that day's visits are removed. Everything else stays.")
        }
        .preferredColorScheme(.dark)
    }


    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                manager.closeInternalPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 9) {
                AppLogo(style: .tile, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("History")
                        .font(.title3.bold())
                    Text("\(store.visitCount) visits · \(store.siteCount) sites · kept on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !store.entries.isEmpty {
                Menu {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Theme.surface, in: Circle())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("Search titles and addresses", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairline)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }


    // MARK: - List

    private var content: some View {
        List {
            if !store.entries.isEmpty {
                statsSection
            }

            if sections.isEmpty {
                emptySection
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                            row(entry)
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }

            if !flags.isEnabled(.historyRecord) {
                Section {
                    Label(
                        "History recording is turned off in Flags, so new visits are not saved.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } else if !CustomizationStore.shared.keepCookies {
                Section {
                    Label(
                        "With Keep cookies and sign-ins off, a session keeps nothing — new visits are not saved.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 150)
    }

    private func sectionHeader(_ section: HistorySection) -> some View {
        HStack {
            Text(section.title)
            Spacer()
            Text("\(section.entries.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            Menu {
                Button(role: .destructive) {
                    dayToClear = section.id
                } label: {
                    Label("Clear This Day", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 22)
            }
        }
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 10) {
                statTile("\(store.visitCount)", "visits")
                statTile("\(store.siteCount)", "sites")
                statTile("\(store.visits())", "today")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.hairline)
        )
    }

    private var emptySection: some View {
        Section {
            ContentUnavailableView {
                Label(isSearching ? "Nothing matches" : "No history yet",
                      systemImage: isSearching ? "magnifyingglass" : "clock.arrow.circlepath")
            } description: {
                Text(isSearching
                     ? "No saved visit has that in its title or address."
                     : "Pages you visit appear here, grouped by the day you read them, and stay until you delete them.")
            }
            .listRowBackground(Color.clear)
        }
    }


    private func row(_ entry: HistoryEntry) -> some View {
        Button {
            manager.openHistoryEntry(entry, inNewTab: true)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.16))
                    Text(entry.monogram)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(entry.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(entry.visitedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.remove(entry.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                manager.openHistoryEntry(entry, inNewTab: true)
            } label: {
                Label("Open in New Tab", systemImage: "plus.square.on.square")
            }
            Button {
                manager.openHistoryEntry(entry, inNewTab: false)
                manager.closeInternalPage()
            } label: {
                Label("Open Here", systemImage: "arrow.up.forward.square")
            }
            Button {
                UIPasteboard.general.string = entry.url
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) {
                store.remove(entry.id)
            } label: {
                Label("Delete Visit", systemImage: "trash")
            }
            Button(role: .destructive) {
                store.removeAll(from: entry.host)
            } label: {
                Label("Delete Everything From \(entry.host)", systemImage: "xmark.circle")
            }
        }
    }
}
