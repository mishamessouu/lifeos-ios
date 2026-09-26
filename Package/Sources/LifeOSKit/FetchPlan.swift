import Foundation

/// When the app fetches the newest messages.
///
/// A push carries no content, so the app fetches on every push. The kernel
/// marks a Sent message delivered only after the push call returns, so a
/// fetch the instant a push lands may miss the new message. The rule: on a
/// push, fetch at once and once more about three seconds later. On every
/// return to the foreground, fetch once.
public enum FetchPlan {
    public enum Trigger: Hashable, Sendable {
        case push
        case foreground
    }

    /// Seconds between the push and the second fetch.
    public static let pushRecheck: TimeInterval = 3

    /// The wait before each fetch, counted from the fetch before it.
    public static func gaps(for trigger: Trigger) -> [TimeInterval] {
        switch trigger {
        case .push: [0, pushRecheck]
        case .foreground: [0]
        }
    }

    /// Runs the fetches of one trigger in order. A sleep that throws, as
    /// `Task.sleep` does when the task is cancelled, ends the plan.
    public static func run(
        _ trigger: Trigger,
        sleep: (TimeInterval) async throws -> Void = FetchPlan.taskSleep,
        fetch: () async -> Void
    ) async {
        for gap in gaps(for: trigger) {
            if gap > 0 {
                do {
                    try await sleep(gap)
                } catch {
                    return
                }
            }
            await fetch()
        }
    }

    public static func taskSleep(_ seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}
