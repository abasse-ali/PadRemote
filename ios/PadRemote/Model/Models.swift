import Foundation

/// Un PC connu (adresse + code PIN), mémorisé sur l'iPhone.
struct SavedPC: Codable, Equatable, Identifiable {
    var name: String
    var host: String
    var port: Int
    var pin: String

    var id: String { name.isEmpty ? "\(host):\(port)" : name }
    var displayName: String { name.isEmpty ? host : name }
}

enum PCStore {
    private static let listKey = "savedPCs"
    private static let lastKey = "lastPC"

    static func load() -> [SavedPC] {
        guard let data = UserDefaults.standard.data(forKey: listKey),
              let list = try? JSONDecoder().decode([SavedPC].self, from: data) else { return [] }
        return list
    }

    static func save(_ list: [SavedPC]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    static var lastID: String? {
        get { UserDefaults.standard.string(forKey: lastKey) }
        set { UserDefaults.standard.set(newValue, forKey: lastKey) }
    }
}

/// Réglages de l'app, enregistrés automatiquement.
final class AppSettings: ObservableObject {
    private static let store = UserDefaults.standard

    @Published var sens: Double { didSet { Self.store.set(sens, forKey: "sens") } }
    @Published var accel: Double { didSet { Self.store.set(accel, forKey: "accel") } }
    @Published var tapToClick: Bool { didSet { Self.store.set(tapToClick, forKey: "tap") } }
    @Published var longPressDrag: Bool { didSet { Self.store.set(longPressDrag, forKey: "longpress") } }
    @Published var scrollSpeed: Double { didSet { Self.store.set(scrollSpeed, forKey: "scroll") } }
    @Published var natural: Bool { didSet { Self.store.set(natural, forKey: "natural") } }
    @Published var smooth: Bool { didSet { Self.store.set(smooth, forKey: "smooth") } }
    @Published var inertia: Bool { didSet { Self.store.set(inertia, forKey: "inertia") } }
    @Published var strip: Bool { didSet { Self.store.set(strip, forKey: "strip") } }
    @Published var haptics: Bool {
        didSet {
            Self.store.set(haptics, forKey: "haptic")
            Haptics.enabled = haptics
        }
    }

    init() {
        let d = Self.store
        d.register(defaults: [
            "sens": 1.5, "accel": 0.6, "tap": true, "longpress": false, "scroll": 1.0,
            "natural": true, "smooth": true, "inertia": true, "strip": true, "haptic": true,
        ])
        sens = d.double(forKey: "sens")
        accel = d.double(forKey: "accel")
        tapToClick = d.bool(forKey: "tap")
        longPressDrag = d.bool(forKey: "longpress")
        scrollSpeed = d.double(forKey: "scroll")
        natural = d.bool(forKey: "natural")
        smooth = d.bool(forKey: "smooth")
        inertia = d.bool(forKey: "inertia")
        strip = d.bool(forKey: "strip")
        haptics = d.bool(forKey: "haptic")
        Haptics.enabled = haptics
    }
}
