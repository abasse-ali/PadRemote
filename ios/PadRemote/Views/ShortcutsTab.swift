import SwiftUI

struct ShortcutSection: Identifiable {
    let title: String
    let items: [KeyDef]
    var id: String { title }
}

struct PowerAction: Identifiable {
    let title: String
    let icon: String
    let action: String
    let confirm: Bool
    var id: String { action }
}

private let keyNames: [String: String] = [
    "ctrl": "Ctrl", "alt": "Alt", "shift": "Maj", "win": "Win", "tab": "Tab", "esc": "Échap",
    "left": "←", "right": "→", "up": "↑", "down": "↓", "add": "+", "subtract": "−", "num0": "0",
]

func comboText(_ key: String, _ mods: [String]) -> String {
    (mods + [key]).map { keyNames[$0] ?? $0.uppercased() }.joined(separator: " + ")
}

struct ShortcutsTab: View {
    @EnvironmentObject private var client: RemoteClient
    @State private var url = ""
    @State private var pendingPower: PowerAction?
    @FocusState private var urlFocused: Bool

    private let three = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private let sections: [ShortcutSection] = [
        ShortcutSection(title: "Édition", items: [
            KeyDef(title: "Copier", key: "c", mods: ["ctrl"]),
            KeyDef(title: "Coller", key: "v", mods: ["ctrl"]),
            KeyDef(title: "Couper", key: "x", mods: ["ctrl"]),
            KeyDef(title: "Annuler", key: "z", mods: ["ctrl"]),
            KeyDef(title: "Rétablir", key: "y", mods: ["ctrl"]),
            KeyDef(title: "Tout sélect.", key: "a", mods: ["ctrl"]),
            KeyDef(title: "Enregistrer", key: "s", mods: ["ctrl"]),
            KeyDef(title: "Rechercher", key: "f", mods: ["ctrl"]),
            KeyDef(title: "Imprimer", key: "p", mods: ["ctrl"]),
        ]),
        ShortcutSection(title: "Windows", items: [
            KeyDef(title: "Bureau", key: "d", mods: ["win"]),
            KeyDef(title: "App précédente", key: "tab", mods: ["alt"]),
            KeyDef(title: "Vue des tâches", key: "tab", mods: ["win"]),
            KeyDef(title: "Démarrer", key: "win"),
            KeyDef(title: "Recherche", key: "s", mods: ["win"]),
            KeyDef(title: "Explorateur", key: "e", mods: ["win"]),
            KeyDef(title: "Fermer fenêtre", key: "f4", mods: ["alt"]),
            KeyDef(title: "Gest. des tâches", key: "esc", mods: ["ctrl", "shift"]),
            KeyDef(title: "Capture", key: "s", mods: ["win", "shift"]),
            KeyDef(title: "Agrandir", key: "up", mods: ["win"]),
            KeyDef(title: "Réduire", key: "down", mods: ["win"]),
            KeyDef(title: "Paramètres", key: "i", mods: ["win"]),
            KeyDef(title: "Ancrer à gauche", key: "left", mods: ["win"]),
            KeyDef(title: "Ancrer à droite", key: "right", mods: ["win"]),
            KeyDef(title: "Presse-papiers", key: "v", mods: ["win"]),
            KeyDef(title: "Bureau virtuel ←", key: "left", mods: ["ctrl", "win"]),
            KeyDef(title: "Bureau virtuel →", key: "right", mods: ["ctrl", "win"]),
            KeyDef(title: "Projeter", key: "p", mods: ["win"]),
        ]),
        ShortcutSection(title: "Navigateur", items: [
            KeyDef(title: "Précédent", key: "left", mods: ["alt"]),
            KeyDef(title: "Suivant", key: "right", mods: ["alt"]),
            KeyDef(title: "Actualiser", key: "f5"),
            KeyDef(title: "Nouvel onglet", key: "t", mods: ["ctrl"]),
            KeyDef(title: "Fermer onglet", key: "w", mods: ["ctrl"]),
            KeyDef(title: "Rouvrir onglet", key: "t", mods: ["ctrl", "shift"]),
            KeyDef(title: "Onglet suivant", key: "tab", mods: ["ctrl"]),
            KeyDef(title: "Onglet précédent", key: "tab", mods: ["ctrl", "shift"]),
            KeyDef(title: "Barre d’adresse", key: "l", mods: ["ctrl"]),
            KeyDef(title: "Zoom +", key: "add", mods: ["ctrl"]),
            KeyDef(title: "Zoom −", key: "subtract", mods: ["ctrl"]),
            KeyDef(title: "Zoom 100 %", key: "num0", mods: ["ctrl"]),
            KeyDef(title: "Plein écran", key: "f11"),
            KeyDef(title: "Nouvelle fenêtre", key: "n", mods: ["ctrl"]),
            KeyDef(title: "Historique", key: "h", mods: ["ctrl"]),
        ]),
    ]

    private let powerActions: [PowerAction] = [
        PowerAction(title: "Verrouiller", icon: "lock.fill", action: "lock", confirm: false),
        PowerAction(title: "Éteindre l’écran", icon: "display", action: "display_off", confirm: false),
        PowerAction(title: "Veille", icon: "moon.fill", action: "sleep", confirm: true),
        PowerAction(title: "Déconnexion", icon: "rectangle.portrait.and.arrow.right", action: "logoff", confirm: true),
        PowerAction(title: "Redémarrer", icon: "arrow.clockwise", action: "restart", confirm: true),
        PowerAction(title: "Arrêter", icon: "power", action: "shutdown", confirm: true),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(sections) { section in
                    SectionTitle(title: section.title)
                    LazyVGrid(columns: three, spacing: 8) {
                        ForEach(section.items) { item in
                            KeyButton(title: item.title, subtitle: comboText(item.key, item.mods),
                                      look: .cap(height: 58), vertical: true) {
                                client.key(item.key, mods: item.mods)
                            }
                        }
                    }
                }

                SectionTitle(title: "Ouvrir une page sur le PC")
                HStack(spacing: 8) {
                    TextField("youtube.com", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($urlFocused)
                        .submitLabel(.go)
                        .onSubmit(openURL)
                        .padding(.horizontal, 8)
                    Button("Ouvrir", action: openURL)
                        .buttonStyle(PressStyle(look: .cap(height: 40, fill: Theme.accent, stroke: .clear)))
                        .frame(width: 90)
                }
                .card(padding: 6)

                SectionTitle(title: "Alimentation")
                LazyVGrid(columns: three, spacing: 8) {
                    ForEach(powerActions) { p in
                        KeyButton(title: p.title, icon: p.icon,
                                  look: .cap(height: 64, fg: p.action == "shutdown" || p.action == "restart" ? Theme.bad : .white),
                                  vertical: true) {
                            if p.confirm {
                                pendingPower = p
                            } else {
                                client.power(p.action)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .confirmationDialog(
            pendingPower.map { "\($0.title) le PC ?" } ?? "",
            isPresented: Binding(get: { pendingPower != nil }, set: { if !$0 { pendingPower = nil } }),
            titleVisibility: .visible
        ) {
            if let p = pendingPower {
                Button(p.title, role: .destructive) { client.power(p.action) }
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func openURL() {
        var u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u.isEmpty else { return }
        if !u.lowercased().hasPrefix("http://") && !u.lowercased().hasPrefix("https://") {
            u = "https://" + u
        }
        if client.openURL(u) {
            url = ""
            urlFocused = false
        }
    }
}
