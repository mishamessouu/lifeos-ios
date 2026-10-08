public struct UNAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let alert = UNAuthorizationOptions(rawValue: 1)
    public static let sound = UNAuthorizationOptions(rawValue: 2)
    public static let badge = UNAuthorizationOptions(rawValue: 4)
}
public enum UNAuthorizationStatus: Sendable { case notDetermined, denied, authorized, provisional, ephemeral }
public final class UNNotificationSettings: @unchecked Sendable { public let authorizationStatus: UNAuthorizationStatus = .notDetermined }
public final class UNUserNotificationCenter: @unchecked Sendable {
    public static func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }
    public func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    public func notificationSettings() async -> UNNotificationSettings { UNNotificationSettings() }
}
