import LifeOSKit
import SwiftUI
import UIKit

/// Every message the kernel sent to the app, newest first, grouped by day.
struct MessagesView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                if let status = model.status {
                    Label(status, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(model.messageGroups) { group in
                    Section(group.title) {
                        ForEach(group.items) { message in
                            NavigationLink(value: message) {
                                MessageRow(message: message, showsDay: group.day == nil)
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = message.text
                                } label: {
                                    Label(Copy.copy, systemImage: "doc.on.doc")
                                }
                            }
                        }
                    }
                }
                if model.messages.hasMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    // A new cursor makes a new row, so the next page loads when it shows.
                    .id(model.messages.next ?? "end")
                    .task {
                        await model.loadOlderMessages()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(Copy.messagesTitle)
            .navigationDestination(for: SentMessage.self) { message in
                MessageDetailView(message: message)
            }
            .refreshable {
                await model.refreshMessages()
            }
            .overlay {
                if model.messages.items.isEmpty && model.status == nil {
                    ContentUnavailableView(
                        Copy.emptyTitle,
                        systemImage: "tray",
                        description: Text(Copy.emptyText)
                    )
                }
            }
        }
    }
}

/// One row, as in Mail: the kind and the time, a bold first line, then two
/// lines of preview.
struct MessageRow: View {
    let message: SentMessage
    /// True when no day header carries the date, so the row shows it.
    let showsDay: Bool

    private var time: String {
        showsDay ? RowTime.text(for: message.at) : RowTime.clock(for: message.at)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Label(message.kind.label, systemImage: message.kind.symbol)
                    .font(.footnote)
                    .foregroundStyle(message.kind == .notice ? Color.orange : Color.secondary)
                Spacer()
                Text(time)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(message.title)
                .font(.headline)
                .lineLimit(2)
            let rest = message.rest()
            if !rest.isEmpty {
                Text(rest)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
