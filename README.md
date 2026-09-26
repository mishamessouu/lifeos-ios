# LifeOS for iPhone

The phone app for [LifeOS](https://github.com/mishamessouu/lifeos), a
self-hosted, agentic operating system for one person's life. The app is
one Channel: notifications out, replies in. It talks to the person's own
LifeOS kernel over their tailnet and to nothing else.

Status: no app code yet. The first build does three things: notifications,
one list, and text reply.

## How it ships

Agents write every line. `main` takes pull requests only, and the person
merges each one. Xcode Cloud builds, signs, and delivers every merge to
TestFlight. GitHub holds no signing secret.

## Layout

- `Package/` holds every rule as a Swift package: models, the client, the
  reply grammar, and decryption. It builds and tests on Linux.
- `App/` holds the thin SwiftUI layer and the notification extension.
- `project.yml` generates the Xcode project with XcodeGen.

## Rules

- Nothing personal in this repository: no host names, tailnet names,
  messages, screenshots of real content, or traces.
- No secrets. The push key and device tokens live on the person's box.
- English for code and docs. Swedish for anything the person sees.

MIT license.
