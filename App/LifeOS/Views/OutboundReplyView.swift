import LifeOSKit

/// The words and symbol one queued reply shows.
struct OutboundReplyView: Identifiable {
    let reply: OutboundReply

    var id: String { reply.id }
    var text: String { reply.text }

    var isProblem: Bool { reply.state != .sent }

    var stateLine: String {
        switch reply.state {
        case .sent:
            return Copy.sent
        case .unsent:
            return Copy.unsent
        case .refused:
            if let reason = reply.reason, !reason.isEmpty {
                return "\(Copy.refused): \(reason)"
            }
            return Copy.refused
        }
    }

    var symbol: String {
        switch reply.state {
        case .sent: return "checkmark"
        case .unsent: return "clock"
        case .refused: return "exclamationmark.circle"
        }
    }
}
