//
//  IPadBrowserLayout.swift
//  Focus Plus
//

import SwiftUI

/// Large-screen layout for iPad: a persistent tab sidebar beside the page,
/// with the browser controls in a bar above the content.
struct IPadBrowserLayout: View {
    @ObservedObject var manager: TabManager
    @ObservedObject private var flags = FlagsStore.shared
    @FocusState private var addressFocused: Bool
    @State private var showTrackerTip = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)

            VStack(spacing: 0) {
                topBar

                if manager.isIncognito {
                    HStack {
                        IncognitoPill()
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)
                }

                TabContentView(manager: manager)

                if showTrackerTip, let model = manager.activeTab?.model {
                    TrackerTip(model: model)
                        .padding(.bottom, 10)
                        .onTapGesture { withAnimation(Theme.animation) { showTrackerTip = false } }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if let toastText = manager.toastText {
                    StatusToast(text: toastText, symbol: manager.toastSymbol,
                                actionTitle: manager.toastActionTitle) {
                        manager.allowPopupsForLastBlockedSite()
                    }
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.isIncognito)
        .onAppear { manager.captureTabPreviews() }
        .onDisappear { manager.clearTabPreviews() }
        .onChange(of: manager.pagesVisited) { _, _ in manager.captureActiveTabPreview() }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            brand

            ScrollView(showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(manager.tabs) { tab in
                        TabRow(manager: manager, model: tab.model, tabID: tab.id)
                    }
                }
            }

            Button {
                withAnimation(Theme.animation) { _ = manager.addTab() }
            } label: {
                Label("New Tab", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.hairline)
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Button { manager.enterHistory() } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                Button { manager.enterFlags() } label: {
                    Label("Flags", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                Button { manager.showSettings = true } label: {
                    Label("Settings & Extensions", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                if !CustomizationStore.shared.minimalisticMode {
                    Button(action: manager.requestErase) {
                        Label("Erase Browsing Data", systemImage: "trash")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 268)
        .background(Color(white: 1, opacity: 0.04))
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.accent.opacity(0.16)).frame(width: 32, height: 32)
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Focus Plus")
                    .font(.headline)
                Text("ProjectBySketch™")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !CustomizationStore.shared.minimalisticMode {
                Button {
                    withAnimation(Theme.animation) { manager.toggleIncognito() }
                } label: {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(manager.isIncognito ? Theme.incognito : Color.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            if let model = manager.activeTab?.model {
                ProgressBar(model: model)
            }

            HStack(spacing: 10) {
                if let model = manager.activeTab?.model {
                    if !model.isStart {
                        Button(action: model.goBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .opacity(model.canGoBack ? 1 : 0.3)
                        }
                        .buttonStyle(.plain)
                        .disabled(!model.canGoBack)

                        Button(action: model.toggleReload) {
                            Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                    }

                    AddressField(model: model, showTrackerTip: $showTrackerTip,
                                 addressFocused: $addressFocused)
                        .frame(maxWidth: 700)

                    Spacer()

                    Button { manager.enterHistory() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button { manager.enterFlags() } label: {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button { manager.showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }
}

private struct TabRow: View {
    @ObservedObject var manager: TabManager
    @ObservedObject var model: BrowserModel
    @ObservedObject private var flags = FlagsStore.shared
    let tabID: Tab.ID

    private var isActive: Bool { tabID == manager.activeTabID }

    var body: some View {
        HStack(spacing: 8) {
            if flags.isEnabled(.tabPreviews), let image = model.previewImage, !model.isStart {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                Image(systemName: model.isStart ? "shield.lefthalf.filled" : "globe")
                    .font(.system(size: 13))
                    .foregroundStyle(isActive ? Theme.accent : Color.secondary)
                    .frame(width: 44)
            }
            Text(model.displayedURL?.host ?? "Start Page")
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button {
                withAnimation(Theme.animation) { manager.close(tabID) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Theme.surface, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isActive ? 0.12 : 0.0))
        )
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(Theme.animation) { manager.select(tabID) } }
    }
}
