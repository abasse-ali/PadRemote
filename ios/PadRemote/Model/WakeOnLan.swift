import Darwin
import Foundation

/// Réveil à distance du PC (Wake-on-LAN) : « paquet magique » UDP adressé à sa carte réseau.
///
/// Envoyé en diffusion (255.255.255.255 et x.x.x.255) et directement à la dernière adresse IP connue.
/// Note : iOS réserve la diffusion aux apps qui ont l'autorisation « multicast » d'Apple ;
/// sans elle, seul l'envoi direct passe (il fonctionne tant que l'iPhone connaît encore la carte du PC,
/// par exemple quand le PC est en veille).
enum WakeOnLan {
    static func packet(for mac: String) -> [UInt8]? {
        let hex = mac.filter { $0.isHexDigit }
        guard hex.count == 12 else { return nil }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        var out = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { out.append(contentsOf: bytes) }
        return out
    }

    static func targets(for host: String?) -> [String] {
        var list = ["255.255.255.255"]
        if let host = host {
            let parts = host.split(separator: ".")
            if parts.count == 4, parts.allSatisfy({ UInt8($0) != nil }) {
                list.append(parts[0..<3].joined(separator: ".") + ".255")
                list.append(host)
            }
        }
        return list
    }

    /// Envoie les paquets ; renvoie le nombre d'envois acceptés par le système.
    @discardableResult
    static func send(macs: [String], host: String?) -> Int {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return 0 }
        defer { close(fd) }
        var yes: Int32 = 1
        _ = setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var accepted = 0
        for mac in macs {
            guard let pkt = packet(for: mac) else { continue }
            for target in targets(for: host) {
                for port: UInt16 in [9, 7] {
                    var addr = sockaddr_in()
                    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                    addr.sin_family = sa_family_t(AF_INET)
                    addr.sin_port = port.bigEndian
                    guard inet_pton(AF_INET, target, &addr.sin_addr) == 1 else { continue }
                    let sent = pkt.withUnsafeBytes { raw -> Int in
                        withUnsafePointer(to: &addr) { ptr in
                            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                                sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                            }
                        }
                    }
                    if sent == pkt.count { accepted += 1 }
                }
            }
        }
        return accepted
    }
}
