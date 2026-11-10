//
//  PairingGenerator.swift
//  Focus Plus
//

import Foundation
import Network

/// What the phone answers over the tunnel's lockdown service.
struct LockdownDeviceInfo: Equatable {
    var name: String?
    var model: String?
    var systemVersion: String?
    var build: String?
    var udid: String?
}

enum PairingGeneratorError: LocalizedError {
    case badAddress
    case unreachable(String)
    case transport(String)
    case badReply(String)
    case refused(String)

    var errorDescription: String? {
        switch self {
        case .badAddress:
            return "That tunnel address is not valid. Use an IP address and a port, such as 127.0.0.1:62078."
        case .unreachable(let detail):
            return "Nothing is listening on that address (\(detail)). Start the JIT tunnel first."
        case .transport(let detail):
            return "The tunnel closed the connection: \(detail)"
        case .badReply(let detail):
            return "The tunnel answered something that is not a lockdown message: \(detail)"
        case .refused(let detail):
            return "The phone refused the request: \(detail)"
        }
    }
}

/// The lockdown protocol: length-prefixed property lists exchanged over a
/// tunnel to the device. Only the readable half is implemented here — asking
/// the phone who it is, and whether it wants a session — because the half that
/// writes a pairing record needs a client certificate and a TLS handshake this
/// app cannot build (iOS has no way to turn a generated key into a SecIdentity,
/// and bundling a TLS stack would add a dependency).
final class LockdownLink {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.projectbysketch.focusplus.lockdown")
    private var pending = Data()

    init(host: String, port: UInt16) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw PairingGeneratorError.badAddress
        }
        connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
    }

    func connect(timeout: TimeInterval = 4) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let gate = OnceGate()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.claim() { continuation.resume() }
                case .failed(let error):
                    if gate.claim() {
                        continuation.resume(throwing: PairingGeneratorError.unreachable(error.localizedDescription))
                    }
                case .cancelled:
                    if gate.claim() {
                        continuation.resume(throwing: PairingGeneratorError.unreachable("closed"))
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                if gate.claim() {
                    continuation.resume(throwing: PairingGeneratorError.unreachable("timed out"))
                }
            }
        }
    }

    func close() {
        connection.cancel()
    }

    /// One lockdown message: a 4-byte big-endian length, then the XML plist.
    func send(_ value: [String: Any]) async throws {
        guard let payload = try? PropertyListSerialization.data(
            fromPropertyList: value,
            format: .xml,
            options: 0
        ) else {
            throw PairingGeneratorError.transport("could not encode the request")
        }
        var length = UInt32(payload.count).bigEndian
        var message = Data(bytes: &length, count: 4)
        message.append(payload)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: message, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: PairingGeneratorError.transport(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func receive() async throws -> [String: Any] {
        let header = try await read(exactly: 4)
        let length = header.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
        guard length > 0, length < 8 * 1024 * 1024 else {
            throw PairingGeneratorError.badReply("bad message length \(length)")
        }
        let body = try await read(exactly: Int(length))
        guard let plist = try? PropertyListSerialization.propertyList(from: body, format: nil),
              let dictionary = plist as? [String: Any] else {
            throw PairingGeneratorError.badReply("not a property list")
        }
        return dictionary
    }

    private func read(exactly count: Int) async throws -> Data {
        while pending.count < count {
            let chunk = try await readChunk()
            if chunk.isEmpty { throw PairingGeneratorError.transport("closed while reading") }
            pending.append(chunk)
        }
        let result = pending.prefix(count)
        pending.removeFirst(count)
        return Data(result)
    }

    private func readChunk() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: PairingGeneratorError.transport(error.localizedDescription))
                    return
                }
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                    return
                }
                if isComplete {
                    continuation.resume(returning: Data())
                    return
                }
                continuation.resume(returning: Data())
            }
        }
    }

    private final class OnceGate {
        private let lock = NSLock()
        private var claimed = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            if claimed { return false }
            claimed = true
            return true
        }
    }
}

/// Reads the phone through the tunnel: the lockdown handshake without the
/// encrypted half, so the app can prove the tunnel is real and show which
/// device it points at.
@MainActor
final class PairingGenerator: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case finished
        case failed(String)
    }

    static let shared = PairingGenerator()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var log: [String] = []
    @Published private(set) var device: LockdownDeviceInfo?
    @Published private(set) var wantsEncryptedSession = false
    @Published var host: String = JITManager.tunnelHost
    @Published var portText: String = String(JITManager.tunnelPort)

    private var hostID: String?

    func run() async {
        guard phase != .running else { return }
        phase = .running
        log = []
        device = nil
        wantsEncryptedSession = false
        hostID = UUID().uuidString.uppercased()

        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? JITManager.tunnelPort
        var link: LockdownLink?
        do {
            record("Connecting to \(host):\(port)")
            let opened = try LockdownLink(host: host, port: port)
            link = opened
            try await opened.connect()
            record("Connected")

            try await opened.send(["Label": "Focus Plus", "Request": "QueryType"])
            let type = try await opened.receive()
            guard let kind = type["Type"] as? String else {
                throw PairingGeneratorError.badReply("no Type in the reply")
            }
            record("Service: \(kind)")
            guard kind == "com.apple.mobile.lockdown" else {
                throw PairingGeneratorError.badReply("that is \(kind), not lockdown")
            }

            var info = LockdownDeviceInfo()
            info.name = try await value(opened, key: "DeviceName")
            info.model = try await value(opened, key: "ProductType")
            info.systemVersion = try await value(opened, key: "ProductVersion")
            info.build = try await value(opened, key: "BuildVersion")
            info.udid = try await value(opened, key: "UniqueDeviceID")
            device = info
            record("Device: \(info.name ?? "unknown") · \(info.model ?? "?") · iOS \(info.systemVersion ?? "?")")

            // The session request is where the phone says whether it needs TLS
            // for everything that follows — which is exactly where a record
            // would have to be written, and where this app stops.
            try await opened.send([
                "Label": "Focus Plus",
                "Request": "StartSession",
                "HostID": hostID ?? "",
                "SystemBUID": UUID().uuidString.uppercased()
            ])
            let session = try await opened.receive()
            if let error = session["Error"] as? String {
                record("Session refused: \(error)")
            } else {
                wantsEncryptedSession = session["EnableSessionSSL"] as? Bool ?? false
                record(wantsEncryptedSession
                       ? "Session started — the phone requires TLS for pairing"
                       : "Session started — no TLS requested")
            }

            phase = .finished
            record("Done. This is as far as the unencrypted handshake goes.")
        } catch {
            let message = error.localizedDescription
            record("Failed: \(message)")
            phase = .failed(message)
        }
        link?.close()
    }

    private func value(_ link: LockdownLink, key: String) async throws -> String? {
        try await link.send(["Label": "Focus Plus", "Request": "GetValue", "Key": key])
        let reply = try await link.receive()
        if let error = reply["Error"] as? String {
            record("\(key): \(error)")
            return nil
        }
        return reply["Value"] as? String
    }

    private func record(_ line: String) {
        log.append(line)
    }
}
