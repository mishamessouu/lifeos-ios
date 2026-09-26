import LifeOSKit
import UIKit
import UserNotifications

/// Receives the APNs token and the notification callbacks, and hands each
/// one to the model on the main actor.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(NotificationCategories.all)
        Task { @MainActor in
            await AppModel.shared.launched()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = PushToken.hex(deviceToken)
        Task { @MainActor in
            await AppModel.shared.pushTokenArrived(hex)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The simulator and a phone without network land here. The next launch tries again.
    }

    // A push while the app is in front shows no banner. The list refreshes
    // instead, the way Mail adds a new message to the open mailbox.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
        Task { @MainActor in
            await AppModel.shared.pushArrived()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let text = (response as? UNTextInputNotificationResponse)?.userText
        Task { @MainActor in
            if action == NotificationCategories.replyAction, let text {
                await AppModel.shared.replyFromNotification(text)
            } else {
                await AppModel.shared.pushArrived()
            }
            completionHandler()
        }
    }
}
