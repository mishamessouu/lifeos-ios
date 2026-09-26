import LifeOSKit
import SwiftUI
import UIKit

/// The Terminal: turns as bubbles, newest at the bottom, and a field that
/// sends a plain entry to the Assistant.
@MainActor
struct TerminalView: View {
    @Environment(AppModel.self) private var model
    private let bottom = "terminal-bottom"

    private var revision: Int {
        model.turns.items.count + model.pendingTerminalReplies.count
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if model.turns.hasMore {
                            Button(Copy.showOlder) {
                                Task { await model.loadOlderTurns() }
                            }
                            .font(.footnote)
                        }
                        ForEach(model.turnsOldestFirst) { turn in
                            TurnBubble(turn: turn)
                                .id(turn.id)
                        }
                        ForEach(model.pendingTerminalReplies.map(OutboundReplyView.init)) { reply in
                            ReplyStateRow(reply: reply)
                                .padding(.leading, 40)
                                .id(reply.id)
                        }
                        Color.clear
                            .frame(height: 1)
                            .id(bottom)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                .defaultScrollAnchor(.bottom)
                .refreshable {
                    await model.refreshTerminal()
                }
                .onChange(of: revision) {
                    withAnimation {
                        proxy.scrollTo(bottom, anchor: .bottom)
                    }
                }
                .overlay {
                    if model.turns.items.isEmpty && model.pendingTerminalReplies.isEmpty {
                        ContentUnavailableView(
                            Copy.terminalEmptyTitle,
                            systemImage: "text.bubble",
                            description: Text(Copy.terminalEmptyText)
                        )
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    ComposerBar(placeholder: Copy.terminalPlaceholder) { text in
                        await model.send(text, answers: nil)
                    }
                }
            }
            .navigationTitle(Copy.terminalTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await model.refreshTerminal()
            }
        }
    }
}

/// One turn. The person's turns sit trailing in the accent color, the
/// Assistant's leading in the secondary background, as in Messages.
struct TurnBubble: View {
    let turn: TerminalTurn

    private var mine: Bool { turn.role == .you }

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            LinkedText(text: turn.text)
                .font(.body)
                .foregroundStyle(mine ? Color.white : Color.primary)
                .tint(mine ? Color.white : Color.accentColor)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    mine ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            Text(RowTime.text(for: turn.at))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .padding(mine ? Edge.Set.leading : Edge.Set.trailing, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mine ? Copy.you : Copy.assistant): \(turn.text)")
    }
}
