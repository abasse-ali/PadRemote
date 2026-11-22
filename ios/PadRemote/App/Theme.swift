import SwiftUI
import UIKit

enum Theme {
    static let bg = Color(red: 0.039, green: 0.043, blue: 0.059)
    static let surface = Color(red: 0.082, green: 0.090, blue: 0.114)
    static let surface2 = Color(red: 0.118, green: 0.129, blue: 0.161)
    static let surface3 = Color(red: 0.165, green: 0.180, blue: 0.220)
    static let line = Color.white.opacity(0.08)
    static let muted = Color(red: 0.549, green: 0.573, blue: 0.635)
    static let accent = Color(red: 0.302, green: 0.486, blue: 1.0)
    static let accent2 = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let ok = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let warn = Color(red: 1.0, green: 0.624, blue: 0.039)
    static let bad = Color(red: 1.0, green: 0.271, blue: 0.227)
}

/// Retours haptiques (vibrations légères) — désactivables dans les réglages.
enum Haptics {
    static var enabled = true
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)

    static func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    static func click() {
        guard enabled else { return }
        rigid.impactOccurred(intensity: 0.75)
    }
}
