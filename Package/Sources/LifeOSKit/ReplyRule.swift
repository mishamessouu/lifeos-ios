import Foundation

/// Decides what a reply written on one Sent message answers.
///
/// The kernel binds a reply only to a message it still holds open. The app
/// offers a bound reply on a Finding, a Digest, a Question, or an Answer
/// sent in the last 60 minutes. Anything older, or of another kind, gets a
/// plain Terminal entry instead (`answers` nil).
public enum ReplyRule {
    public static let window: TimeInterval = 60 * 60
    static let kinds: Set<Kind> = [.finding, .digest, .question, .answer]

    /// The message id a reply binds to, or nil for a Terminal entry.
    public static func answers(_ message: SentMessage, now: Date = Date()) -> String? {
        guard kinds.contains(message.kind), let at = message.at else { return nil }
        let age = now.timeIntervalSince(at)
        guard age >= -60, age < window else { return nil }
        return message.id
    }
}
