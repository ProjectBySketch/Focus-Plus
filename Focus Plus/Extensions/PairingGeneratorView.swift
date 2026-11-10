//
//  PairingGeneratorView.swift
//  Focus Plus
//

import SwiftUI

/// The pairing-file sheet: read the phone through the local tunnel, see what
/// it says, and get the one step that still has to happen elsewhere — the
/// encrypted half of the lockdown handshake that writes the record.
struct PairingGeneratorView: View {
    @ObservedObject private var generator = PairingGenerator.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tunnel host", text: $generator.host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Port", text: $generator.portText)
                        .keyboardType(.numberPad)
                    Button {
                        Task { await generator.run() }
                    } label: {
                        if generator.phase == .running {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Reading the phone…")
                            }
                        } else {
                            Label("Read the phone over the tunnel", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .disabled(generator.phase == .running)
                } header: {
                    Text("Tunnel")
                } footer: {
                    Text("Point this at the local tunnel a JIT helper such as StikDebug opens on this device. Focus Plus only speaks to it on localhost — nothing leaves the phone.")
                }

                if let device = generator.device {
                    Section("Device") {
                        LabeledContent("Name", value: device.name ?? "—")
                        LabeledContent("Model", value: device.model ?? "—")
                        LabeledContent("iOS", value: device.systemVersion ?? "—")
                        LabeledContent("Build", value: device.build ?? "—")
                        LabeledContent("UDID", value: device.udid ?? "—")
                        LabeledContent("TLS for pairing",
                                       value: generator.wantsEncryptedSession ? "Required" : "Not required")
                    }
                }

                if !generator.log.isEmpty {
                    Section("Handshake") {
                        ForEach(Array(generator.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if case .failed(let message) = generator.phase {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Text("A pairing file is written at the end of the encrypted half of this handshake: the app has to present a host certificate to the phone and sign the record with it. iOS gives an app no way to turn a key it generated into a SecIdentity, so that step needs a TLS stack the app does not bundle — the same reason SideStore and StikDebug ship one.")
                        .font(.footnote)
                    Text("Use their generator for the record (SideStore → Settings → Pairing file, or the StikDebug helper), then add it with “Add pairing file…” on this page. It is the same record these handshake steps are leading to.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Where the record comes from")
                }
            }
            .navigationTitle("Pairing file")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
