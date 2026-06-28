# BroPrompter

A native macOS teleprompter. Camera preview behind your script, auto-scroll,
and audio / video recording, built with SwiftUI for macOS 26 (Tahoe).

Status: early build. The Mac App Store release is pending review. In the
meantime the builds below are open-source and free to download.

## Download and install

Grab the latest `BroPrompter-<version>.dmg` from the
[Releases](../../releases) page, open it, and drag BroPrompter to Applications.

These bridge builds are not yet notarized by Apple (the Developer Program
account is still being verified). macOS Gatekeeper will block the first launch.
Clear it once, then the app opens normally forever after.

Option A - Terminal (most reliable):

```sh
xattr -dr com.apple.quarantine /Applications/BroPrompter.app
```

Option B - System Settings:

1. Double-click BroPrompter. macOS blocks it.
2. Open System Settings > Privacy & Security.
3. Scroll to the message about BroPrompter and click Open Anyway, then confirm.

Once the App Store / notarized build ships, this step goes away.

## Build from source

Requirements: macOS 15+, Xcode 16+, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make generate   # generate BroPrompter.xcodeproj from project.yml
make build      # build the app (Debug, ad-hoc signing)
make run        # build and launch
```

Package a distributable DMG yourself:

```sh
make release    # writes build/release/BroPrompter-<version>.dmg (unsigned)
```

To produce a Developer ID signed + notarized DMG, set the signing environment
first (requires an active Apple Developer membership):

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
TEAM_ID="TEAMID" \
NOTARY_PROFILE="your-notary-profile" \
make release
```

## Development

```sh
make format     # autofix to the Airbnb Swift Style Guide
make lint       # check formatting and lint (0 violations required)
make test       # headless unit / integration tests
make hooks      # install the pre-commit hook (run once per clone)
```

See `CLAUDE.md`, `DESIGN.md`, and `GUIDELINES.md` for the design system,
behavior contract, and contributor conventions.

## License

[MIT](LICENSE)
