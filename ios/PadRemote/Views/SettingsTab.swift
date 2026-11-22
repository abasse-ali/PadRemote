import SwiftUI

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
        .padding(.vertical, 2)
    }
}

struct SettingsTab: View {
    @EnvironmentObject private var client: RemoteClient
    @EnvironmentObject private var settings: AppSettings
    @State private var confirmForget = false

    var body: some View {
        Form {
            Section("Connexion") {
                LabeledContent("PC", value: client.serverName.isEmpty ? "—" : client.serverName)
                LabeledContent("Adresse", value: client.target.map { "\($0.host):\($0.port)" } ?? "—")
                LabeledContent("Latence", value: client.latency.map { "\($0) ms" } ?? "—")
                Button("Changer de PC") { client.disconnect() }
                Button("Oublier le code PIN", role: .destructive) { confirmForget = true }
            }

            Section("Pavé tactile") {
                SliderRow(title: "Vitesse du curseur", value: $settings.sens, range: 0.4...4, step: 0.1) {
                    String(format: "%.1f×", $0)
                }
                SliderRow(title: "Accélération", value: $settings.accel, range: 0...1.5, step: 0.05) {
                    "\(Int(($0 * 100).rounded())) %"
                }
                Toggle("Toucher pour cliquer", isOn: $settings.tapToClick)
                Toggle("Appui long pour glisser", isOn: $settings.longPressDrag)
            }

            Section("Défilement") {
                SliderRow(title: "Vitesse de défilement", value: $settings.scrollSpeed, range: 0.3...3, step: 0.1) {
                    String(format: "%.1f×", $0)
                }
                Toggle("Défilement naturel (comme l’iPhone)", isOn: $settings.natural)
                Toggle("Défilement fluide (sinon par crans)", isOn: $settings.smooth)
                Toggle("Inertie après le geste", isOn: $settings.inertia)
                Toggle("Molette sur le bord droit", isOn: $settings.strip)
            }

            Section("Général") {
                Toggle("Retour haptique", isOn: $settings.haptics)
            }

            Section("Gestes") {
                VStack(alignment: .leading, spacing: 6) {
                    helpLine("1 doigt", "déplacer · toucher = clic · 2 touchers = double-clic")
                    helpLine("Toucher puis glisser", "sélectionner, glisser-déposer")
                    helpLine("2 doigts", "défiler · toucher = clic droit · pincer = zoom")
                    helpLine("3 doigts", "toucher = clic milieu · ↑ vue des tâches · ↓ bureau · ←/→ app précédente")
                    helpLine("Bouton Gauche maintenu", "+ un doigt sur le pavé = glisser-déposer")
                    helpLine("Modificateurs", "1 toucher = pour la prochaine touche ou le prochain clic, 2 = verrouillé")
                }
                .font(.footnote)
                .padding(.vertical, 4)
            }

            Section {
                EmptyView()
            } footer: {
                Text("PadRemote 1.0 · le serveur doit tourner sur le PC (Demarrer_PadRemote.bat).")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .scrollContentBackground(.hidden)
        .confirmationDialog("Oublier le code PIN de ce PC ?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Oublier", role: .destructive) { client.forgetPin() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func helpLine(_ bold: String, _ rest: String) -> some View {
        (Text(bold).fontWeight(.semibold) + Text(" : " + rest).foregroundColor(Theme.muted))
    }
}
