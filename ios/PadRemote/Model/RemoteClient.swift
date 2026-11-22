import Foundation
import Network
import SwiftUI

/// Connexion WebSocket au serveur PadRemote du PC + toutes les commandes envoyées.
/// Toutes les méthodes s'exécutent sur le fil principal (la connexion utilise la file `.main`).
final class RemoteClient: ObservableObject {
    enum Status { case idle, connecting, online, offline }

    @Published private(set) var status: Status = .idle
    @Published private(set) var target: SavedPC?
    @Published private(set) var serverName = ""
    @Published private(set) var latency: Int?
    @Published private(set) var powerAllowed = true
    @Published private(set) var saved: [SavedPC] = PCStore.load()
    @Published private(set) var mods: [String: Int] = ["ctrl": 0, "alt": 0, "shift": 0, "win": 0]
    @Published var pinRequest: SavedPC?
    @Published var pinError: String?
    @Published var toast: String?
    @Published var liveKeyboard = false
    @Published var selectedTab = 0

    private var conn: NWConnection?
    private var generation = 0
    private var authed = false
    private var retry = 0
    private var retryItem: DispatchWorkItem?
    private var pingTimer: Timer?
    private var lastPong = Date()
    private var lastOfflineToast = Date.distantPast
    private var toastItem: DispatchWorkItem?

    init() {
        if let id = PCStore.lastID, let pc = saved.first(where: { $0.id == id }), !pc.pin.isEmpty {
            target = pc
            open()
        }
    }

    // MARK: - Connexion

    func connect(_ pc: SavedPC) {
        pinError = nil
        pinRequest = nil
        target = pc
        retry = 0
        open()
    }

    func disconnect() {
        PCStore.lastID = nil
        close()
        target = nil
        status = .idle
    }

    func forgetPin() {
        guard let t = target else { return }
        saved.removeAll { $0.id == t.id }
        PCStore.save(saved)
        disconnect()
    }

    func removeSaved(at offsets: IndexSet) {
        saved.remove(atOffsets: offsets)
        PCStore.save(saved)
    }

    /// Le PC a peut-être changé d'adresse IP : on suit ce que Bonjour annonce.
    func refreshAddress(name: String, host: String, port: Int) {
        if var t = target, t.name == name, t.host != host || t.port != port {
            t.host = host
            t.port = port
            target = t
            store(t)
            if status != .online {
                retry = 0
                open()
            }
        }
        if let i = saved.firstIndex(where: { $0.name == name }), saved[i].host != host || saved[i].port != port {
            saved[i].host = host
            saved[i].port = port
            PCStore.save(saved)
        }
    }

    /// QR code de la page d'appairage : padremote://IP:PORT?pin=123456&name=PC
    func handlePairURL(_ url: URL) {
        guard url.scheme?.lowercased() == "padremote",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host, !host.isEmpty else { return }
        var query: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            if let value = item.value { query[item.name] = value }
        }
        let pc = SavedPC(name: query["name"] ?? "", host: host, port: comps.port ?? 8765, pin: query["pin"] ?? "")
        if pc.pin.isEmpty {
            pinRequest = pc
        } else {
            connect(pc)
        }
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if target != nil && status != .online {
                retry = 0
                open()
            } else {
                ping()
            }
        case .background:
            releaseMods()
        default:
            break
        }
    }

    private func store(_ pc: SavedPC) {
        var pc = pc
        if pc.macs == nil {
            pc.macs = saved.first(where: { $0.id == pc.id || ($0.host == pc.host && $0.port == pc.port) })?.macs
        }
        saved.removeAll { $0.id == pc.id || ($0.host == pc.host && $0.port == pc.port) }
        saved.insert(pc, at: 0)
        PCStore.save(saved)
        PCStore.lastID = pc.id
    }

    private func close() {
        generation += 1
        authed = false
        pingTimer?.invalidate()
        pingTimer = nil
        retryItem?.cancel()
        retryItem = nil
        conn?.cancel()
        conn = nil
        latency = nil
        mods = mods.mapValues { _ in 0 }
    }

    private func open() {
        guard let pc = target else { return }
        close()
        let gen = generation
        status = .connecting
        let hostPart = pc.host.contains(":") ? "[\(pc.host)]" : pc.host
        guard let url = URL(string: "ws://\(hostPart):\(pc.port)/ws") else {
            status = .offline
            return
        }
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.connectionTimeout = 6
        let params = NWParameters(tls: nil, tcp: tcp)
        let ws = NWProtocolWebSocket.Options()
        ws.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(ws, at: 0)

        let c = NWConnection(to: .url(url), using: params)
        conn = c
        c.stateUpdateHandler = { [weak self] state in
            guard let self = self, gen == self.generation else { return }
            switch state {
            case .ready:
                self.sendRaw(["t": "auth", "pin": pc.pin])
            case .waiting, .failed:
                self.connectionLost(gen)
            default:
                break
            }
        }
        receive(on: c, gen: gen)
        c.start(queue: .main)
    }

    private func receive(on c: NWConnection, gen: Int) {
        c.receiveMessage { [weak self] data, context, _, error in
            guard let self = self, gen == self.generation else { return }
            if error != nil {
                self.connectionLost(gen)
                return
            }
            if let meta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               meta.opcode == .close {
                self.connectionLost(gen)
                return
            }
            if let data = data, !data.isEmpty,
               let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
                self.handle(obj)
            }
            if gen == self.generation {
                self.receive(on: c, gen: gen)
            }
        }
    }

    private func connectionLost(_ gen: Int) {
        guard gen == generation else { return }
        close()
        status = .offline
        scheduleRetry()
    }

    private func scheduleRetry() {
        guard target != nil else { return }
        retryItem?.cancel()
        let delay = min(5.0, 0.4 * pow(2.0, Double(retry)))
        retry += 1
        let item = DispatchWorkItem { [weak self] in self?.open() }
        retryItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func handle(_ m: [String: Any]) {
        switch m["t"] as? String {
        case "ok":
            authed = true
            retry = 0
            status = .online
            serverName = (m["name"] as? String) ?? "PC"
            powerAllowed = (m["power"] as? Bool) ?? true
            if var t = target {
                t.name = serverName
                if let macs = m["macs"] as? [String], !macs.isEmpty {
                    t.macs = macs
                }
                target = t
                store(t)
            }
            lastPong = Date()
            pingTimer?.invalidate()
            pingTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
                self?.ping()
            }
            ping()
        case "err":
            let blocked = (m["e"] as? String) == "blocked"
            var pc = target
            pc?.pin = ""
            close()
            target = nil
            status = .idle
            PCStore.lastID = nil
            pinError = blocked ? "Trop d’essais. Réessayez dans une minute." : "Code PIN incorrect."
            pinRequest = pc
        case "p":
            lastPong = Date()
            if let sent = (m["i"] as? NSNumber)?.doubleValue {
                latency = max(1, Int((ProcessInfo.processInfo.systemUptime - sent) * 1000))
            }
        case "info":
            if let text = m["m"] as? String { showToast(text) }
        default:
            break
        }
    }

    private func ping() {
        guard authed else { return }
        if Date().timeIntervalSince(lastPong) > 8 {
            retry = 0
            connectionLost(generation)
            return
        }
        sendRaw(["t": "p", "i": ProcessInfo.processInfo.systemUptime])
    }

    // MARK: - Envoi

    @discardableResult
    func send(_ obj: [String: Any]) -> Bool {
        guard authed, conn != nil else {
            if Date().timeIntervalSince(lastOfflineToast) > 2.5 {
                lastOfflineToast = Date()
                showToast("Non connecté au PC")
            }
            return false
        }
        sendRaw(obj)
        return true
    }

    private func sendRaw(_ obj: [String: Any]) {
        guard let c = conn, JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj) else { return }
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "msg", metadata: [meta])
        c.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    func showToast(_ text: String) {
        toast = text
        toastItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: item)
    }

    // MARK: - Commandes

    func move(_ dx: Double, _ dy: Double) {
        guard dx.isFinite, dy.isFinite else { return }
        let x = (dx * 100).rounded() / 100
        let y = (dy * 100).rounded() / 100
        if x != 0 || y != 0 { send(["t": "m", "x": x, "y": y]) }
    }

    func scroll(v: Int, h: Int) {
        if v != 0 || h != 0 { send(["t": "s", "v": v, "h": h]) }
    }

    func click(_ button: String) {
        send(["t": "c", "b": button])
        afterAction()
    }

    func buttonDown(_ button: String) {
        send(["t": "bd", "b": button])
    }

    func buttonUp(_ button: String) {
        send(["t": "bu", "b": button])
        afterAction()
    }

    func zoom(_ steps: Int) {
        if steps != 0 { send(["t": "z", "n": steps]) }
    }

    func key(_ k: String, mods extra: [String] = [], count: Int = 1) {
        var obj: [String: Any] = ["t": "k", "k": k, "mods": extra]
        if count > 1 { obj["n"] = count }
        send(obj)
        afterAction()
    }

    @discardableResult
    func text(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        let ok = send(["t": "txt", "s": s])
        afterAction()
        return ok
    }

    /// Caractère tapé sur le clavier iOS en saisie directe.
    func typed(_ s: String) {
        if s == "\n" {
            key("enter")
        } else if cmdModActive && s.count == 1 {
            key(s.lowercased()) // ex. Ctrl + C
        } else {
            text(s)
        }
    }

    func power(_ action: String) {
        send(["t": "pw", "a": action])
    }

    // MARK: - Allumer le PC (Wake-on-LAN)

    func wakeMacs(for pc: SavedPC?) -> [String] {
        guard let pc = pc else { return [] }
        if let macs = pc.macs, !macs.isEmpty { return macs }
        let known = saved.first { $0.id == pc.id || ($0.host == pc.host && $0.port == pc.port) }
        return known?.macs ?? []
    }

    var canWake: Bool { !wakeMacs(for: target).isEmpty }

    /// Envoie le signal de réveil, puis se (re)connecte : l'app attend que le PC ait démarré.
    func wake(_ pc: SavedPC? = nil) {
        guard let pc = pc ?? target else { return }
        let macs = wakeMacs(for: pc)
        guard !macs.isEmpty else {
            showToast("Connectez-vous une fois au PC allumé pour activer « Allumer le PC ».")
            return
        }
        let host = pc.host
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<3 {
                WakeOnLan.send(macs: macs, host: host)
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        Haptics.click()
        showToast("Signal de réveil envoyé à \(pc.displayName)")
        if target == nil, !pc.pin.isEmpty {
            connect(pc)
        } else if status != .online {
            retry = 0
            open()
        }
    }

    @discardableResult
    func openURL(_ url: String) -> Bool {
        send(["t": "url", "u": url])
    }

    // MARK: - Modificateurs (0 = relâché, 1 = une fois, 2 = verrouillé)

    var cmdModActive: Bool {
        (mods["ctrl"] ?? 0) > 0 || (mods["alt"] ?? 0) > 0 || (mods["win"] ?? 0) > 0
    }

    func tapMod(_ m: String) {
        switch mods[m] ?? 0 {
        case 0:
            if send(["t": "kd", "k": m]) { mods[m] = 1 }
        case 1:
            mods[m] = 2
        default:
            mods[m] = 0
            send(["t": "ku", "k": m])
        }
    }

    /// Relâche les modificateurs « une fois » après une touche ou un clic.
    func afterAction() {
        for (m, state) in mods where state == 1 {
            mods[m] = 0
            send(["t": "ku", "k": m])
        }
    }

    private func releaseMods() {
        if authed {
            for (m, state) in mods where state > 0 {
                sendRaw(["t": "ku", "k": m])
            }
        }
        mods = mods.mapValues { _ in 0 }
    }
}
