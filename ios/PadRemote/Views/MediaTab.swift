import SwiftUI

struct MediaTab: View {
    @EnvironmentObject private var client: RemoteClient
    private let four = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Volume")
                HStack {
                    Spacer()
                    RoundKey(icon: "speaker.wave.1.fill", repeats: true) { client.key("volume_down") }
                    Spacer()
                    RoundKey(icon: "speaker.slash.fill") { client.key("volume_mute") }
                    Spacer()
                    RoundKey(icon: "speaker.wave.3.fill", repeats: true) { client.key("volume_up") }
                    Spacer()
                }
                .padding(.vertical, 6)
                .card(padding: 12)

                SectionTitle(title: "Lecture")
                HStack {
                    Spacer()
                    RoundKey(icon: "backward.end.fill") { client.key("media_prev") }
                    Spacer()
                    RoundKey(icon: "playpause.fill", big: true) { client.key("media_play_pause") }
                    Spacer()
                    RoundKey(icon: "forward.end.fill") { client.key("media_next") }
                    Spacer()
                    RoundKey(icon: "stop.fill") { client.key("media_stop") }
                    Spacer()
                }
                .padding(.vertical, 4)
                .card(padding: 12)

                SectionTitle(title: "Présentation")
                HStack(spacing: 8) {
                    KeyButton(title: "Précédente", icon: "chevron.left", look: .tile(accent: false), vertical: true) {
                        client.key("left")
                    }
                    KeyButton(title: "Suivante", icon: "chevron.right", look: .tile(accent: true), vertical: true) {
                        client.key("right")
                    }
                    .frame(maxWidth: .infinity)
                    .layoutPriority(1)
                }
                LazyVGrid(columns: four, spacing: 8) {
                    KeyButton(title: "Démarrer", icon: "play", look: .cap(height: 60), vertical: true) { client.key("f5") }
                    KeyButton(title: "Depuis ici", icon: "play.rectangle", look: .cap(height: 60), vertical: true) {
                        client.key("f5", mods: ["shift"])
                    }
                    KeyButton(title: "Écran noir", icon: "display", look: .cap(height: 60), vertical: true) { client.key("b") }
                    KeyButton(title: "Quitter", icon: "xmark", look: .cap(height: 60), vertical: true) { client.key("esc") }
                }

                SectionTitle(title: "Vidéo (navigateur, YouTube…)")
                LazyVGrid(columns: four, spacing: 8) {
                    KeyButton(title: "Lecture", icon: "playpause", look: .cap(height: 60), vertical: true) { client.key("space") }
                    KeyButton(title: "−5 s", icon: "gobackward.5", look: .cap(height: 60), vertical: true) { client.key("left") }
                    KeyButton(title: "+5 s", icon: "goforward.5", look: .cap(height: 60), vertical: true) { client.key("right") }
                    KeyButton(title: "Plein écran", icon: "arrow.up.left.and.arrow.down.right", look: .cap(height: 60), vertical: true) {
                        client.key("f")
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
    }
}
