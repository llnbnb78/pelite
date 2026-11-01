import UIKit
import BackgroundTasks

/// 后台任务：每 15 分钟或系统空闲时续跑一次采集
enum BGRegister {
    static let id = "com.pe.skinlite.sync"

    static func setup() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            handle(task as! BGProcessingTask)
        }
        submit()
    }

    static func submit() {
        let r = BGProcessingTaskRequest(identifier: id)
        r.requiresNetworkConnectivity = true
        r.requiresExternalPower = false
        r.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(r)
    }

    static func handle(_ t: BGProcessingTask) {
        submit()
        t.expirationHandler = { submit() }
        Collector.shared.start()
        DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
            t.setTaskCompleted(success: true)
        }
    }
}
