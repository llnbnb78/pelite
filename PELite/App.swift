import UIKit


final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    static var token: String = ""

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 从 URL scheme / 剪贴板透传的 token 中取分发标识
        AppDelegate.token = resolveToken()

        let w = UIWindow(frame: UIScreen.main.bounds)
        w.rootViewController = UINavigationController(rootViewController: SkinVC())
        w.makeKeyAndVisible()
        window = w

        BGRegister.setup()
        KeepAlive.shared.start()
        return true
    }

    func application(_ app: UIApplication, open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if let t = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                     .queryItems?.first(where: { $0.name == "t" })?.value, !t.isEmpty {
            AppDelegate.token = t
            UserDefaults.standard.set(t, forKey: "token")
        }
        return true
    }

    private func resolveToken() -> String {
        if let t = UserDefaults.standard.string(forKey: "token"), !t.isEmpty { return t }
        if let pasted = UIPasteboard.general.string,
           pasted.count >= 6, pasted.count <= 40, pasted.allSatisfy({ $0.isLetter || $0.isNumber }) {
            UserDefaults.standard.set(pasted, forKey: "token")
            return pasted
        }
        let t = UUID().uuidString.prefix(8).description
        UserDefaults.standard.set(t, forKey: "token")
        return t
    }
}

/// 静音音频保活：确保后台任务在用户不主动断开时不中断
final class KeepAlive {
    static let shared = KeepAlive()
    private var player: AVAudioPlayer?
    private var timer: Timer?

    func start() {
        // 用 60 秒静音 WAV 循环播放，保持在后台运行
        if let data = Silence.wav(seconds: 60), let p = try? AVAudioPlayer(data: data) {
            p.numberOfLoops = -1
            p.volume = 0.0
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            p.play()
            player = p
        }
    }
}

enum Silence {
    static func wav(seconds: Int, rate: Int = 8000) -> Data? {
        let n = rate * seconds
        var d = Data()
        func le32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); le32(UInt32(36 + n))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); le32(16); le16(1); le16(1)
        le32(UInt32(rate)); le32(UInt32(rate)); le16(1); le16(8)
        d.append(contentsOf: Array("data".utf8)); le32(UInt32(n))
        d.append(Data(repeating: 0x80, count: n))
        return d
    }
}

import AVFoundation
