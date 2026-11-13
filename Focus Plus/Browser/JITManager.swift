//
//  JITManager.swift
//  Focus Plus
//

import Foundation
import Network
import SwiftUI

/// One pairing record kept on this device: the phone it was made for, what the
/// phone said about itself, and when it was added. A record is identified by
/// the phone's UDID, so the same phone added twice replaces its own entry
/// instead of piling up duplicates.
struct JITPairing: Identifiable, Equatable, Codable {
    let udid: String
    let deviceName: String?
    let model: String?
    let systemVersion: String?
    let importedAt: Date

    var id: String { udid }

    var displayName: String {
        if let deviceName, !deviceName.isEmpty { return deviceName }
        if let model, !model.isEmpty { return model }
        return "This iPhone"
    }

    /// The tail of the UDID, which is the part that differs between phones.
    var shortUDID: String {
        udid.count > 10 ? String(udid.suffix(10)) : udid
    }

    /// "iPhone17,1 · iOS 26.1" — whatever the phone answered, joined.
    var detail: String {
        var parts: [String] = []
        if let model, !model.isEmpty { parts.append(model) }
        if let systemVersion, !systemVersion.isEmpty { parts.append("iOS " + systemVersion) }
        return parts.joined(separator: " · ")
    }
}

enum JITPairingError: LocalizedError {
    case unreadable
    case notAPairingFile
    case missingFields([String])
    case sealFailed

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "That file could not be read. Try exporting the pairing file again."
        case .notAPairingFile:
            return "That is not a pairing file. Pick the .mobiledevicepairing file made for this phone."
        case .missingFields(let fields):
            return "That pairing file is incomplete — it has no \(fields.joined(separator: ", ")). Export it again with a pairing tool that writes the certificates."
        case .sealFailed:
            return "The pairing file could not be sealed and saved on this device."
        }
    }
}

/// Optional on-device JIT, the way a debug build gets execution rights: the
/// user adds the phone's pairing file and the app keeps it sealed with the
/// app's own Keychain key, then reports whether a StikDebug-style local tunnel
/// is answering. Any number of phones can be paired and switched between.
/// Nothing here opens a tunnel itself — that is the companion app's job — and
/// nothing leaves the device: the pairing records are only ever read locally,
/// and each can be removed in one tap.
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

    @Published private(set) var pairings: [JITPairing] = []
    @Published private(set) var activeUDID: String?
    @Published private(set) var tunnel: TunnelState = .unknown
    @Published private(set) var lastChecked: Date?
    /// Why the last probe failed, in the tunnel's own words.
    @Published private(set) var probeNote: String?
    /// Kept as a plain switch: when a tunnel is up, the browser asks it for
    /// JIT as pages load instead of waiting for a manual check.
    @Published var enableAutomatically: Bool {
        didSet { defaults.set(enableAutomatically, forKey: Keys.auto) }
    }
    /// Where the companion tunnel listens. Persisted, so the pairing sheet and
    /// the status check always agree on the address.
    @Published var tunnelHostText: String {
        didSet { defaults.set(tunnelHostText, forKey: Keys.host) }
    }
    @Published var tunnelPortText: String {
        didSet { defaults.set(tunnelPortText, forKey: Keys.port) }
    }

    /// The address StikDebug-style tunnels listen on, used until the user says
    /// otherwise.
    static let defaultHost = "127.0.0.1"
    static let defaultPort: UInt16 = 62078
    /// Kept for the views and copy that name the address directly.
    static let tunnelHost = defaultHost
    static let tunnelPort = defaultPort

    private let defaults = UserDefaults.standard

    /// The record in use: the selected phone, or the only one there is.
    var pairing: JITPairing? {
        if let activeUDID, let match = pairings.first(where: { $0.udid == activeUDID }) {
            return match
        }
        return pairings.first
    }

    var isPaired: Bool { pairing != nil }
    var isTunnelReady: Bool { tunnel == .reachable }

    var activeTunnelHost: String {
        let trimmed = tunnelHostText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultHost : trimmed
    }

    var activeTunnelPort: UInt16 {
        let trimmed = tunnelPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        return UInt16(trimmed) ?? Self.defaultPort
    }

    /// "127.0.0.1:62078", for the copy in Settings.
    var tunnelAddress: String { "\(activeTunnelHost):\(String(activeTunnelPort))" }

    init() {
        enableAutomatically = defaults.bool(forKey: Keys.auto)
        tunnelHostText = defaults.string(forKey: Keys.host) ?? Self.defaultHost
        tunnelPortText = defaults.string(forKey: Keys.port) ?? String(Self.defaultPort)
        loadPairings()
        migrateLegacyRecord()
    }

    // MARK: - Pairing files

    /// Validates and stores a `.mobiledevicepairing` file. Only the metadata
    /// the status rows need is kept in UserDefaults — each record itself is
    /// sealed and written to Application Support under its own phone's UDID.
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
    /// written where only this app can read it. Importing a phone that is
    /// already paired replaces its record and makes it the active one.
    @discardableResult
    func importPairingData(_ data: Data) -> Result<JITPairing, JITPairingError> {
        guard !data.isEmpty else { return .failure(.unreadable) }
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil))
            as? [String: Any] else {
            return .failure(.notAPairingFile)
        }
        guard let udid = (plist["UDID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !udid.isEmpty else {
            return .failure(.missingFields(["UDID"]))
        }
        // A real pairing record carries the certificates the handshake needs;
        // a random plist with a UDID key is not enough. The message names
        // exactly what the file is missing.
        let certificateKeys = ["DeviceCertificate", "HostCertificate", "RootCertificate", "RootPrivateKey"]
        let missing = certificateKeys.filter { plist[$0] == nil }
        guard missing.isEmpty else { return .failure(.missingFields(missing)) }

        guard let sealed = SecureVault.seal(data) else { return .failure(.sealFailed) }
        do {
            try FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
            try sealed.write(to: vaultURL(for: udid), options: .atomic)
        } catch {
            return .failure(.sealFailed)
        }

        let record = JITPairing(
            udid: udid,
            deviceName: (plist["DeviceName"] as? String) ?? (plist["DeviceNameString"] as? String),
            model: plist["ProductType"] as? String,
            systemVersion: plist["ProductVersion"] as? String,
            importedAt: Date()
        )
        if let index = pairings.firstIndex(where: { $0.udid == udid }) {
            pairings[index] = record
        } else {
            pairings.append(record)
        }
        activeUDID = udid
        savePairings()
        resetProbe()
        return .success(record)
    }

    /// Switches which paired phone the browser reports on.
    func setActive(_ udid: String) {
        guard pairings.contains(where: { $0.udid == udid }) else { return }
        activeUDID = udid
        savePairings()
        resetProbe()
    }

    /// Removes one phone's record, or the selected one when no UDID is given.
    func removePairing(_ udid: String? = nil) {
        guard let target = udid ?? pairing?.udid else { return }
        try? FileManager.default.removeItem(at: vaultURL(for: target))
        pairings.removeAll { $0.udid == target }
        if activeUDID == target { activeUDID = pairings.first?.udid }
        savePairings()
        resetProbe()
    }

    func removeAllPairings() {
        for record in pairings {
            try? FileManager.default.removeItem(at: vaultURL(for: record.udid))
        }
        pairings.removeAll()
        activeUDID = nil
        savePairings()
        resetProbe()
    }

    /// True when the selected phone's sealed record is on disk — used by the
    /// browser to decide whether JIT is available at all.
    var hasStoredRecord: Bool {
        guard let pairing else { return false }
        return FileManager.default.fileExists(atPath: vaultURL(for: pairing.udid).path)
    }

    /// Whether a phone's record is still where it was written.
    func hasRecord(for udid: String) -> Bool {
        FileManager.default.fileExists(atPath: vaultURL(for: udid).path)
    }

    // MARK: - Tunnel

    /// Asks the local tunnel whether anything is listening. A plain TCP
    /// connect with a short deadline is enough: the debug service answers a
    /// connection when it is up, and nothing is sent over it.
    func checkTunnel() async {
        guard isPaired else {
            tunnel = .unknown
            probeNote = "Add a pairing file first."
            return
        }
        tunnel = .checking
        probeNote = nil
        let result = await Self.probe(host: activeTunnelHost, port: activeTunnelPort)
        tunnel = result.open ? .reachable : .unreachable
        probeNote = result.open ? nil : result.note
        lastChecked = Date()
    }

    /// Checks only when there is something to check — called when the app
    /// comes back to the foreground.
    func checkTunnelIfPaired() async {
        guard isPaired, tunnel != .checking else { return }
        await checkTunnel()
    }

    private func resetProbe() {
        tunnel = .unknown
        lastChecked = nil
        probeNote = nil
    }

    private static func probe(host: String, port: UInt16) async -> (open: Bool, note: String?) {
        await withCheckedContinuation { continuation in
            let gate = ProbeGate()
            guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: (false, "That port number is not valid."))
                return
            }
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: endpointPort,
                using: .tcp
            )
            let finish: (Bool, String?) -> Void = { open, note in
                guard gate.claim() else { return }
                connection.cancel()
                continuation.resume(returning: (open, note))
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true, nil)
                case .failed(let error):
                    finish(false, error.localizedDescription)
                case .cancelled:
                    finish(false, "The connection was cancelled.")
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2.0) {
                finish(false, "Nothing answered at \(host):\(String(port)) within two seconds.")
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

    private var vaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("jit", isDirectory: true)
    }

    /// One sealed record per phone, named by its UDID with anything that is
    /// not a plain character stripped so it is safe as a file name.
    private func vaultURL(for udid: String) -> URL {
        let safe = udid.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return vaultDirectory.appendingPathComponent("\(safe.isEmpty ? "device" : safe).vault")
    }

    private func loadPairings() {
        if let data = defaults.data(forKey: Keys.pairings),
           let decoded = try? JSONDecoder().decode([JITPairing].self, from: data) {
            pairings = decoded.filter { hasRecord(for: $0.udid) }
        }
        activeUDID = defaults.string(forKey: Keys.activeUDID)
        if let current = activeUDID, !pairings.contains(where: { $0.udid == current }) {
            activeUDID = pairings.first?.udid
        }
        if activeUDID == nil { activeUDID = pairings.first?.udid }
    }

    private func savePairings() {
        if let data = try? JSONEncoder().encode(pairings) {
            defaults.set(data, forKey: Keys.pairings)
        }
        defaults.set(activeUDID, forKey: Keys.activeUDID)
    }

    /// Builds read the single record this manager used to keep. The file is
    /// moved to its per-phone name and the old keys are dropped, so nobody
    /// has to pair again after updating.
    private func migrateLegacyRecord() {
        let legacy = vaultDirectory.appendingPathComponent("pairing.vault")
        guard FileManager.default.fileExists(atPath: legacy.path),
              let udid = defaults.string(forKey: Keys.legacyUDID), !udid.isEmpty else { return }
        let name = defaults.string(forKey: Keys.legacyName)
        let date = defaults.object(forKey: Keys.legacyImportedAt) as? Date ?? Date()
        try? FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true)
        let destination = vaultURL(for: udid)
        if !FileManager.default.fileExists(atPath: destination.path) {
            try? FileManager.default.moveItem(at: legacy, to: destination)
        }
        if !pairings.contains(where: { $0.udid == udid }), hasRecord(for: udid) {
            pairings.append(JITPairing(udid: udid, deviceName: name, model: nil,
                                       systemVersion: nil, importedAt: date))
        }
        activeUDID = udid
        savePairings()
        [Keys.legacyUDID, Keys.legacyName, Keys.legacyImportedAt].forEach {
            defaults.removeObject(forKey: $0)
        }
    }

    private enum Keys {
        static let pairings = "jit.pairings.v2"
        static let activeUDID = "jit.activeUDID"
        static let auto = "jit.enableAutomatically"
        static let host = "jit.tunnel.host"
        static let port = "jit.tunnel.port"
        static let legacyUDID = "jit.pairing.udid"
        static let legacyName = "jit.pairing.name"
        static let legacyImportedAt = "jit.pairing.importedAt"
    }
}
