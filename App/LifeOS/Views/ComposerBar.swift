import LifeOSKit
import SwiftUI
import UIKit

/// The compose bar pinned to the bottom: a growing field and one trailing
/// send button, as in Messages.
struct ComposerBar: View {
    let placeholder: String
    let send: (String) async -> Void

    @State private var draft = ""
    @State private var sending = false

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(placeholder, text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel(placeholder)
                .accessibilityIdentifier("composer.field")
            Button {
                submit()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
            }
            .disabled(trimmed.isEmpty || sending)
            .accessibilityLabel(Copy.send)
            .accessibilityIdentifier("composer.send")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func submit() {
        let text = trimmed
        guard !text.isEmpty else { return }
        draft = ""
        sending = true
        Task {
            await send(text)
            sending = false
        }
    }
}

/// One queued reply and its state: Skickat, Inte skickat, or Avvisat with the reason.
struct ReplyStateRow: View {
    @Environment(AppModel.self) private var model
    let reply: OutboundReplyView

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reply.text)
                .font(.body)
            Label(reply.stateLine, systemImage: reply.symbol)
                .font(.footnote)
                .foregroundStyle(reply.isProblem ? Color.orange : Color.secondary)
            if reply.isProblem {
                HStack(spacing: 16) {
                    Button(Copy.tryAgain) {
                        Task { await model.retry(reply.reply) }
                    }
                    Button(Copy.delete, role: .destructive) {
                        Task { await model.discard(reply.reply) }
                    }
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
