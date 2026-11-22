import SwiftUI

struct MainView: View {
    @EnvironmentObject private var client: RemoteClient

    var body: some View {
        VStack(spacing: 0) {
            StatusHeader()
            TabView(selection: $client.selectedTab) {
                MouseTab()
                    .tabItem { Label("Souris", systemImage: "computermouse") }
                    .tag(0)
                KeysTab()
                    .tabItem { Label("Clavier", systemImage: "keyboard") }
                    .tag(1)
                MediaTab()
                    .tabItem { Label("Médias", systemImage: "play.circle") }
                    .tag(2)
                ShortcutsTab()
                    .tabItem { Label("Raccourcis", systemImage: "bolt") }
                    .tag(3)
                SettingsTab()
                    .tabItem { Label("Réglages", systemImage: "slider.horizontal.3") }
                    .tag(4)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }
}

struct StatusHeader: View {
    @EnvironmentObject private var client: RemoteClient

    private var color: Color {
        switch client.status {
        case .online: return Theme.ok
        case .offline: return Theme.bad
        default: return Theme.warn
        }
    }

    private var title: String {
        switch client.status {
        case .online: return client.serverName.isEmpty ? "Connecté" : client.serverName
        case .offline: return "Hors ligne · reconnexion…"
        default: return "Connexion à \(client.target?.displayName ?? "PC")…"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .background(Circle().fill(color.opacity(0.22)).frame(width: 17, height: 17))
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if client.status == .online, let ms = client.latency {
                Text("\(ms) ms")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.muted)
            }
            Menu {
                Button {
                    client.disconnect()
                } label: {
                    Label("Changer de PC", systemImage: "arrow.left.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.muted)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }
}
