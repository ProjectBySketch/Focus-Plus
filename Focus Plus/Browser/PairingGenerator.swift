//
//  PairingGenerator.swift
//  Focus Plus
//

import Darwin
import Foundation
import OpenSSL

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
    case crypto(String)

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
        case .crypto(let detail):
            return "Could not build the host certificate: \(detail)"
        }
    }
}

/// A socket to the phone that TLS can take over in place — the one thing a
/// lockdown pairing needs and Network.framework cannot do, which is why this
/// talks to the socket directly and lets OpenSSL do the encrypted half.
final class PairingTransport {
    private var fd: Int32 = -1
    private var ssl: OpaquePointer?

    deinit { close() }

    func open(host: String, port: UInt16, timeoutSeconds: Int = 5) throws {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &address.sin_addr) == 1 else {
            throw PairingGeneratorError.badAddress
        }

        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw PairingGeneratorError.unreachable("could not open a socket")
        }

        var timeout = timeval(tv_sec: timeoutSeconds, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout,
                   socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout,
                   socklen_t(MemoryLayout<timeval>.size))

        let code = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                Darwin.connect(descriptor, sockaddrPointer,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard code == 0 else {
            Darwin.close(descriptor)
            throw PairingGeneratorError.unreachable(String(cString: strerror(errno)))
        }
        fd = descriptor
    }

    func close() {
        if let ssl {
            SSL_shutdown(ssl)
            SSL_free(ssl)
            self.ssl = nil
        }
        if fd >= 0 {
            Darwin.close(fd)
            fd = -1
        }
    }

    func write(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < data.count {
                let remaining = data.count - offset
                let written: Int
                if let ssl {
                    written = Int(SSL_write(ssl, base.advanced(by: offset), Int32(remaining)))
                } else {
                    written = Darwin.write(fd, base.advanced(by: offset), remaining)
                }
                guard written > 0 else {
                    throw PairingGeneratorError.transport("write failed")
                }
                offset += written
            }
        }
    }

    func read(exactly count: Int) throws -> Data {
        var data = Data(count: count)
        try data.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < count {
                let remaining = count - offset
                let read: Int
                if let ssl {
                    read = Int(SSL_read(ssl, base.advanced(by: offset), Int32(remaining)))
                } else {
                    read = Darwin.read(fd, base.advanced(by: offset), remaining)
                }
                guard read > 0 else {
                    throw PairingGeneratorError.transport("closed while reading")
                }
                offset += read
            }
        }
        return data
    }

    // MARK: - TLS

    /// Upgrades the open socket in place, presenting the host certificate the
    /// pairing record will carry. The phone's certificate is self-signed and
    /// only becomes known during the pairing itself, so verification is left to
    /// the record exchange rather than to the handshake.
    func startTLS(certificate: OpaquePointer, key: OpaquePointer) throws {
        guard fd >= 0 else { throw PairingGeneratorError.transport("socket is not open") }
        guard let method = TLS_client_method(), let context = SSL_CTX_new(method) else {
            throw PairingGeneratorError.crypto("could not create a TLS context")
        }
        defer { SSL_CTX_free(context) }
        guard SSL_CTX_use_certificate(context, certificate) == 1,
              SSL_CTX_use_PrivateKey(context, key) == 1 else {
            throw PairingGeneratorError.crypto("could not load the host certificate")
        }
        SSL_CTX_set_verify(context, 0, nil)
        guard let connection = SSL_new(context) else {
            throw PairingGeneratorError.crypto("could not start TLS")
        }
        _ = SSL_set_fd(connection, fd)
        guard SSL_connect(connection) == 1 else {
            SSL_free(connection)
            throw PairingGeneratorError.transport("the TLS handshake was refused")
        }
        ssl = connection
    }

    // MARK: - Messages

    func send(_ value: [String: Any]) throws {
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
        try write(message)
    }

    func receive() throws -> [String: Any] {
        let header = try read(exactly: 4)
        let length = UInt32(bigEndian: header.withUnsafeBytes { $0.load(as: UInt32.self) })
        guard length > 0, length < 8 * 1024 * 1024 else {
            throw PairingGeneratorError.badReply("bad message length \(length)")
        }
        let body = try read(exactly: Int(length))
        guard let plist = try? PropertyListSerialization.propertyList(from: body, format: nil),
              let dictionary = plist as? [String: Any] else {
            throw PairingGeneratorError.badReply("not a property list")
        }
        return dictionary
    }
}

/// The host certificate a pairing record needs: an RSA key and a self-signed
/// X.509 certificate around it, generated with OpenSSL and kept as DER and PEM
/// so they can be written into the record exactly as the phone stores them.
struct PairingIdentity {
    let certificate: OpaquePointer
    let key: OpaquePointer
    let certificateDER: Data
    let keyPEM: Data

    static func generate() throws -> PairingIdentity {
        guard let keyContext = EVP_PKEY_CTX_new_id(6, nil) else { // EVP_PKEY_RSA
            throw PairingGeneratorError.crypto("could not start a key")
        }
        defer { EVP_PKEY_CTX_free(keyContext) }
        guard EVP_PKEY_keygen_init(keyContext) == 1,
              EVP_PKEY_CTX_set_rsa_keygen_bits(keyContext, 2048) == 1 else {
            throw PairingGeneratorError.crypto("could not configure the key")
        }
        var generatedKey: OpaquePointer?
        guard EVP_PKEY_keygen(keyContext, &generatedKey) == 1, let key = generatedKey else {
            throw PairingGeneratorError.crypto("could not generate a key")
        }

        guard let certificate = X509_new() else {
            throw PairingGeneratorError.crypto("could not create a certificate")
        }
        X509_set_version(certificate, 2)
        ASN1_INTEGER_set(X509_get_serialNumber(certificate), 1)
        X509_gmtime_adj(X509_getm_notBefore(certificate), 0)
        X509_gmtime_adj(X509_getm_notAfter(certificate), 60 * 60 * 24 * 3650)
        X509_set_pubkey(certificate, key)

        guard let name = X509_get_subject_name(certificate) else {
            throw PairingGeneratorError.crypto("could not name the certificate")
        }
        var commonName = Array("Focus Plus".utf8)
        _ = commonName.withUnsafeBufferPointer { buffer in
            X509_NAME_add_entry_by_txt(
                name, "CN", 4097 /* MBSTRING_ASC */,
                buffer.baseAddress, Int32(commonName.count), -1, 0
            )
        }
        X509_set_issuer_name(certificate, name)
        guard X509_sign(certificate, key, EVP_sha256()) > 0 else {
            throw PairingGeneratorError.crypto("could not sign the certificate")
        }

        var pointer: UnsafeMutablePointer<UInt8>?
        let length = i2d_X509(certificate, &pointer)
        guard length > 0, let pointer else {
            throw PairingGeneratorError.crypto("could not export the certificate")
        }
        let der = Data(bytes: pointer, count: Int(length))
        CRYPTO_free(UnsafeMutableRawPointer(pointer), nil, 0)

        guard let bio = BIO_new(BIO_s_mem()) else {
            throw PairingGeneratorError.crypto("could not write the key")
        }
        defer { BIO_free(bio) }
        guard PEM_write_bio_PrivateKey(bio, key, nil, nil, 0, nil, nil) == 1 else {
            throw PairingGeneratorError.crypto("could not write the key")
        }
        var pemPointer: UnsafeMutablePointer<CChar>?
        let pemLength = withUnsafeMutablePointer(to: &pemPointer) { pointer in
            BIO_ctrl(bio, 3 /* BIO_CTRL_INFO */, 0, UnsafeMutableRawPointer(pointer))
        }
        guard pemLength > 0, let pemPointer else {
            throw PairingGeneratorError.crypto("could not write the key")
        }
        let keyPEM = Data(bytes: pemPointer, count: Int(pemLength))

        return PairingIdentity(
            certificate: certificate,
            key: key,
            certificateDER: der,
            keyPEM: keyPEM
        )
    }
}

/// Runs the whole pairing against the tunnel and hands the finished record to
/// the JIT store: who the phone is, the encrypted session, and the `Pair`
/// request that writes the record.
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

    func run() async {
        guard phase != .running else { return }
        phase = .running
        log = []
        device = nil
        wantsEncryptedSession = false

        let hostID = UUID().uuidString.uppercased()
        let systemBUID = UUID().uuidString.uppercased()
        let port = UInt16(portText.trimmingCharacters(in: .whitespaces)) ?? JITManager.tunnelPort
        let transport = PairingTransport()

        do {
            note("Connecting to \(host):\(port)")
            try transport.open(host: host, port: port)
            note("Connected")

            try transport.send(["Label": "Focus Plus", "Request": "QueryType"])
            let type = try transport.receive()
            guard let kind = type["Type"] as? String else {
                throw PairingGeneratorError.badReply("no Type in the reply")
            }
            note("Service: \(kind)")
            guard kind == "com.apple.mobile.lockdown" else {
                throw PairingGeneratorError.badReply("that is \(kind), not lockdown")
            }

            var info = LockdownDeviceInfo()
            info.name = try stringValue(transport, key: "DeviceName")
            info.model = try stringValue(transport, key: "ProductType")
            info.systemVersion = try stringValue(transport, key: "ProductVersion")
            info.build = try stringValue(transport, key: "BuildVersion")
            info.udid = try stringValue(transport, key: "UniqueDeviceID")
            device = info
            note("Device: \(info.name ?? "unknown") · \(info.model ?? "?") · iOS \(info.systemVersion ?? "?")")

            let deviceCertificate = try dataValue(transport, key: "DeviceCertificate")

            note("Creating the host certificate")
            let identity = try PairingIdentity.generate()

            try transport.send([
                "Label": "Focus Plus",
                "Request": "StartSession",
                "HostID": hostID,
                "SystemBUID": systemBUID
            ])
            let session = try transport.receive()
            if let error = session["Error"] as? String {
                throw PairingGeneratorError.refused(error)
            }
            wantsEncryptedSession = session["EnableSessionSSL"] as? Bool ?? false
            note(wantsEncryptedSession ? "Session started — starting TLS" : "Session started")

            try transport.startTLS(certificate: identity.certificate, key: identity.key)
            note("TLS established with the host certificate")

            note("Requesting the pairing record")
            try transport.send([
                "Label": "Focus Plus",
                "Request": "Pair",
                "PairRecord": [
                    "DeviceCertificate": deviceCertificate ?? Data(),
                    "HostCertificate": identity.certificateDER,
                    "HostPrivateKey": identity.keyPEM,
                    "HostID": hostID,
                    "SystemBUID": systemBUID
                ]
            ])
            let reply = try transport.receive()
            if let error = reply["Error"] as? String {
                throw PairingGeneratorError.refused(error)
            }
            note("The phone wrote the record")

            var pairingRecord: [String: Any] = [
                "DeviceCertificate": deviceCertificate ?? Data(),
                "HostCertificate": identity.certificateDER,
                "HostPrivateKey": identity.keyPEM,
                "RootCertificate": identity.certificateDER,
                "RootPrivateKey": identity.keyPEM,
                "HostID": hostID,
                "SystemBUID": systemBUID,
                "UDID": info.udid ?? ""
            ]
            if let escrow = reply["EscrowBag"] as? Data {
                pairingRecord["EscrowBag"] = escrow
            }
            if let mac = try stringValue(transport, key: "WiFiMACAddress") {
                pairingRecord["WiFiMACAddress"] = mac
            }
            if let name = info.name {
                pairingRecord["DeviceName"] = name
            }

            guard let data = try? PropertyListSerialization.data(
                fromPropertyList: pairingRecord,
                format: .xml,
                options: 0
            ) else {
                throw PairingGeneratorError.transport("could not encode the pairing file")
            }

            switch JITManager.shared.importPairingData(data) {
            case .success(let pairing):
                note("Saved: \(pairing.displayName)")
                note("Pairing file generated on this device.")
                phase = .finished
            case .failure(let error):
                throw PairingGeneratorError.crypto(error.localizedDescription)
            }
        } catch {
            let message = error.localizedDescription
            note("Failed: \(message)")
            phase = .failed(message)
        }
        transport.close()
    }

    private func stringValue(_ transport: PairingTransport, key: String) throws -> String? {
        try rawValue(transport, key: key) as? String
    }

    private func dataValue(_ transport: PairingTransport, key: String) throws -> Data? {
        try rawValue(transport, key: key) as? Data
    }

    private func rawValue(_ transport: PairingTransport, key: String) throws -> Any? {
        try transport.send(["Label": "Focus Plus", "Request": "GetValue", "Key": key])
        let reply = try transport.receive()
        if let error = reply["Error"] as? String {
            note("\(key): \(error)")
            return nil
        }
        return reply["Value"]
    }

    private func note(_ line: String) {
        log.append(line)
    }
}
