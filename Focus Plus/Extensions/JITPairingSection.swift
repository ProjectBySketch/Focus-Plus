//
//  JITPairingSection.swift
//  Focus Plus
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings → JIT & Pairing: add a `.mobiledevicepairing` file for this phone,
/// see what it holds, check whether the local JIT tunnel is up, and remove it
/// again. The pairing record never leaves the device.
struct JITPairingSection: View {
    @ObservedObject private var jit = JITManager.shared
    @State private var showPicker = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        Section {
            statusRow

            if let pairing = jit.pairing {
                LabeledContent("Device", value: pairing.displayName)
                LabeledContent("UDID", value: pairing.udid)
                LabeledContent("Added", value: pairing.importedAt.formatted(date: .abbreviated, time: .shortened))
            }

            Button {
                showPicker = true
            } label: {
                Label(jit.isPaired ? "Replace pairing file…" : "Add pairing file…",
                      systemImage: "doc.badge.plus")
            }

            if jit.isPaired {
                Button {
                    Task { await jit.checkTunnel() }
                } label: {
                    Label("Check JIT tunnel", systemImage: "bolt.horizontal")
                }
                Toggle("Enable JIT automatically", isOn: $jit.enableAutomatically)
                Button(role: .destructive) {
                    jit.removePairing()
                    message = nil
                } label: {
                    Label("Remove pairing file", systemImage: "trash")
                }
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(messageIsError ? Color.red : Color.secondary)
            }
        } header: {
            Text("JIT & Pairing")
        } footer: {
            Text("Optional. Add the .mobiledevicepairing file exported for this phone — the same pairing record a debug build uses — and Focus Plus keeps it sealed with the app's own Keychain key. JIT itself is handed over by a local tunnel such as StikDebug running on this device, listening on \(JITManager.tunnelHost):\(String(JITManager.tunnelPort)); Focus Plus only checks that it is up and never opens one itself. Nothing is uploaded, and removing the pairing file deletes it from this device.")
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
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: jit.pairing == nil ? "link.badge.plus" : jit.tunnel.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(jit.tunnel == .reachable ? Theme.accent : .secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(jit.pairing == nil ? "No pairing file" : "Paired")
                    .font(.subheadline.weight(.semibold))
                Text(jit.pairing == nil
                     ? "JIT stays off until a pairing file is added."
                     : jit.tunnel.label + (jit.lastChecked.map { " · " + $0.formatted(date: .omitted, time: .shortened) } ?? ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if jit.tunnel == .checking {
                ProgressView()
            }
        }
        .padding(.vertical, 2)
    }

    private func accept(_ url: URL) {
        switch jit.importPairingFile(at: url) {
        case .success(let pairing):
            message = "Paired with \(pairing.displayName). Check the tunnel to enable JIT."
            messageIsError = false
            Task { await jit.checkTunnel() }
        case .failure(let error):
            message = error.errorDescription
            messageIsError = true
        }
    }
}
