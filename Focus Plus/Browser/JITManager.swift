//
//  JITManager.swift
//  Focus Plus
//

import Foundation
import Network
import SwiftUI

/// What a pairing file tells us about the phone it was made for.
struct JITPairing: Equatable {
    let udid: String
    let deviceName: String?
    let importedAt: Date

    var displayName: String { deviceName ?? String(udid.prefix(8)) + "…" }
}

enum JITPairingError: LocalizedError {
    case unreadable
    case notAPairingFile
    case sealFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "That file could not be read. Try exporting the pairing file again."
        case .notAPairingFile:
            return "That is not a pairing file. Pick the .mobiledevicepairing file made for this phone."
        case .sealFailed:
            return "The pairing file could not be sealed and saved on this device."
        }
    }
}

/// Optional on-device JIT, the way a debug build gets execution rights: the
/// user adds the phone's pairing file and the app keeps it sealed with the
/// app's own Keychain key, then reports whether a StikDebug-style local tunnel
/// is listening. Nothing here opens a tunnel itself — that is the companion
/// app's job — and nothing leaves the device: the pairing record is only ever
/// read locally, and it can be removed in one tap.
@MainActor
final class JITManager: ObservableObject {
    static let shared = JITManager()

    enum TunnelState: String {
        case unknown
        case checking
        case reachable
        case unreachable

        var label: String {
            switch self {
            case .unknown: return "Not checked"
            case .checking: return "Checking…"
            case .reachable: return "Tunnel ready"
            case .unreachable: return "No tunnel"
            }
        }

        var symbol: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .checking: return "antenna.radiowaves.left.and.right"
            case .reachable: return "bolt.horizontal.circle.fill"
            case .unreachable: return "bolt.slash.circle"
            }
        }
    }

    @Published private(set) var pairing: JITPairing?
    @Published private(set) var tunnel: TunnelState = .unknown
    @Published private(set) var lastChecked: Date?
    /// Kept as a plain switch: when a tunnel is up, the browser asks it for
    /// JIT as pages load instead of waiting for a manual check.
    @Published var enableAutomatically: Bool {
        didSet { defaults.set(enableAutomatically, forKey: Keys.auto) }
    }

    /// Where StikDebug-style tunnels listen for the debug handshake.
    static let tunnelHost = "127.0.0.1"
    static let tunnelPort: UInt16 = 62078

    private let defaults = UserDefaults.standard

    var isPaired: Bool { pairing != nil }

    init() {
        enableAutomatically = defaults.bool(forKey: Keys.auto)
        loadMetadata()
    }

    // MARK: - Pairing file

    /// Validates and stores a `.mobiledevicepairing` file. Only the metadata
    /// used by the status rows is kept in UserDefaults — the record itself is
    /// sealed and written to Application Support.
    @discardableResult
    func importPairingFile(at url: URL) -> Result<JITPairing, JITPairingError> {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            return .failure(.unreadable)
        }
        return importPairingData(data)
    }

    /// Stores a record produced by the in-app generator exactly as it stores
    /// one read from a file: validated, sealed with the Keychain key and
    /// written where only this app can read it.
    @discardableResult
    func importPairingData(_ data: Data) -> Result<JITPairing, JITPairingError> {
        guard !data.isEmpty else {
            return .failure(.unreadable)
        }
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil))
            as? [String: Any] else {
            return .failure(.notAPairingFile)
        }
        guard let udid = (plist["UDID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !udid.isEmpty else {
            return .failure(.notAPairingFile)
        }
        // A real pairing record carries the certificates the handshake needs;
        // a random plist with a UDID key is not enough.
        let certificateKeys = ["DeviceCertificate", "HostCertificate", "RootCertificate", "RootPrivateKey"]
        guard certificateKeys.allSatisfy({ plist[$0] != nil }) else {
            return .failure(.notAPairingFile)
        }
        guard let sealed = SecureVault.seal(data) else {
            return .failure(.sealFailed)
        }
        do {
            try FileManager.default.createDirectory(
                at: vaultURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try sealed.write(to: vaultURL, options: .atomic)
        } catch {
            return .failure(.sealFailed)
        }

        let name = (plist["DeviceName"] as? String) ?? (plist["DeviceNameString"] as? String)
        let record = JITPairing(udid: udid, deviceName: name, importedAt: Date())
        pairing = record
        saveMetadata(record)
        return .success(record)
    }

    func removePairing() {
        pairing = nil
        tunnel = .unknown
        lastChecked = nil
        try? FileManager.default.removeItem(at: vaultURL)
        defaults.removeObject(forKey: Keys.udid)
        defaults.removeObject(forKey: Keys.name)
        defaults.removeObject(forKey: Keys.importedAt)
    }

    /// True when a sealed pairing record is on disk — used by the browser to
    /// decide whether JIT is available at all.
    var hasStoredRecord: Bool {
        FileManager.default.fileExists(atPath: vaultURL.path)
    }

    // MARK: - Tunnel

    /// Asks the local tunnel whether anything is listening. A plain TCP
    /// connect with a short deadline is enough: the debug service answers a
    /// connection when it is up, and nothing is sent over it.
    func checkTunnel() async {
        guard isPaired else {
            tunnel = .unknown
            return
        }
        tunnel = .checking
        let reachable = await Self.probe()
        tunnel = reachable ? .reachable : .unreachable
        lastChecked = Date()
    }

    private static func probe() async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = ProbeGate()
            guard let port = NWEndpoint.Port(rawValue: tunnelPort) else {
                continuation.resume(returning: false)
                return
            }
            let connection = NWConnection(
                host: NWEndpoint.Host(tunnelHost),
                port: port,
                using: .tcp
            )
            let finish: (Bool) -> Void = { open in
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: open)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
                finish(false)
            }
        }
    }

    /// Makes sure only the first of "ready", "failed" and "timed out" answers.
    private final class ProbeGate {
        private let lock = NSLock()
        private var answered = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if answered { return false }
            answered = true
            return true
        }
    }

    // MARK: - Storage

    private var vaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("jit", isDirectory: true)
            .appendingPathComponent("pairing.vault")
    }

    private func loadMetadata() {
        guard let udid = defaults.string(forKey: Keys.udid) else { return }
        let name = defaults.string(forKey: Keys.name)
        let date = defaults.object(forKey: Keys.importedAt) as? Date ?? Date()
        pairing = JITPairing(udid: udid, deviceName: name, importedAt: date)
    }

    private func saveMetadata(_ record: JITPairing) {
        defaults.set(record.udid, forKey: Keys.udid)
        defaults.set(record.deviceName, forKey: Keys.name)
        defaults.set(record.importedAt, forKey: Keys.importedAt)
    }

    private enum Keys {
        static let udid = "jit.pairing.udid"
        static let name = "jit.pairing.name"
        static let importedAt = "jit.pairing.importedAt"
        static let auto = "jit.enableAutomatically"
    }
}
