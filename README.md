# LifeOS for iPhone

The phone app for [LifeOS](https://github.com/mishamessouu/lifeos), a
self-hosted, agentic operating system for one person's life. The app is
one Channel: notifications out, replies in. It talks to the person's own
LifeOS kernel over their tailnet and to nothing else.

Status: the first app. Pairing, the list of Sent messages, a detail view
with reply, the Terminal, settings, push registration, and a text reply
from a notification. See `docs/handover.md` for what is tested and what
is not.

## How it ships

Agents write every line. `main` takes pull requests only, and the person
merges each one. Xcode Cloud builds, signs, and delivers every merge to
TestFlight. GitHub holds no signing secret.

## Layout

- `Package/` holds every rule as the Swift package `LifeOSKit`: models,
  JSON decoding, the client, the pair link parser, the reply queue, the
  cursor merge, and the fetch plan. It builds and tests on Linux.
- `App/LifeOS/` holds the thin SwiftUI app. `App/NotificationService/`
  holds the notification service extension. `App/UITests/` holds one UI
  test that keeps a screenshot of the pairing screen.
- `project.yml` generates `LifeOS.xcodeproj` with XcodeGen. Both are
  committed.
- `Config/Team.xcconfig` names the signing team. `ci_scripts/` runs in
  Xcode Cloud.
- `docs/design.md` names each borrowed design pattern and its source.
  `docs/xcode-cloud.md` is the one-time Xcode Cloud setup.
- `scripts/make-icon.py` draws the app icon. `scripts/check.sh` fails on
  an em dash or an email address in any tracked file.

## Test the package

These commands run the package tests on Linux or a Mac with Swift 6.0 or
newer:

    cd Package
    swift build
    swift test

GitHub Actions runs the same tests on every pull request.

## Regenerate the project

Run this after any change to `project.yml` or to the files under `App/`,
then commit the result with the change:

    xcodegen generate

## Rules

- Nothing personal in this repository: no host names, tailnet names,
  messages, screenshots of real content, or traces.
- No secrets. The push key and device tokens live on the person's box.
- English for code and docs. Swedish for anything the person sees.

MIT license.
