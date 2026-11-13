//
//  JITPairingView.swift
//  Focus Plus
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Settings → JIT & Pairing: every phone paired with this app, which one is in
/// use, where the companion tunnel answers, and one button per action. A
/// record can be added from a file or generated on the device; either way it is
/// sealed with the app's own Keychain key and never leaves this phone.
struct JITPairingView: View {
    @ObservedObject private var jit = JITManager.shared
    @State private var showPicker = false
    @State private var showGenerator = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var pendingRemoval: JITPairing?

    private var removalBinding: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { showing in if !showing { pendingRemoval = nil } }
        )
    }

    var body: some View {
        Form {
            Section {
                statusHeader
            } footer: {
                Text(jit.isPaired
                     ? "The record is sealed on this device and read only when a tunnel asks for JIT."
                     : "JIT stays off until a pairing file is added. It is optional — the browser works without it.")
            }

            Section {
                TextField("Tunnel host", text: $jit.tunnelHostText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("Port", text: $jit.tunnelPortText)
                    .keyboardType(.numberPad)
                Button {
                    Task { await jit.checkTunnel() }
                } label: {
                    Label("Check the tunnel", systemImage: "bolt.horizontal")
                }
                .disabled(!jit.isPaired)
                Toggle("Enable JIT automatically", isOn: $jit.enableAutomatically)
            } header: {
                Text("Tunnel")
            } footer: {
                Text("Point this at the local tunnel a JIT helper such as StikDebug opens on this device — normally \(JITManager.defaultHost):\(String(JITManager.defaultPort)). Focus Plus only connects to it on localhost to check it is up; it never opens a tunnel itself. With automatic JIT on, the browser asks the tunnel as pages load instead of waiting for a manual check.")
            }

            Section {
                if jit.pairings.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No pairing file").font(.subheadline.weight(.semibold))
                            Text("Add one below, or generate it on this device.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                } else {
                    ForEach(jit.pairings) { pairing in
                        pairingRow(pairing)
                    }
                    if jit.pairings.count > 1 {
                        Button(role: .destructive) {
                            jit.removeAllPairings()
                            message = "Every pairing file was removed from this device."
                            messageIsError = false
                        } label: {
                            Label("Remove every pairing file", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text(jit.pairings.count == 1 ? "Paired phone" : "Paired phones")
            } footer: {
                Text("The tick marks the phone in use. Tapping another one switches to it — each record is stored separately, so a second phone never overwrites the first.")
            }

            Section {
                Button {
                    showGenerator = true
                } label: {
                    Label("Generate a pairing file…", systemImage: "wand.and.stars")
                }
                Button {
                    showPicker = true
                } label: {
                    Label(jit.isPaired ? "Add or replace from a file…" : "Add a pairing file…",
                          systemImage: "doc.badge.plus")
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(messageIsError ? Color.red : Color.secondary)
                }
            } header: {
                Text("Pair")
            } footer: {
                Text("Generating speaks the whole lockdown handshake through the tunnel above and asks the phone to write the record — it needs the tunnel running. A file exported by SideStore or the StikDebug helper works too. Either way it is validated (UDID plus the certificates the handshake needs), sealed with the app's Keychain key and stored where only this app can read it. Nothing is uploaded.")
            }
        }
        .navigationTitle("JIT & Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await jit.checkTunnelIfPaired() }
        }
        .sheet(isPresented: $showGenerator) {
            PairingGeneratorView()
        }
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                accept(url)
            case .failure(let error):
                message = error.localizedDescription
                messageIsError = true
            }
        }
        .confirmationDialog(
            "Remove this pairing file?",
            isPresented: removalBinding,
            titleVisibility: .visible
        ) {
            if let record = pendingRemoval {
                Button("Remove \(record.displayName)", role: .destructive) {
                    jit.removePairing(record.udid)
                    pendingRemoval = nil
                    message = "Pairing file removed from this device."
                    messageIsError = false
                }
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The sealed record is deleted. You can add it again with the same file.")
        }
    }

    // MARK: - Pieces

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: jit.pairing == nil ? "link.badge.plus" : jit.tunnel.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(jit.tunnel == .reachable ? Theme.accent : .secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(jit.pairing == nil ? "Not paired" : jit.tunnel.label)
                    .font(.subheadline.weight(.semibold))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if jit.tunnel == .checking { ProgressView() }
        }
        .padding(.vertical, 2)
    }

    private var statusDetail: String {
        guard let pairing = jit.pairing else {
            return "No pairing file on this device yet."
        }
        var parts = [pairing.displayName]
        if !pairing.detail.isEmpty { parts.append(pairing.detail) }
        parts.append(jit.tunnelAddress)
        if let note = jit.probeNote, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    private func pairingRow(_ pairing: JITPairing) -> some View {
        let selected = jit.pairing?.udid == pairing.udid
        return HStack(spacing: 12) {
            Button {
                jit.setActive(pairing.udid)
                message = nil
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(selected ? Theme.accent : Color.secondary)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pairing.displayName)
                            .font(.subheadline.weight(.medium))
                        Text(rowDetail(pairing))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button {
                pendingRemoval = pairing
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                UIPasteboard.general.string = pairing.udid
            } label: {
                Label("Copy UDID", systemImage: "doc.on.doc")
            }
            if !selected {
                Button {
                    jit.setActive(pairing.udid)
                } label: {
                    Label("Use this phone", systemImage: "checkmark.circle")
                }
            }
            Button(role: .destructive) {
                pendingRemoval = pairing
            } label: {
                Label("Remove pairing file", systemImage: "trash")
            }
        }
    }

    private func rowDetail(_ pairing: JITPairing) -> String {
        var parts: [String] = []
        if !pairing.detail.isEmpty { parts.append(pairing.detail) }
        parts.append("…" + pairing.shortUDID)
        parts.append(pairing.importedAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }

    private func accept(_ url: URL) {
        switch jit.importPairingFile(at: url) {
        case .success(let pairing):
            message = "Paired with \(pairing.displayName)."
            messageIsError = false
            Task { await jit.checkTunnel() }
        case .failure(let error):
            message = error.errorDescription
            messageIsError = true
        }
    }
}
