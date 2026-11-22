import SwiftUI

struct ConnectView: View {
    @EnvironmentObject private var client: RemoteClient
    @EnvironmentObject private var discovery: Discovery
    @State private var host = ""
    @State private var port = "8765"
    @State private var pin = ""
    @State private var pinInput = ""
    @State private var pinTarget: SavedPC?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "cursorarrow.rays")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Pavé tactile, clavier et télécommande pour votre PC.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                Section {
                    if discovery.found.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Recherche des PC sur le réseau…")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    ForEach(discovery.found) { pc in
                        Button {
                            select(pc)
                        } label: {
                            row(icon: "desktopcomputer", title: pc.name,
                                detail: pc.host.map { "\($0):\(pc.port ?? 8765)" } ?? "Recherche de l’adresse…")
                        }
                        .disabled(pc.host == nil)
                    }
                } header: {
                    Text("PC détectés")
                } footer: {
                    Text("Lancez Demarrer_PadRemote.bat sur le PC. L’iPhone et le PC doivent être sur le même réseau. Vous pouvez aussi scanner le QR code affiché sur le PC avec l’appareil photo.")
                }

                if !client.saved.isEmpty {
                    Section("Récents") {
                        ForEach(client.saved) { pc in
                            Button {
                                if pc.pin.isEmpty {
                                    client.pinRequest = pc
                                } else {
                                    client.connect(pc)
                                }
                            } label: {
                                row(icon: "clock.arrow.circlepath", title: pc.displayName, detail: "\(pc.host):\(pc.port)")
                            }
                        }
                        .onDelete { client.removeSaved(at: $0) }
                    }
                }

                Section {
                    TextField("Adresse IP du PC (ex. 192.168.1.59)", text: $host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                        .focused($focused)
                    TextField("Code PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .focused($focused)
                    Button("Se connecter") {
                        focused = false
                        let h = host.trimmingCharacters(in: .whitespaces)
                        client.connect(SavedPC(name: "", host: h, port: Int(port) ?? 8765, pin: pin))
                    }
                    .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty || pin.count < 4)
                } header: {
                    Text("Connexion manuelle")
                } footer: {
                    Text("L’adresse et le code PIN sont affichés dans la fenêtre PadRemote du PC.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("PadRemote")
            .refreshable { discovery.start() }
        }
        .onChange(of: client.pinRequest) { _, request in
            if let request = request {
                pinTarget = request
                pinInput = ""
            }
        }
        .alert("Code PIN", isPresented: Binding(
            get: { client.pinRequest != nil },
            set: { if !$0 { client.pinRequest = nil } }
        )) {
            TextField("Code PIN", text: $pinInput)
                .keyboardType(.numberPad)
            Button("Annuler", role: .cancel) {}
            Button("Se connecter") {
                if var pc = pinTarget, !pinInput.isEmpty {
                    pc.pin = pinInput
                    client.connect(pc)
                }
            }
        } message: {
            Text(client.pinError ?? "Entrez le code PIN affiché sur \(pinTarget?.displayName ?? "le PC").")
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 4)
    }

    private func select(_ pc: Discovery.Found) {
        guard let h = pc.host else { return }
        let p = pc.port ?? 8765
        if let known = client.saved.first(where: { $0.name == pc.name }), !known.pin.isEmpty {
            client.connect(SavedPC(name: pc.name, host: h, port: p, pin: known.pin))
        } else {
            client.pinRequest = SavedPC(name: pc.name, host: h, port: p, pin: "")
        }
    }
}
