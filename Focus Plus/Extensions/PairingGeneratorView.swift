//
//  PairingGeneratorView.swift
//  Focus Plus
//

import SwiftUI

/// The pairing-file sheet: read the phone through the local tunnel, watch the
/// handshake step by step, and end up with a record this device keeps sealed.
struct PairingGeneratorView: View {
    @ObservedObject private var generator = PairingGenerator.shared
    @Environment(\.dismiss) private var dismiss

    private var isRunning: Bool { generator.phase == .running }
    private var didFinish: Bool { generator.phase == .finished }

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
                        if isRunning {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Talking to the phone…")
                            }
                        } else {
                            Label(didFinish ? "Generate again" : "Pair through the tunnel",
                                  systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .disabled(isRunning)
                } header: {
                    Text("Tunnel")
                } footer: {
                    Text("The local tunnel a JIT helper such as StikDebug opens on this device. The address is shared with the JIT page, so both always agree. Focus Plus only speaks to it on localhost.")
                }

                if didFinish, let saved = generator.savedPairing {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Paired with \(saved.displayName)")
                                    .font(.subheadline.weight(.semibold))
                                Text("The record is sealed and switched on.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                if let device = generator.device {
                    Section("Device") {
                        LabeledContent("Name", value: device.name ?? "—")
                        LabeledContent("Model", value: device.model ?? "—")
                        LabeledContent("iOS", value: device.systemVersion ?? "—")
                        LabeledContent("Build", value: device.build ?? "—")
                        LabeledContent("UDID", value: device.udid ?? "—")
                        LabeledContent("Encrypted session",
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
                    } header: {
                        Text("Stopped")
                    } footer: {
                        Text("The log above names the step that refused. A record made by SideStore or the StikDebug helper can still be added with “Add a pairing file…”.")
                    }
                }

                Section {
                    Text("Focus Plus runs the whole lockdown handshake here: it introduces itself, reads the phone, generates a host certificate with OpenSSL, starts the encrypted session and asks the phone to write the pairing record. The finished record is sealed with the app's Keychain key and stored where only this app can read it — nothing is uploaded.")
                        .font(.footnote)
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
