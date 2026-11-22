import SwiftUI
import UIKit

/// Pavé tactile multi-touch.
/// 1 doigt : déplacer · toucher : clic · toucher puis glisser : glisser-déposer
/// 2 doigts : défiler · toucher : clic droit · pincer : zoom
/// 3 doigts : toucher : clic milieu · glisser ↑ ↓ ← → : vue des tâches / bureau / app précédente
final class TrackpadUIView: UIView {
    weak var client: RemoteClient? { didSet { scroller.client = client } }
    var settings: AppSettings? { didSet { scroller.settings = settings } }
    var onFirstTouch: (() -> Void)?

    private struct Finger {
        var p: CGPoint
        var t: TimeInterval
    }

    private enum Mode { case none, scroll, pinch }

    private let scroller = ScrollEngine()
    private var fingers: [ObjectIdentifier: Finger] = [:]
    private var maxFingers = 0
    private var t0: CFTimeInterval = 0
    private var moved = false
    private var travel: CGFloat = 0
    private var mode: Mode = .none
    private var dragging = false
    private var longPressDragging = false
    private var candidate = false
    private var lastTap: CFTimeInterval = 0
    private var center0 = CGPoint.zero
    private var spread0: CGFloat = 0
    private var acc: CGFloat = 0
    private var accSpread: CGFloat = 0
    private var swipe = CGPoint.zero
    private var swipeFired = false
    private var zoomAcc: CGFloat = 0
    private var longPress: DispatchWorkItem?
    private var dots: [CAShapeLayer] = []
    private var touchedOnce = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) non pris en charge")
    }

    // MARK: - Géométrie

    private func centroid() -> CGPoint {
        guard !fingers.isEmpty else { return .zero }
        var x: CGFloat = 0
        var y: CGFloat = 0
        for f in fingers.values {
            x += f.p.x
            y += f.p.y
        }
        let n = CGFloat(fingers.count)
        return CGPoint(x: x / n, y: y / n)
    }

    private func spread() -> CGFloat {
        let list = Array(fingers.values)
        guard list.count >= 2 else { return 0 }
        return hypot(list[0].p.x - list[1].p.x, list[0].p.y - list[1].p.y)
    }

    private func resetReferences() {
        center0 = centroid()
        spread0 = spread()
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        scroller.stopInertia()
        if !touchedOnce {
            touchedOnce = true
            onFirstTouch?()
        }
        let now = CACurrentMediaTime()
        if fingers.isEmpty {
            t0 = now
            maxFingers = 0
            moved = false
            travel = 0
            mode = .none
            dragging = false
            longPressDragging = false
            swipe = .zero
            swipeFired = false
            zoomAcc = 0
            acc = 0
            accSpread = 0
            candidate = (settings?.tapToClick ?? true) && now - lastTap < 0.3
            scroller.begin()
        }
        for t in touches {
            fingers[ObjectIdentifier(t)] = Finger(p: t.location(in: self), t: t.timestamp)
        }
        maxFingers = max(maxFingers, fingers.count)
        resetReferences()
        longPress?.cancel()
        if fingers.count == 1, maxFingers == 1, settings?.longPressDrag == true, !candidate {
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, self.fingers.count == 1, self.maxFingers == 1, !self.moved else { return }
                self.longPressDragging = true
                self.startDrag()
            }
            longPress = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48, execute: item)
        }
        updateDots()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var dx: CGFloat = 0
        var dy: CGFloat = 0
        var dt: TimeInterval = 0.016
        var hit = false
        for t in touches {
            let key = ObjectIdentifier(t)
            guard var f = fingers[key] else { continue }
            let p = t.location(in: self)
            dx += p.x - f.p.x
            dy += p.y - f.p.y
            dt = t.timestamp - f.t
            f.p = p
            f.t = t.timestamp
            fingers[key] = f
            hit = true
        }
        guard hit else { return }
        switch fingers.count {
        case 1:
            // Doigt restant après un geste à plusieurs doigts : ignoré.
            if maxFingers == 1 {
                travel += hypot(dx, dy)
                if !moved && travel > 9 {
                    moved = true
                    longPress?.cancel()
                }
                if candidate && moved && !dragging {
                    dragging = true
                    startDrag()
                }
                moveCursor(dx: dx, dy: dy, dt: dt)
            }
        case 2:
            twoFingers()
        default:
            threeFingers()
        }
        updateDots()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches, cancelled: true)
    }

    private func finish(_ touches: Set<UITouch>, cancelled: Bool) {
        for t in touches {
            fingers.removeValue(forKey: ObjectIdentifier(t))
        }
        if !fingers.isEmpty {
            resetReferences()
            updateDots()
            return
        }
        longPress?.cancel()
        let now = CACurrentMediaTime()
        let tapLimit = 0.28 + (maxFingers > 1 ? 0.08 : 0)
        if dragging || longPressDragging {
            client?.buttonUp("l")
            lastTap = 0
        } else if !cancelled, settings?.tapToClick ?? true, !moved, now - t0 < tapLimit {
            let button = maxFingers == 1 ? "l" : (maxFingers == 2 ? "r" : "m")
            client?.click(button)
            Haptics.click()
            lastTap = maxFingers == 1 ? now : 0
        } else if mode == .scroll {
            scroller.end()
        }
        dragging = false
        longPressDragging = false
        setDragHighlight(false)
        updateDots()
    }

    // MARK: - Gestes

    private func moveCursor(dx: CGFloat, dy: CGFloat, dt: TimeInterval) {
        guard let s = settings else { return }
        let speed = Double(hypot(dx, dy)) / max(dt * 1000, 4) // points par ms
        let gain = s.sens * (1 + s.accel * min(speed, 2.5) * 1.3)
        client?.move(Double(dx) * gain, Double(dy) * gain)
    }

    private func twoFingers() {
        let c = centroid()
        let d = spread()
        let dcx = c.x - center0.x
        let dcy = c.y - center0.y
        let dd = d - spread0
        center0 = c
        spread0 = d
        if mode == .none {
            acc += hypot(dcx, dcy)
            accSpread += dd
            let ad = abs(accSpread)
            if ad > 24 && ad > acc * 1.2 {
                mode = .pinch
                moved = true
            } else if (acc > 12 && ad < acc * 0.8) || acc > 40 {
                mode = .scroll
                moved = true
                scroller.begin()
            }
            return
        }
        if mode == .scroll {
            scroller.scroll(dx: Double(dcx), dy: Double(dcy))
        } else {
            zoomAcc += dd
            var steps = 0
            while zoomAcc >= 42 { steps += 1; zoomAcc -= 42 }
            while zoomAcc <= -42 { steps -= 1; zoomAcc += 42 }
            client?.zoom(steps)
        }
    }

    private func threeFingers() {
        let c = centroid()
        swipe.x += c.x - center0.x
        swipe.y += c.y - center0.y
        center0 = c
        guard !swipeFired, hypot(swipe.x, swipe.y) >= 55 else { return }
        swipeFired = true
        moved = true
        Haptics.tap()
        if abs(swipe.y) > abs(swipe.x) {
            if swipe.y < 0 {
                client?.key("tab", mods: ["win"]) // vers le haut : vue des tâches
            } else {
                client?.key("d", mods: ["win"]) // vers le bas : bureau
            }
        } else {
            client?.key("tab", mods: ["alt"]) // côté : application précédente
        }
    }

    private func startDrag() {
        client?.buttonDown("l")
        Haptics.tap()
        setDragHighlight(true)
    }

    // MARK: - Affichage

    private func setDragHighlight(_ on: Bool) {
        backgroundColor = on ? UIColor(Theme.accent).withAlphaComponent(0.10) : .clear
    }

    private func updateDots() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var i = 0
        for f in fingers.values {
            if i >= dots.count {
                let l = CAShapeLayer()
                l.path = UIBezierPath(ovalIn: CGRect(x: -30, y: -30, width: 60, height: 60)).cgPath
                l.fillColor = UIColor(red: 0.47, green: 0.59, blue: 1, alpha: 0.22).cgColor
                l.strokeColor = UIColor(red: 0.59, green: 0.69, blue: 1, alpha: 0.55).cgColor
                l.lineWidth = 1.5
                layer.addSublayer(l)
                dots.append(l)
            }
            dots[i].isHidden = false
            dots[i].position = f.p
            i += 1
        }
        while i < dots.count {
            dots[i].isHidden = true
            i += 1
        }
        CATransaction.commit()
    }
}

struct TrackpadView: UIViewRepresentable {
    let client: RemoteClient
    let settings: AppSettings
    var onFirstTouch: () -> Void = {}

    func makeUIView(context: Context) -> TrackpadUIView {
        let v = TrackpadUIView()
        v.client = client
        v.settings = settings
        v.onFirstTouch = onFirstTouch
        return v
    }

    func updateUIView(_ v: TrackpadUIView, context: Context) {
        v.client = client
        v.settings = settings
    }
}
