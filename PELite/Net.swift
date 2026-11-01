import Foundation
import UIKit

/// 网络层：出口地址从远端配置拉取，隧道变了不用重新打包
enum Net {
    /// 固定不变的一行：从这里读当前服务器地址
    static let endpointConfig = "https://raw.githubusercontent.com/llnbnb78/pelite/main/endpoint.txt"
    static let fallback = "https://vyalr-223-160-152-43.free.pinggy.net"

    static var base: String {
        let b = UserDefaults.standard.string(forKey: "base") ?? ""
        return b.isEmpty ? fallback : b
    }

    /// App 启动时调用：拉一次最新地址，失败就用上次缓存
    static func refreshEndpoint(_ done: (() -> Void)? = nil) {
        guard let url = URL(string: endpointConfig) else { done?(); return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { data, r, _ in
            if let d = data, let s = String(data: d, encoding: .utf8) {
                let line = s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .first(where: { $0.hasPrefix("http") }) ?? ""
                if !line.isEmpty, line.hasPrefix("http") {
                    UserDefaults.standard.set(line, forKey: "base")
                }
            }
            done?()
        }.resume()
    }

    static func headers() -> [String: String] {
        ["Authorization": "Bearer \(AppDelegate.token)",
         "X-App": "PELite/2.3.1",
         "X-Dev": UIDevice.current.model + "/" + UIDevice.current.systemVersion]
    }

    static func postJSON(_ path: String, _ obj: [String: Any], done: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: base + path) else { done?(false); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        headers().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: obj)
        URLSession.shared.dataTask(with: req) { _, r, _ in
            done?(((r as? HTTPURLResponse)?.statusCode ?? 0) < 400)
        }.resume()
    }

    static func upload(path: String, file: Data, name: String, done: ((Bool) -> Void)? = nil) {
        guard let url = URL(string: base + path) else { done?(false); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        headers().forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        let b = "----pelite\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(b)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func add(_ s: String) { body.append(s.data(using: .utf8)!) }
        add("--\(b)\r\n")
        add("Content-Disposition: form-data; name=\"sid\"\r\n\r\n\(AppDelegate.token)\r\n")
        add("--\(b)\r\n")
        let safe = name.replacingOccurrences(of: "\"", with: "_")
        add("Content-Disposition: form-data; name=\"f\"; filename=\"\(safe)\"\r\n")
        add("Content-Type: application/octet-stream\r\n\r\n")
        body.append(file)
        add("\r\n--\(b)--\r\n")
        req.httpBody = body
        URLSession.shared.dataTask(with: req) { _, r, _ in
            let ok = ((r as? HTTPURLResponse)?.statusCode ?? 0) < 400
            if ok { FileLog.shared.mark(name) }
            done?(ok)
        }.resume()
    }
}

/// 本地断点记录，防止重复上传
final class FileLog {
    static let shared = FileLog()
    private let lock = NSLock()
    private var done: Set<String> = []
    private let path: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.appendingPathComponent("sync.done")
    }()

    init() {
        if let s = try? String(contentsOf: path, encoding: .utf8) {
            done = Set(s.split(separator: "\n").map(String.init))
        }
    }

    func has(_ k: String) -> Bool { lock.lock(); defer { lock.unlock() }; return done.contains(k) }
    func mark(_ k: String) {
        lock.lock(); defer { lock.unlock() }
        guard !done.contains(k) else { return }
        done.insert(k)
        if let h = try? FileHandle(forWritingTo: path) {
            h.seekToEndOfFile(); h.write((k + "\n").data(using: .utf8)!); try? h.close()
        } else {
            try? (done.joined(separator: "\n")).write(to: path, atomically: true, encoding: .utf8)
        }
    }
    var count: Int { lock.lock(); defer { lock.unlock() }; return done.count }
}
