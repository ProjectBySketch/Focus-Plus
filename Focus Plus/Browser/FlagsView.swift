//
//  FlagsView.swift
//  Focus Plus
//

import SwiftUI

/// The Flags page: a page inside the tab, with the same header as History,
/// every switch the build reads grouped and filterable, and a change saved the
/// moment it is tapped. Nothing here needs a relaunch.
struct FlagsView: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var flags = FlagsStore.shared

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
        VStack(spacing: 0) {
            header
            searchField
            list
        }
        .background(Theme.backdropGradient.ignoresSafeArea())
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
        .preferredColorScheme(.dark)
    }


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
                    Text("Flags")
                        .font(.title3.bold())
                    Text("\(BrowserFlag.allCases.count) switches · saved on this device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if flags.changedCount > 0 {
                Text("\(flags.changedCount) changed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.accent.opacity(0.16), in: Capsule())
            }

            Menu {
                Button {
                    flags.enableAllExperimental()
                } label: {
                    Label("Enable All Experimental", systemImage: "flask")
                }
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Theme.surface, in: Circle())
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
            TextField("Filter flags", text: $query)
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


    private var list: some View {
        List {
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
                Text("Every flag is also reachable at focus://flags. Flags are saved on this device with the rest of the app's settings.")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 150)
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
