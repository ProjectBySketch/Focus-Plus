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
                    Text("Focus Plus runs the whole lockdown handshake here: it introduces itself to the phone, reads it, generates a host certificate with OpenSSL, starts the encrypted session and asks the phone to write the pairing record. The finished record is sealed with the app's Keychain key and stored where only this app can read it — nothing is uploaded.")
                        .font(.footnote)
                    Text("This needs the JIT tunnel running on this device, because that is what reaches the phone's lockdown service. If the handshake stops, the log above names the step that refused it. A record made by SideStore or the StikDebug helper can still be added with “Add pairing file…”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("What this does")
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
