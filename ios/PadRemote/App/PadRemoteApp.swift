import SwiftUI

@main
struct PadRemoteApp: App {
    @StateObject private var client = RemoteClient()
    @StateObject private var settings = AppSettings()
    @StateObject private var discovery = Discovery()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(client)
                .environmentObject(settings)
                .environmentObject(discovery)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onOpenURL { url in client.handlePairURL(url) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var client: RemoteClient
    @EnvironmentObject private var discovery: Discovery
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if client.target == nil {
                ConnectView()
            } else {
                MainView()
            }
        }
        .overlay(alignment: .top) {
            if let message = client.toast {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1)))
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeOut(duration: 0.2), value: client.toast)
        .onAppear { discovery.start() }
        .onChange(of: scenePhase) { _, phase in
            client.scenePhaseChanged(phase)
            if phase == .active { discovery.start() }
        }
        .onChange(of: discovery.found) { _, found in
            for pc in found {
                if let host = pc.host, let port = pc.port {
                    client.refreshAddress(name: pc.name, host: host, port: port)
                }
            }
        }
    }
}
