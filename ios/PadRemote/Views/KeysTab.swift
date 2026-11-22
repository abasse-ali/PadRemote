import SwiftUI

struct KeyDef: Identifiable {
    let title: String
    var icon: String? = nil
    let key: String
    var mods: [String] = []
    var repeats = false

    var id: String { title + "|" + key + "|" + mods.joined(separator: "+") }
}

struct KeysTab: View {
    @EnvironmentObject private var client: RemoteClient
    @State private var compose = ""
    @FocusState private var composeFocused: Bool

    private let four = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    private let six = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private let special: [KeyDef] = [
        KeyDef(title: "Échap", key: "esc"),
        KeyDef(title: "Tab", key: "tab"),
        KeyDef(title: "Effacer", icon: "delete.left", key: "backspace", repeats: true),
        KeyDef(title: "Suppr", key: "delete", repeats: true),
        KeyDef(title: "Entrée", icon: "return", key: "enter"),
        KeyDef(title: "Espace", key: "space", repeats: true),
        KeyDef(title: "Inser", key: "insert"),
        KeyDef(title: "Impr. écran", key: "printscreen"),
        KeyDef(title: "Début", key: "home"),
        KeyDef(title: "Fin", key: "end"),
        KeyDef(title: "Page ↑", key: "pageup", repeats: true),
        KeyDef(title: "Page ↓", key: "pagedown", repeats: true),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 10) {
                    TextField("Écrivez ou dictez ici, puis envoyez au PC…", text: $compose, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($composeFocused)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                    HStack(spacing: 8) {
                        KeyButton(title: "Envoyer", look: .cap(fill: Theme.surface3)) { sendCompose("") }
                        KeyButton(title: "Envoyer + ⏎", look: .cap(fill: Theme.surface3)) { sendCompose("\n") }
                        KeyButton(title: "Saisie directe", look: .cap(fill: Theme.accent, stroke: .clear)) {
                            composeFocused = false
                            client.selectedTab = 0
                            client.liveKeyboard = true
                        }
                    }
                }
                .card()
                .padding(.top, 6)

                SectionTitle(title: "Modificateurs", note: "1 toucher = une fois · 2 = verrouillé")
                HStack(spacing: 8) {
                    ModButton(mod: "ctrl", title: "Ctrl")
                    ModButton(mod: "alt", title: "Alt")
                    ModButton(mod: "shift", title: "Maj")
                    ModButton(mod: "win", title: "Win")
                }

                SectionTitle(title: "Touches")
                LazyVGrid(columns: four, spacing: 8) {
                    ForEach(special) { k in
                        if let icon = k.icon {
                            KeyButton(icon: icon, repeats: k.repeats) { client.key(k.key) }
                                .accessibilityLabel(k.title)
                        } else {
                            KeyButton(title: k.title, repeats: k.repeats) { client.key(k.key) }
                        }
                    }
                }

                VStack(spacing: 8) {
                    KeyButton(icon: "chevron.up", look: .cap(height: 52), repeats: true) { client.key("up") }
                        .frame(width: 92)
                    HStack(spacing: 8) {
                        KeyButton(icon: "chevron.left", look: .cap(height: 52), repeats: true) { client.key("left") }
                            .frame(width: 92)
                        KeyButton(icon: "chevron.down", look: .cap(height: 52), repeats: true) { client.key("down") }
                            .frame(width: 92)
                        KeyButton(icon: "chevron.right", look: .cap(height: 52), repeats: true) { client.key("right") }
                            .frame(width: 92)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                SectionTitle(title: "Touches de fonction")
                LazyVGrid(columns: six, spacing: 8) {
                    ForEach(1...12, id: \.self) { i in
                        KeyButton(title: "F\(i)") { client.key("f\(i)") }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sendCompose(_ suffix: String) {
        guard !compose.isEmpty else {
            client.showToast("Rien à envoyer")
            return
        }
        if client.text(compose + suffix) {
            compose = ""
            client.showToast("Texte envoyé au PC")
        }
    }
}
