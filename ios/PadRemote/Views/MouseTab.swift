import SwiftUI

struct MouseTab: View {
    @EnvironmentObject private var client: RemoteClient
    @EnvironmentObject private var settings: AppSettings
    @AppStorage("padUsed") private var padUsed = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TrackpadView(client: client, settings: settings, onFirstTouch: { padUsed = true })
                    .background(PadBackground())
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.line, lineWidth: 1))
                    .overlay(alignment: .bottomLeading) {
                        if !padUsed && !client.liveKeyboard {
                            PadHint().allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        if client.status != .online {
                            OfflineOverlay().allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            Haptics.tap()
                            client.liveKeyboard.toggle()
                        } label: {
                            Image(systemName: client.liveKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(client.liveKeyboard ? Theme.accent : Theme.surface3.opacity(0.9)))
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        }
                        .padding(10)
                    }

                if settings.strip {
                    ScrollStripView(client: client, settings: settings)
                        .frame(width: 42)
                        .background(StripBackground())
                        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 21, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
            }

            if client.liveKeyboard {
                KeyBar()
            }

            MouseButtonsView(client: client)
                .frame(height: client.liveKeyboard ? 50 : 64)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(
            KeyInputRepresentable(active: $client.liveKeyboard, client: client)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        )
        .onDisappear { client.liveKeyboard = false }
    }
}

/// Touches affichées au-dessus du clavier iOS pendant la saisie directe.
struct KeyBar: View {
    @EnvironmentObject private var client: RemoteClient

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                KeyButton(title: "Échap", look: .cap(height: 40)) { client.key("esc") }
                KeyButton(title: "Tab", look: .cap(height: 40)) { client.key("tab") }
                ModButton(mod: "ctrl", title: "Ctrl", height: 40)
                ModButton(mod: "alt", title: "Alt", height: 40)
                ModButton(mod: "shift", title: "Maj", height: 40)
                ModButton(mod: "win", title: "Win", height: 40)
                KeyButton(icon: "chevron.down", look: .cap(height: 40)) { client.liveKeyboard = false }
            }
            HStack(spacing: 6) {
                KeyButton(title: "Suppr", look: .cap(height: 40), repeats: true) { client.key("delete") }
                KeyButton(title: "Début", look: .cap(height: 40)) { client.key("home") }
                KeyButton(icon: "chevron.left", look: .cap(height: 40), repeats: true) { client.key("left") }
                KeyButton(icon: "chevron.up", look: .cap(height: 40), repeats: true) { client.key("up") }
                KeyButton(icon: "chevron.down", look: .cap(height: 40), repeats: true) { client.key("down") }
                KeyButton(icon: "chevron.right", look: .cap(height: 40), repeats: true) { client.key("right") }
                KeyButton(title: "Fin", look: .cap(height: 40)) { client.key("end") }
            }
        }
    }
}

struct PadHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            hint("1 doigt", "déplacer · toucher = clic")
            hint("2 doigts", "défiler · toucher = clic droit · pincer = zoom")
            hint("3 doigts", "toucher = clic milieu · glisser = fenêtres")
            hint("Toucher 2×", "puis glisser = sélectionner")
        }
        .font(.system(size: 12.5))
        .padding(18)
    }

    private func hint(_ bold: String, _ rest: String) -> some View {
        (Text(bold).fontWeight(.semibold).foregroundColor(.white.opacity(0.55))
            + Text(" " + rest).foregroundColor(.white.opacity(0.36)))
    }
}

struct OfflineOverlay: View {
    @EnvironmentObject private var client: RemoteClient

    var body: some View {
        ZStack {
            Theme.bg.opacity(0.55)
            VStack(spacing: 6) {
                ProgressView()
                Text(client.status == .offline ? "Hors ligne" : "Connexion…")
                    .font(.headline)
                Text("Vérifiez que PadRemote tourne sur le PC.")
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct PadBackground: View {
    var body: some View {
        ZStack {
            Theme.surface
            RadialGradient(colors: [Theme.accent.opacity(0.14), .clear],
                           center: UnitPoint(x: 0.3, y: 0), startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Theme.accent2.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 380)
            Canvas { context, size in
                let step: CGFloat = 22
                var y: CGFloat = 10
                while y < size.height {
                    var x: CGFloat = 10
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                     with: .color(.white.opacity(0.07)))
                        x += step
                    }
                    y += step
                }
            }
        }
    }
}

struct StripBackground: View {
    var body: some View {
        ZStack {
            Theme.surface
            Canvas { context, size in
                var y: CGFloat = 10
                while y < size.height - 8 {
                    let rect = CGRect(x: size.width / 2 - 7, y: y, width: 14, height: 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.white.opacity(0.10)))
                    y += 11
                }
            }
        }
    }
}
