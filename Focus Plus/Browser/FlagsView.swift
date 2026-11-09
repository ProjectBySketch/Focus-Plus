//
//  FlagsView.swift
//  Focus Plus
//

import SwiftUI

/// The Flags page: every switch the build reads, grouped, searchable, and
/// saved the moment it is tapped. Nothing here needs a relaunch.
struct FlagsView: View {
    @ObservedObject private var flags = FlagsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var showResetConfirmation = false

    private var visibleFlags: [BrowserFlag] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return BrowserFlag.allCases }
        return BrowserFlag.allCases.filter {
            $0.title.lowercased().contains(needle)
                || $0.summary.lowercased().contains(needle)
                || $0.rawValue.lowercased().contains(needle)
        }
    }

    private func flags(in group: FlagGroup) -> [BrowserFlag] {
        visibleFlags.filter { $0.group == group }
    }

    var body: some View {
        NavigationStack {
            List {
                introSection

                ForEach(FlagGroup.allCases) { group in
                    let groupFlags = flags(in: group)
                    if !groupFlags.isEmpty {
                        Section {
                            ForEach(groupFlags) { flag in
                                row(flag)
                            }
                        } header: {
                            Label(group.rawValue, systemImage: group.symbol)
                        }
                    }
                }

                if visibleFlags.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: query)
                            .listRowBackground(Color.clear)
                    }
                }

                footerSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.baseBackground.ignoresSafeArea())
            .navigationTitle("Flags")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Filter flags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            flags.enableAllExperimental()
                        } label: {
                            Label("Enable All Experimental", systemImage: "flask")
                        }
                        Button {
                            flags.reset()
                        } label: {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .foregroundStyle(Theme.accent)
                    Text("\(BrowserFlag.allCases.count) flags")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if flags.changedCount > 0 {
                        Text("\(flags.changedCount) changed")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.16), in: Capsule())
                    }
                }
                Text("These switches change how Focus Plus behaves right away. Stable ones are on in every build; beta and experimental ones may move, break or vanish.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var footerSection: some View {
        Section {
            Button {
                flags.enableAllExperimental()
            } label: {
                Label("Enable all experimental flags", systemImage: "flask")
            }
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Reset every flag", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Everything at once")
        } footer: {
            Text("Every flag can also be reached by typing focus://flags in the address bar. Flags are saved on this device with the rest of the app's settings.")
        }
        .confirmationDialog(
            "Reset every flag?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { flags.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each switch goes back to the value this build ships with.")
        }
    }

    private func row(_ flag: BrowserFlag) -> some View {
        Toggle(isOn: Binding(
            get: { flags.isEnabled(flag) },
            set: { flags.set(flag, enabled: $0) }
        )) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(flag.title)
                        .font(.subheadline.weight(.semibold))
                    stageBadge(flag.stage)
                }
                Text(flag.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(flag.rawValue)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)
        }
    }

    private func stageBadge(_ stage: FlagStage) -> some View {
        Text(stage.rawValue)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .textCase(.uppercase)
            .foregroundStyle(color(for: stage))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color(for: stage).opacity(0.16), in: Capsule())
    }

    private func color(for stage: FlagStage) -> Color {
        switch stage {
        case .stable: return .secondary
        case .beta: return .orange
        case .experimental: return Theme.incognito
        }
    }
}
