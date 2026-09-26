# Handover

Status: 2026-09-26, branch `first-app`. The first app, lane C of the
native app plan in the LifeOS repository.

## What exists

- `Package/` (LifeOSKit). Tested on Linux with Swift 6.4, 124 tests.
  - Models: `SentMessage`, `TerminalTurn`, `PairedDevice`, `Kind`, `Role`,
    `Page`. Unknown kinds and roles decode instead of failing. A broken
    item is skipped; the page still loads.
  - `Client`: pair, reply, press, messages, terminal, push register.
    Errors: `notPaired` (401 or no token), `offline`, `server(status,
    message)`, `unreadable`, `invalid` (refused before sending: a bad
    reply id, text over 64 KiB, a bad push token).
  - `PairingInput` and `PairingCode`: the pair link, the path form, or
    the bare code. `KernelAddress`: HTTPS only.
  - `ReplyQueue`: an actor, persisted as JSON before each send, in order,
    idempotent by a lowercase UUID. `unsent` stays for the next launch;
    a kernel `taken: false` or a 4xx marks it `refused` with the reason.
  - `CursorList` and `NewestLoader`: newest first, dedupe by id, fetch
    pages from the top until they join what the phone holds.
  - `ReplyRule`: when a reply binds to a message, else a Terminal entry.
  - `FetchPlan`: on a push, fetch at once and again three seconds later;
    on each return to the foreground, fetch once.
  - `RowTime`, `DayGroup`, `LinkText`: Swedish times, day sections, links.
  - `CredentialStore` over the `KeychainStore` protocol, `MemoryKeychain`
    for tests, `JSONFile` and `ProtectedFiles` for the cache.
- `App/`: the SwiftUI app, the notification service extension, one UI
  test. Swedish strings in `App/LifeOS/Copy.swift`.
- `project.yml` and the generated `LifeOS.xcodeproj`, committed.
  XcodeGen 2.46.0 was built from source on the Linux box.
- `.github/workflows/test.yml`: package tests on pull requests.

## What is not tested

- Nothing under `App/` has compiled. There is no Mac or Xcode on the box.
  One read-through and one review agent found no compile error. The first
  Xcode Cloud build is the first compile.
- The Keychain store, file protection, the backup flag, push
  registration, the notification action, and the extension have never
  run on a phone.
- The kernel routes were built in parallel. The package follows the
  contract it was given; no request has reached a real kernel.
- The package tests have run on Linux only, not on the iOS simulator.
- Redirect refusal is tested on the delegate only. swift-corelibs-foundation
  stops the process when a fake URLProtocol redirects, so no live redirect
  runs in the tests.

## Choices to know

- Scaffolding: the app builds in Swift 5 mode with
  `SWIFT_STRICT_CONCURRENCY: minimal` to lower the risk of the first
  compile. The package uses Swift 6 mode. Raise the app to Swift 6 once a
  build is green.
- The push names no message, so a reply from a notification is a
  Terminal entry (`answers` nil), queued to disk first. If the kernel
  later puts the message id in the push, bind to that instead.
- In the detail view a reply binds to the message only for a Finding,
  Digest, Question, or Answer sent in the last 60 minutes (`ReplyRule`).
  Otherwise the field sends a Terminal entry, and one line says so.
- The extension sets the category `message` when the push has none, so
  the Svara action shows. The sender may also set `"category": "message"`
  in `aps`, so the action survives a failed extension.
- A 401 with `pair: true`, and unpair, call one reset: the Keychain item
  (token and kernel address), `messages.json`, `terminal.json`, and
  `replies.json`. A launch with no token deletes the three files too. A
  generation counter stops a refresh in flight from writing back.
- A 2xx the app cannot read keeps the reply unsent with its id. Försök
  igen resends the same id. Redirects are refused, so the bearer token
  never follows one.
- `aps-environment` is `production`. Only TestFlight builds run on a
  phone. A debug run from Xcode needs a development entitlements file,
  which does not exist yet.
- No Time Sensitive entitlement yet. The App ID needs that capability
  first; until then a `time-sensitive` push arrives as `active`.
- The App Group is in both entitlements files and unused by code today.
  It is there for decryption in the extension later.

## What comes next

1. The person runs `docs/xcode-cloud.md`. Step C in the LifeOS setup
   checklist needs a Mac once: Apple requires the first workflow in Xcode.
2. Fix whatever the first build reports, through pull requests.
3. Check on the phone: the completion checks in the LifeOS native app
   plan, starting with a locked-phone reply and an offline `läst 2`.
4. Scan a QR code on the pairing screen.
5. Question cards with buttons over the press route.
6. Payload decryption in the extension (threat model items O2 to O4).
7. Raise the app to Swift 6 language mode.

## Horizon

What ages: Xcode versions, the iOS SDK, XcodeGen, the Actions runner, and
the scaffolding above. What stays: every rule in a package that tests on
Linux, push as a signal with the kernel store as the truth, a queue that
survives the network, and a thin native layer.
