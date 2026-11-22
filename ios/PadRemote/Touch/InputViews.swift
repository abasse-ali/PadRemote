import SwiftUI
import UIKit

// MARK: - Molette verticale (bord droit du pavé)

final class ScrollStripUIView: UIView {
    weak var client: RemoteClient? { didSet { scroller.client = client } }
    var settings: AppSettings? { didSet { scroller.settings = settings } }

    private let scroller = ScrollEngine()
    private var active: UITouch?
    private var lastY: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) non pris en charge")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active == nil, let t = touches.first else { return }
        active = t
        lastY = t.location(in: self).y
        scroller.begin()
        backgroundColor = UIColor.white.withAlphaComponent(0.07)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = active, touches.contains(t) else { return }
        let y = t.location(in: self).y
        scroller.scroll(dx: 0, dy: Double(y - lastY) * 1.4)
        lastY = y
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        end(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        end(touches)
    }

    private func end(_ touches: Set<UITouch>) {
        guard let t = active, touches.contains(t) else { return }
        active = nil
        scroller.end()
        backgroundColor = .clear
    }
}

struct ScrollStripView: UIViewRepresentable {
    let client: RemoteClient
    let settings: AppSettings

    func makeUIView(context: Context) -> ScrollStripUIView {
        let v = ScrollStripUIView()
        v.client = client
        v.settings = settings
        return v
    }

    func updateUIView(_ v: ScrollStripUIView, context: Context) {
        v.client = client
        v.settings = settings
    }
}

// MARK: - Boutons Gauche / Milieu / Droit (maintien possible pendant qu'un autre doigt bouge)

final class MouseButtonsUIView: UIView {
    weak var client: RemoteClient?

    private let left = MouseButtonsUIView.makeButton(title: "Gauche")
    private let middle = MouseButtonsUIView.makeButton(title: nil)
    private let right = MouseButtonsUIView.makeButton(title: "Droit")
    private var touchButton: [ObjectIdentifier: String] = [:]
    private var pressCount: [String: Int] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        for v in [left, middle, right] {
            v.isUserInteractionEnabled = false
            addSubview(v)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) non pris en charge")
    }

    private static func makeButton(title: String?) -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(Theme.surface2)
        v.layer.cornerRadius = 20
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        if let title = title {
            let label = UILabel()
            label.text = title
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.textColor = UIColor(Theme.muted)
            v.addSubview(label)
        } else {
            let pill = UIView()
            pill.backgroundColor = UIColor(Theme.surface3)
            pill.layer.cornerRadius = 4
            pill.layer.borderWidth = 1
            pill.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            v.addSubview(pill)
        }
        return v
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let gap: CGFloat = 8
        let mid: CGFloat = 58
        let side = max(0, (bounds.width - mid - gap * 2) / 2)
        left.frame = CGRect(x: 0, y: 0, width: side, height: bounds.height)
        middle.frame = CGRect(x: side + gap, y: 0, width: mid, height: bounds.height)
        right.frame = CGRect(x: side + gap + mid + gap, y: 0, width: side, height: bounds.height)
        for v in [left, right] {
            v.subviews.first?.frame = v.bounds
        }
        if let pill = middle.subviews.first {
            pill.bounds = CGRect(x: 0, y: 0, width: 8, height: 22)
            pill.center = CGPoint(x: middle.bounds.midX, y: middle.bounds.midY)
        }
    }

    private func button(at p: CGPoint) -> String {
        if p.x < middle.frame.minX - 4 { return "l" }
        if p.x > middle.frame.maxX + 4 { return "r" }
        return "m"
    }

    private func view(for b: String) -> UIView {
        switch b {
        case "l": return left
        case "r": return right
        default: return middle
        }
    }

    private func setPressed(_ b: String, _ on: Bool) {
        let v = view(for: b)
        UIView.animate(withDuration: 0.08) {
            v.backgroundColor = on ? UIColor(Theme.accent) : UIColor(Theme.surface2)
            v.transform = on ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
        (v.subviews.first as? UILabel)?.textColor = on ? .white : UIColor(Theme.muted)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let b = button(at: t.location(in: self))
            touchButton[ObjectIdentifier(t)] = b
            let n = pressCount[b] ?? 0
            pressCount[b] = n + 1
            if n == 0 {
                client?.buttonDown(b)
                Haptics.tap()
                setPressed(b, true)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    private func release(_ touches: Set<UITouch>) {
        for t in touches {
            guard let b = touchButton.removeValue(forKey: ObjectIdentifier(t)) else { continue }
            let n = max(0, (pressCount[b] ?? 1) - 1)
            pressCount[b] = n
            if n == 0 {
                client?.buttonUp(b)
                setPressed(b, false)
            }
        }
    }
}

struct MouseButtonsView: UIViewRepresentable {
    let client: RemoteClient

    func makeUIView(context: Context) -> MouseButtonsUIView {
        let v = MouseButtonsUIView()
        v.client = client
        return v
    }

    func updateUIView(_ v: MouseButtonsUIView, context: Context) {
        v.client = client
    }
}

// MARK: - Saisie directe : vue invisible qui reçoit le clavier iOS

final class KeyInputView: UIView, UIKeyInput {
    var onText: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var wantsFocus = false

    // Clavier « brut » : pas de correction, pas de majuscule automatique, pas de guillemets typographiques.
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .dark
    var returnKeyType: UIReturnKeyType = .default

    var hasText: Bool { true } // pour que « effacer » soit toujours transmis

    override var canBecomeFirstResponder: Bool { true }

    func insertText(_ text: String) {
        onText?(text)
    }

    func deleteBackward() {
        onDelete?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && wantsFocus && !isFirstResponder {
            _ = becomeFirstResponder()
        }
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onFocusChange?(true) }
        return ok
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { onFocusChange?(false) }
        return ok
    }
}

struct KeyInputRepresentable: UIViewRepresentable {
    @Binding var active: Bool
    let client: RemoteClient

    func makeUIView(context: Context) -> KeyInputView {
        let v = KeyInputView()
        let binding = $active
        let remote = client
        v.onText = { [weak remote] s in remote?.typed(s) }
        v.onDelete = { [weak remote] in remote?.key("backspace") }
        v.onFocusChange = { focused in
            if !focused {
                DispatchQueue.main.async {
                    if binding.wrappedValue { binding.wrappedValue = false }
                }
            }
        }
        return v
    }

    func updateUIView(_ v: KeyInputView, context: Context) {
        v.wantsFocus = active
        if active && !v.isFirstResponder {
            DispatchQueue.main.async {
                if v.window != nil { _ = v.becomeFirstResponder() }
            }
        } else if !active && v.isFirstResponder {
            _ = v.resignFirstResponder()
        }
    }
}
