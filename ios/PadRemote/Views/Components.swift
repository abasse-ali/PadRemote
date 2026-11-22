import SwiftUI

/// Apparence d'une touche.
enum KeyLook {
    case cap(height: CGFloat = 44, fill: Color = Theme.surface2, stroke: Color = Theme.line, fg: Color = .white)
    case circle(big: Bool)
    case tile(accent: Bool)
}

struct LookModifier: ViewModifier {
    let look: KeyLook
    let pressed: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch look {
        case let .cap(height, fill, stroke, fg):
            content
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(fg)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(pressed ? Theme.surface3 : fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(stroke, lineWidth: 1)
                )
                .scaleEffect(pressed ? 0.96 : 1)
        case let .circle(big):
            content
                .foregroundStyle(.white)
                .background(
                    Circle().fill(big ? (pressed ? Theme.accent.opacity(0.75) : Theme.accent)
                                      : (pressed ? Theme.surface3 : Theme.surface2))
                )
                .overlay(Circle().stroke(big ? Color.clear : Theme.line, lineWidth: 1))
                .scaleEffect(pressed ? 0.94 : 1)
        case let .tile(accent):
            content
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accent
                              ? AnyShapeStyle(LinearGradient(colors: [Theme.accent, Theme.accent2],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(pressed ? Theme.surface3 : Theme.surface2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent ? Color.clear : Theme.line, lineWidth: 1)
                )
                .opacity(accent && pressed ? 0.8 : 1)
                .scaleEffect(pressed ? 0.97 : 1)
        }
    }
}

/// Bouton classique : action au relâchement.
struct PressStyle: ButtonStyle {
    let look: KeyLook

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(LookModifier(look: look, pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

/// Bouton à répétition : action à l'appui, puis répétée tant que le doigt reste posé.
struct RepeatStyle: ButtonStyle {
    let look: KeyLook
    let action: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        RepeatBody(configuration: configuration, look: look, action: action)
    }
}

private struct RepeatBody: View {
    let configuration: ButtonStyleConfiguration
    let look: KeyLook
    let action: () -> Void
    @State private var timer: Timer?

    var body: some View {
        configuration.label
            .modifier(LookModifier(look: look, pressed: configuration.isPressed))
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(Rectangle())
            .onChange(of: configuration.isPressed) { _, pressed in
                timer?.invalidate()
                timer = nil
                guard pressed else { return }
                Haptics.tap()
                action()
                let start = Date()
                timer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
                    if Date().timeIntervalSince(start) > 0.4 { action() }
                }
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }
}

/// Touche avec titre, icône et légende optionnels.
struct KeyButton: View {
    var title: String? = nil
    var icon: String? = nil
    var subtitle: String? = nil
    var look: KeyLook = .cap()
    var repeats = false
    var vertical = false
    let action: () -> Void

    var body: some View {
        if repeats {
            Button(action: {}) { content }
                .buttonStyle(RepeatStyle(look: look, action: action))
        } else {
            Button {
                Haptics.tap()
                action()
            } label: {
                content
            }
            .buttonStyle(PressStyle(look: look))
        }
    }

    @ViewBuilder
    private var content: some View {
        if vertical {
            VStack(spacing: 4) {
                iconView
                titleView
                subtitleView
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        } else {
            HStack(spacing: 6) {
                iconView
                titleView
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = icon {
            Image(systemName: icon)
                .font(.system(size: vertical ? 20 : 16, weight: .semibold))
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let title = title {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let subtitle = subtitle {
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Ctrl / Alt / Maj / Win : 1 toucher = une fois, 2 = verrouillé, 3 = relâché.
struct ModButton: View {
    @EnvironmentObject var client: RemoteClient
    let mod: String
    let title: String
    var height: CGFloat = 44

    var body: some View {
        let state = client.mods[mod] ?? 0
        Button {
            Haptics.tap()
            client.tapMod(mod)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if state == 2 {
                    Circle().frame(width: 5, height: 5)
                }
            }
        }
        .buttonStyle(PressStyle(look: .cap(
            height: height,
            fill: state == 0 ? Theme.surface2 : (state == 1 ? Theme.accent.opacity(0.22) : Theme.accent),
            stroke: state == 1 ? Theme.accent : Theme.line,
            fg: .white
        )))
    }
}

/// Bouton rond (médias).
struct RoundKey: View {
    let icon: String
    var big = false
    var repeats = false
    let action: () -> Void

    var body: some View {
        let size: CGFloat = big ? 82 : 64
        let label = Image(systemName: icon)
            .font(.system(size: big ? 30 : 22, weight: .semibold))
            .frame(width: size, height: size)
        if repeats {
            Button(action: {}) { label }
                .buttonStyle(RepeatStyle(look: .circle(big: big), action: action))
        } else {
            Button {
                Haptics.tap()
                action()
            } label: {
                label
            }
            .buttonStyle(PressStyle(look: .circle(big: big)))
        }
    }
}

struct SectionTitle: View {
    let title: String
    var note: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(Theme.muted)
            if let note = note {
                Text(note)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted.opacity(0.8))
            }
        }
        .padding(.top, 18)
        .padding(.bottom, 2)
        .padding(.horizontal, 4)
    }
}

extension View {
    func card(padding: CGFloat = 10) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}
