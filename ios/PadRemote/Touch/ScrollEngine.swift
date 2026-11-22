import UIKit

/// Convertit les glissements de doigts en molette (défilement fluide ou par crans, avec inertie).
final class ScrollEngine: NSObject {
    weak var client: RemoteClient?
    var settings: AppSettings?

    private var pendV = 0.0
    private var pendH = 0.0
    private var velV = 0.0
    private var velH = 0.0
    private var velT: CFTimeInterval = 0
    private var inertV = 0.0
    private var inertH = 0.0
    private var lastStep: CFTimeInterval = 0
    private var link: CADisplayLink?

    /// Début d'un geste : coupe l'inertie en cours.
    func begin() {
        stopInertia()
        velV = 0
        velH = 0
        velT = 0
    }

    func scroll(dx: Double, dy: Double) {
        guard let s = settings else { return }
        let k = 2.2 * s.scrollSpeed * (s.natural ? 1 : -1)
        let v = dy * k
        let h = -dx * k
        pendV += v
        pendH += h
        let now = CACurrentMediaTime()
        let dt = max(0.008, now - velT)
        let a = dt > 0.08 ? 1.0 : 0.35
        velV = velV * (1 - a) + (v / dt) * a
        velH = velH * (1 - a) + (h / dt) * a
        velT = now
        flush()
    }

    /// Fin du geste : lance l'inertie si le doigt allait vite.
    func end() {
        guard settings?.inertia == true, CACurrentMediaTime() - velT < 0.06, hypot(velV, velH) > 250 else { return }
        inertV = velV
        inertH = velH
        lastStep = CACurrentMediaTime()
        link?.invalidate()
        let l = CADisplayLink(target: self, selector: #selector(step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    func stopInertia() {
        link?.invalidate()
        link = nil
        inertV = 0
        inertH = 0
    }

    @objc private func step(_ l: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(0.05, now - lastStep)
        lastStep = now
        pendV += inertV * dt
        pendH += inertH * dt
        let decay = pow(0.935, dt / 0.0167)
        inertV *= decay
        inertH *= decay
        flush()
        if abs(inertV) < 40 && abs(inertH) < 40 { stopInertia() }
    }

    private func flush() {
        guard let s = settings else { return }
        var v = 0
        var h = 0
        if s.smooth {
            if abs(pendV) >= 4 { v = Int(pendV.rounded()); pendV -= Double(v) }
            if abs(pendH) >= 4 { h = Int(pendH.rounded()); pendH -= Double(h) }
        } else {
            v = Int(pendV / 120) * 120
            pendV -= Double(v)
            h = Int(pendH / 120) * 120
            pendH -= Double(h)
        }
        if v != 0 || h != 0 { client?.scroll(v: v, h: h) }
    }
}
