import Foundation
import UserNotifications

/// Sets the generic body on every push and hands it on at once. It never
/// fails a notification: on any problem, and when time runs out, the push
/// goes on as it came. This is the place where decryption of a payload goes
/// later, before the body is set. The pattern of one delivery under a lock
/// follows Hermex (MIT), see docs/design.md.
final class NotificationService: UNNotificationServiceExtension {
    static let genericBody = "Nytt från LifeOS"
    static let category = "message"

    private let lock = NSLock()
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var original: UNNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        lock.lock()
        self.contentHandler = contentHandler
        original = request.content
        lock.unlock()

        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            deliver(request.content)
            return
        }
        content.body = NotificationService.genericBody
        // The Svara action hangs on this category. Set it when the sender named none.
        if content.categoryIdentifier.isEmpty {
            content.categoryIdentifier = NotificationService.category
        }
        deliver(content)
    }

    override func serviceExtensionTimeWillExpire() {
        lock.lock()
        let fallback = original
        lock.unlock()
        if let fallback {
            deliver(fallback)
        }
    }

    /// Calls the handler once. Whoever comes first wins.
    private func deliver(_ content: UNNotificationContent) {
        lock.lock()
        let handler = contentHandler
        contentHandler = nil
        lock.unlock()
        handler?(content)
    }
}
