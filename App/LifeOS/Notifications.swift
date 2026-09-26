import Foundation
import UserNotifications

/// The notification category and its one action. The service extension sets
/// this category on every push, so the action shows even when the sender
/// names none.
enum NotificationCategories {
    static let message = "message"
    static let replyAction = "reply"

    static var all: Set<UNNotificationCategory> {
        let reply = UNTextInputNotificationAction(
            identifier: replyAction,
            title: Copy.replyAction,
            // A reply can start an Assistant Run with wiki reads, so it needs unlock.
            options: [.authenticationRequired],
            icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left"),
            textInputButtonTitle: Copy.send,
            textInputPlaceholder: Copy.replyPlaceholder
        )
        let category = UNNotificationCategory(
            identifier: message,
            actions: [reply],
            intentIdentifiers: [],
            options: []
        )
        return [category]
    }
}
