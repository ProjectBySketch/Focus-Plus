//
//  HistoryView.swift
//  Focus Plus
//

import SwiftUI
import UIKit

/// The dedicated history page: every visit the browser kept, grouped by day,
/// searchable, and able to reopen a page in a new tab or in the current one.
struct HistoryView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var store = HistoryStore.shared
    @ObservedObject private var flags = FlagsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var showClearConfirmation = false

    private var sections: [HistorySection] { store.sections(matching: query) }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            searchableList
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Theme.baseBackground.ignoresSafeArea())
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .confirmationDialog(
                    "Clear all browsing history?",
                    isPresented: $showClearConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Clear History", role: .destructive) { store.eraseAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes every saved visit from this device. Open tabs, cookies and sign-ins are left alone.")
                }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var searchableList: some View {
        if flags.isEnabled(.historySearch) {
            listContent
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search titles and addresses"
                )
        } else {
            listContent
        }
    }

    private var listContent: some View {
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
                        HStack {
                            Text(section.title)
                            Spacer()
                            Text("\(section.entries.count)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
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
    }

    private var statsSection: some View {
        Section {
            HStack(spacing: 10) {
                statTile("\(store.visitCount)", "visits")
                statTile("\(store.siteCount)", "sites")
                statTile("\(store.visits())", "today")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
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
                     : "Pages you visit appear here, grouped by the day you read them.")
            }
            .listRowBackground(Color.clear)
        }
    }

    private func row(_ entry: HistoryEntry) -> some View {
        Button {
            manager.openHistoryEntry(entry, inNewTab: true)
            dismiss()
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
                dismiss()
            } label: {
                Label("Open in New Tab", systemImage: "plus.square.on.square")
            }
            Button {
                manager.openHistoryEntry(entry, inNewTab: false)
                dismiss()
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
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        if !store.entries.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All History", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
