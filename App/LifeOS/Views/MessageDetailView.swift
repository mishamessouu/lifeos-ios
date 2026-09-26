import LifeOSKit
import SwiftUI

/// The full text of one message, its replies, and a reply field.
struct MessageDetailView: View {
    @Environment(AppModel.self) private var model
    let message: SentMessage

    /// The message id a reply binds to, or nil when the text goes to the
    /// Terminal (ReplyRule: four kinds, last 60 minutes).
    private var answers: String? {
        ReplyRule.answers(message)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label(message.kind.label, systemImage: message.kind.symbol)
                    Spacer()
                    Text(RowTime.full(for: message.at))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)

                LinkedText(text: message.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(model.replies(answering: message.id).map(OutboundReplyView.init)) { reply in
                    ReplyStateRow(reply: reply)
                }

                if answers == nil {
                    Label(Copy.toTerminalLine, systemImage: "text.bubble")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(message.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ComposerBar(placeholder: answers == nil ? Copy.terminalPlaceholder : Copy.replyPlaceholder) { text in
                await model.send(text, answers: answers)
            }
        }
    }
}
