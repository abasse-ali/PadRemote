import Foundation
import Network

/// Recherche des PC qui font tourner le serveur PadRemote (Bonjour « _padremote._tcp »).
final class Discovery: ObservableObject {
    struct Found: Identifiable, Hashable {
        let id: String
        let name: String
        var host: String?
        var port: Int?
    }

    @Published private(set) var found: [Found] = []

    private var browser: NWBrowser?
    private var resolvers: [String: NWConnection] = [:]

    func start() {
        browser?.cancel()
        let params = NWParameters()
        params.includePeerToPeer = false
        let b = NWBrowser(for: .bonjour(type: "_padremote._tcp", domain: nil), using: params)
        b.browseResultsChangedHandler = { [weak self] results, _ in
            self?.update(results)
        }
        b.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.start() }
            }
        }
        b.start(queue: .main)
        browser = b
    }

    private func update(_ results: Set<NWBrowser.Result>) {
        var list: [Found] = []
        for result in results {
            guard case let .service(name, _, _, _) = result.endpoint else { continue }
            if let existing = found.first(where: { $0.id == name }), existing.host != nil {
                list.append(existing)
            } else {
                list.append(Found(id: name, name: name, host: nil, port: nil))
                resolve(name: name, endpoint: result.endpoint)
            }
        }
        found = list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Ouvre une connexion TCP éphémère vers le service pour connaître son IPv4 et son port.
    private func resolve(name: String, endpoint: NWEndpoint) {
        guard resolvers[name] == nil else { return }
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        let c = NWConnection(to: endpoint, using: params)
        resolvers[name] = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if case let .hostPort(host, port)? = c.currentPath?.remoteEndpoint,
                   case let .ipv4(address) = host {
                    let ip = address.rawValue.map { String($0) }.joined(separator: ".")
                    self.setResolved(name: name, host: ip, port: Int(port.rawValue))
                }
                c.stateUpdateHandler = nil
                c.cancel()
                self.resolvers[name] = nil
            case .failed, .waiting:
                c.stateUpdateHandler = nil
                c.cancel()
                self.resolvers[name] = nil
            default:
                break
            }
        }
        c.start(queue: .main)
    }

    private func setResolved(name: String, host: String, port: Int) {
        guard let i = found.firstIndex(where: { $0.id == name }) else { return }
        found[i].host = host
        found[i].port = port
    }
}
