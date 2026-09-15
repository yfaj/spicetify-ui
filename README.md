# Spicetify UI

An unofficial desktop front-end for the [Spicetify CLI](https://github.com/spicetify/cli).

Spicetify UI detects the Spicetify CLI you already have installed, renders its
configuration as a form, and runs its commands. It reimplements none of
Spicetify's behaviour and ships none of its code.

## Requirements

- The [Spicetify CLI](https://spicetify.app/docs/getting-started) installed separately.
- Spotify installed.

This app is not a distributor of Spicetify. It never bundles, forks, or
redistributes the CLI.

## Not affiliated

Not affiliated with, endorsed by, or sponsored by Spicetify or Spotify AB.
"Spotify" is a trademark of Spotify AB.

## Download

Each release ships a portable build and an installer per platform.

| Platform | Portable | Installer |
|---|---|---|
| Windows | `.zip` | `.exe` |
| macOS | `.zip` | `.dmg` |
| Linux | `.tar.gz` | `.deb` |

### Windows
Extract the `.zip` anywhere and run `spicetify_ui.exe`. No install step.

### Linux
Extract the tarball and run `spicetify_ui`. The app uses your desktop
environment's native window decorations.

### macOS
The macOS build is unsigned, so macOS quarantines it on download. Right-click
the app and choose Open once. Subsequent launches work normally.

## Build from source

Requires the Flutter stable channel and, on Windows, Visual Studio with the
"Desktop development with C++" workload.

    flutter pub get
    flutter test
    flutter build windows --release

## Layout

    lib/core/      pure Dart: CLI bridge, config parsing, platform helpers
    lib/ui/        Flutter widgets

`lib/core` never imports Flutter, so all CLI and config logic is testable
without a GUI.

## License

MIT. See `LICENSE`. See `NOTICE` for upstream attribution.
