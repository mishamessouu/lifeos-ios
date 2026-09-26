# Design

Status: first app, 2026-09-26. The goal is a plain, native app that
feels first party. Apple's Human Interface Guidelines are the core, as in
the LifeOS `DESIGN.md`. Every pattern below names where it came from. Each
source was read on 2026-09-26: HIG pages as Apple's JSON, open-source apps
in their code at the commit named.

## Rules we keep

- System fonts and text styles only (`.headline`, `.subheadline`,
  `.footnote`, `.body`). No fixed point sizes. HIG Typography: "Using text
  styles with the system fonts also ensures support for Dynamic Type and
  larger accessibility type sizes."
- SF Symbols for every icon, so icons scale with the text. HIG Typography:
  "When you use SF Symbols, you get icons that scale automatically with
  Dynamic Type size changes."
- Standard containers: `NavigationStack`, `List`, `Form`, `TabView`,
  `ContentUnavailableView`. No custom chrome, no custom colors beyond the
  system accent. Light and dark come from the system.
- Every control has an accessibility label in Swedish. A row reads as one
  element.
- Text wraps rather than truncates in detail views. HIG Typography: "Avoid
  truncating text in scrollable regions unless people can open a separate
  view to read the rest of the content."

## Screens and what each borrows

### Pairing

- One `Form` with one field for the link or the code, a system
  `PasteButton`, and one primary button. A second field for the kernel
  address shows only when the pasted text is a bare code.
- The footer says in one sentence where the code comes from. Borrowed from
  ntfy iOS: its empty topic view explains the one command that fills it
  (`ntfy/Views/Notifications/NotificationListView.swift`, the overlay text
  "To send notifications to this topic, simply PUT or POST").
- `PasteButton` instead of reading the pasteboard: the system button pastes
  without the permission prompt.

### Messages (the list)

- A plain `List`, one row per Sent message, newest first. HIG Lists and
  tables: "Prefer displaying text in a list or table" and "Keep item text
  succinct so row content is comfortable to read ... letting people choose
  an item to reveal its content in a detail view."
- The row follows Apple Mail's message list: a bold first line, the time on
  the trailing edge in secondary color, then two lines of preview in
  secondary color. The kind label (Fynd, Dagens fokus, Fråga, Svar) sits
  where Mail puts the sender, with its SF Symbol.
- Section headers by day ("Idag", "Igår", then the weekday or the date).
  Borrowed from Reminders, which organizes a list into named sections
  (Apple Support, "Edit and organize a list in Reminders on iPhone"), and
  from Things 3, whose headings split one list into parts (Cultured Code,
  Things features page). Inside a day, the row shows only the clock time.
- Mail's row time rule for the detail header and older rows: the clock
  time today, "igår", the weekday within a week, else the date
  (`RowTime` in the package).
- Pull to refresh with `.refreshable`, as ntfy iOS does on its list
  (`NotificationListView.swift`, `.refreshable`).
- Infinite scroll: the last row is a progress row that loads the next
  older page by `before`.
- Empty state: `ContentUnavailableView` with one line saying what arrives
  here. ntfy iOS does the same with a custom overlay; the system view
  replaces it on iOS 17.
- Long press gives Kopiera. Not borrowed: swipe to delete, used by Mail,
  ntfy iOS (`NotificationRowView.swift`, a trailing destructive swipe), and
  Bark (`MessageListViewController.swift`, `UIContextualAction`). The
  kernel store is the truth for LifeOS; a local delete would lie about it.
  Mail's swipe settings are in Apple Support, "Organize email in mailboxes
  on iPhone".
- New content never moves the list under the person's hand. HIG
  Notifications: when the app is in front, "present the information in a
  way that's discoverable but not distracting ... Mail simply adds it to
  the list." The app shows no banner in front; it refreshes the list.

### Message detail

- The full text with links tappable, selectable text, the kind and the full
  time above it. Links are found by `LinkText` in the package.
- Replies to this message show below the text with their state: Skickat,
  Inte skickat, Avvisat.
- A compose bar pinned to the bottom with `.safeAreaInset(edge: .bottom)`:
  a growing text field and one trailing circular send button. Borrowed from
  Apple Messages and from Hermex (`HermesMobile/Features/Chat/
  ChatComposerView.swift`: "One trailing circle", with the accessibility
  label "Send"; ours says "Skicka").

### Terminal

- Turns as Messages bubbles: the person's turns trailing in the accent
  color, the Assistant's leading in the secondary background. Newest at the
  bottom. Hermex anchors its transcript at the bottom with
  `.defaultScrollAnchor(.bottom)` and pins its composer with
  `.safeAreaInset(edge: .bottom)` (`ChatTranscriptView.swift`); we do the
  same.
- Times are small and secondary under each bubble. Messages hides them
  behind a swipe; we show them because the Terminal is a log as much as a
  chat.
- An unsent reply shows at the bottom with "Inte skickat", as Messages
  shows "Not Delivered".

### Settings

- A `Form` with `LabeledContent` rows: device name, device id, kernel
  address. The kernel address edits in place.
- Unpair is one destructive button with a confirmation dialog, at the
  bottom, the way iOS Settings places "Sign Out". Its footer says the
  device stays on the box's list until the person revokes it there.
- The notification row says whether notifications are on and opens the
  system settings when they are off.

### Notifications

- The alert text is generic, "Nytt från LifeOS". HIG Notifications:
  "Provide generically descriptive text to display when notification
  previews aren't available" and "Avoid including sensitive, personal, or
  confidential information in a notification."
- One action, "Svara", a text input that requires unlock. Borrowed from
  Home Assistant iOS: it builds `UNTextInputNotificationAction` and adds
  `.authenticationRequired` from its action options
  (`Sources/Shared/API/Models/NotificationAction.swift`). HIG: "Prefer
  actions that let people perform common, time-saving tasks"; "Avoid
  providing an action that merely opens your app."
- The push carries no content; the app fetches by cursor. Borrowed from
  ntfy iOS: its extension handles a `poll_request` push by fetching from
  the server (`ntfyNSE/NotificationService.swift`).
- The service extension delivers exactly once, under a lock, and falls
  back to the push as delivered when time runs out. Borrowed from Hermex
  (`HermesNotificationService/NotificationService.swift`, "whoever gets
  here first wins"). Bark puts decryption first in its extension
  (`NotificationServiceExtension/NotificationService.swift`, the
  `ciphertext` processor); ours keeps that place free for later.

### Question cards (later slice)

The OpenClaw iOS app shows an approval as a headline, one explaining
sentence, and one button per choice, with the destructive choice last
(`apps/ios/Sources/Gateway/ExecApprovalPromptDialog.swift`). Its design
file says: "Prefer `NavigationStack`, `List`, `Form`, toolbars, sheets, and
system controls" and "Use semantic colors. Red means destructive or
stopped" (`apps/ios/DESIGN.md`). The Question card will follow it. This
build has the press route in the package and no card yet.

## Sources

- HIG Lists and tables, Notifications, Toolbars, Typography:
  https://developer.apple.com/design/human-interface-guidelines/
- Apple Support, Reminders sections:
  https://support.apple.com/guide/iphone/edit-and-organize-a-list-iph82596cb20/ios
- Apple Support, Mail mailboxes and swipes:
  https://support.apple.com/guide/iphone/iph376ef8aa3/ios
- Things 3 headings: https://culturedcode.com/things/features/
- ntfy iOS, MIT, commit 96e659c: https://github.com/binwiederhier/ntfy-ios
- Bark, MIT, commit 6d84f75: https://github.com/Finb/Bark
- Home Assistant iOS, Apache-2.0, commit 2bca3df:
  https://github.com/home-assistant/iOS
- Home Assistant actionable notifications:
  https://companion.home-assistant.io/docs/notifications/actionable-notifications/
- OpenClaw iOS, MIT, commit f979670:
  https://github.com/openclaw/openclaw/tree/main/apps/ios
- Hermex, MIT, commit e73852c: https://github.com/uzairansaruzi/hermex

No code was copied. The patterns were rewritten for this app.
