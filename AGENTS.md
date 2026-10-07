# AGENTS.md

The iPhone app for LifeOS. Public repository, MIT.

## Rules

- `main` takes pull requests only. Work on a branch; the person merges.
- Nothing personal: no host names, tailnet names, real messages, device
  tokens, traces, or screenshots of real content. Use `example.invalid`
  hosts in tests.
- No secrets, and nothing shaped like one.
- Every rule goes in `Package/` (LifeOSKit), with a test. The app under
  `App/` stays thin: views and platform calls only.
- Run `scripts/check.sh`, then `swift build` and `swift test` in
  `Package/`, before every commit.
- Edit `project.yml`, never `LifeOS.xcodeproj`. Run `xcodegen generate`
  and commit both.
- Use the LifeOS words: Channel, Sent message, Finding, Digest, Question,
  Terminal, Paired device, Run, Assistant.
- Swedish for every string the person sees. App strings go in
  `App/LifeOS/Copy.swift`. Labels that a package rule picks (kind labels,
  day and time words) stay in LifeOSKit, with their tests. The extension
  keeps its one fallback body in `NotificationService.swift`.
  English for code, comments, commits, and docs.
- Design: system fonts, Dynamic Type, SF Symbols, standard containers.
  Name the source of each borrowed pattern in `docs/design.md`.

## Style

Short sentences. Active voice. No em dashes anywhere, code comments
included.

## Where things are

- `docs/handover.md`: what exists, what is untested, what comes next.
- `docs/design.md`: design patterns and their sources.
- `docs/xcode-cloud.md`: the one-time Xcode Cloud setup.
- The kernel contracts live in the private `lifeos` repository.
