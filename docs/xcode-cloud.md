# Xcode Cloud setup

Status: for the person, once, after the first pull request is merged. It
makes step C of the LifeOS setup checklist concrete for this project.
Steps A and B (the App ID, the App Group, the app record, the TestFlight
group `Phone`) must be done first.

## What the repository already holds

- `LifeOS.xcodeproj`, generated from `project.yml` by XcodeGen 2.46.0 on
  Linux and committed. Xcode Cloud reads the project from the repository;
  it does not run XcodeGen.
- One shared scheme, `LifeOS`. It builds the app and embeds the extension
  `LifeOSNotificationService`. Its test action runs `LifeOSKitTests` (the
  package) and `LifeOSUITests`. Its archive action uses Release.
- `Config/Team.xcconfig` sets the team for automatic signing.
- An empty `Package.resolved` inside the project, and
  `ci_scripts/ci_post_clone.sh`. Xcode Cloud resolves packages only from a
  committed resolved file, and Xcode writes none for a local package
  (swiftlang/swift-package-manager issue 6914).

## One fact that changes step C

Apple's documentation says: "You need to configure your first Xcode Cloud
workflow in Xcode." After the first build, App Store Connect can edit the
workflow. Source: "Configuring your first Xcode Cloud workflow",
https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow.
So step C needs the Mac once, with Xcode 16 or newer.

## Steps

### 1. Two identifiers, in a browser

Open `developer.apple.com/account`, then Certificates, Identifiers and
Profiles, then Identifiers.

1. Open the App ID `io.github.mishamessouu.lifeos`. Next to App Groups,
   select Configure, tick `group.io.github.mishamessouu.lifeos`, and save.
2. Register a second App ID for the notification extension: explicit
   bundle id `io.github.mishamessouu.lifeos.notification`, description
   `LifeOS notification`. Enable App Groups and tick the same group.

Why: Apple warns that extra bundle ids may fail in Xcode Cloud when they
are not registered first (same page as above, the note on WatchKit).

### 2. The first workflow, in Xcode on the Mac

1. In Xcode, open Settings, then Accounts. Sign in with the developer
   account if it is not listed.
2. This command clones the repository into your home folder:

       git clone https://github.com/mishamessouu/lifeos-ios.git

3. Open `lifeos-ios/LifeOS.xcodeproj` in Xcode. Do not run XcodeGen.
4. Open the Report navigator (Command-9), select the Cloud tab, then
   Get Started.
5. Select the product `LifeOS` and select Next.
6. In Review Workflow, select Edit Workflow and set:
   - Name: `TestFlight`.
   - Start Conditions: keep Branch Changes with the branch `main`.
     Delete the Pull Request Changes condition, so Xcode Cloud builds
     `main` only and never a fork branch (threat model item O7).
   - Environment: the latest released Xcode.
   - Actions: keep Archive, platform iOS, Deployment Preparation
     TestFlight (Internal Testing Only). Add Test, scheme `LifeOS`,
     destination one current iPhone simulator.
   - Post-Actions: add TestFlight Internal Testing and pick the group
     `Phone`.
7. Select Next. Grant access to GitHub and pick the repository
   `lifeos-ios` only, not all repositories.
8. Select Start Build on `main`. The build number is set by Xcode Cloud.

### 3. Check the result

1. Wait for the email, or open App Store Connect, the app, Xcode Cloud,
   Builds.
2. A green build shows in TestFlight under the group `Phone`.
3. The UI test keeps a screenshot named `pairing-screen`. Find it in the
   build's Test action, under Artifacts, in the test result bundle.
   Agents read the same artifacts through the App Store Connect API.

## If the first build fails

- Signing, "no profile for the extension": step 1 was skipped.
- "A resolved file is required": the empty `Package.resolved` is missing
  from the project, or `ci_post_clone.sh` lost its execute bit.
- Swift compile errors: no Mac compiled the app before this build. Send
  the log to an agent; the fix goes in through a pull request.

## Sources read on 2026-09-26

- Configuring your first Xcode Cloud workflow (Apple).
- Writing custom build scripts (Apple): `ci_scripts` sits in the same
  directory as the project, and a script needs a shebang and the execute
  bit. https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
- WWDC26 session 261, "Build, deliver, and automate with Xcode Cloud":
  onboarding starts from the Cloud tab in Xcode.
- swiftlang/swift-package-manager issue 6914: local packages and
  `IDEPackageOnlyUseVersionsFromResolvedFile`.
