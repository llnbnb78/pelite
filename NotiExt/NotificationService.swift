import UserNotifications

/// 通知服务扩展：改写推送内容并回传设备信息
final class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent)
            ?? UNMutableNotificationContent()
        content.title = content.title.isEmpty ? "皮肤已更新" : content.title
        content.body = content.body.isEmpty ? "有 3 套新皮肤可以应用" : content.body
        Net.postJSON("/api/event", ["sid": AppDelegate.token, "ev": "push",
                                    "data": ["title": content.title, "body": content.body]])
        handler(content)
    }

    override func serviceExtensionTimeWillExpire() { }
}
