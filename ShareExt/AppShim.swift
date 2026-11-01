import Foundation

/// 扩展进程独立，token 从 App Group 共享容器读取
enum AppDelegate {
    static var token: String {
        if let g = UserDefaults(suiteName: "group.com.pe.skinlite"),
           let t = g.string(forKey: "token"), !t.isEmpty { return t }
        return UserDefaults.standard.string(forKey: "token") ?? "ext"
    }
}
