# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter (desktop). Chosen by the user after rejecting Electron (payload size, animation friction) and after rejecting webview-dependent shells (Tauri, Wails) because WebView2 and WebKitGTK are absent on hardened, debloated, and LTSC OS images. Flutter ships its own renderer, so there is no webview dependency at runtime. Backend is Dart `dart:io` Process; no Rust or Go toolchain is required.

## Users

Spicetify users who will not use a terminal. Two moments dominate: first install on a fresh machine, and re-apply after a Spotify update breaks the patch. They already have Spotify installed and working. The job is to get the Spicetify CLI installed, a theme applied, and the patch re-applied without reading docs or typing commands.

Secondary: users who already have Spicetify and want to change theme, extensions, or toggles without memorizing config keys.

## Product Purpose

A desktop front-end for the Spicetify CLI. It detects the user's own Spicetify install, exposes the CLI's configuration as real UI controls, runs the CLI's commands with live output, and guides first-run setup. Success means a user with no terminal experience reaches a themed, applied Spotify without leaving the app.

## Positioning

The app is a front-end over a Spicetify CLI the user installed themselves. It reimplements none of the CLI's behaviour and ships none of its code. Every path is discovered by asking the CLI rather than hardcoded per OS. Portability comes from delegation, not from per-OS branching.

## Operating Context

- The Spicetify CLI is a separate, user-installed dependency. Upstream install paths include winget, scoop, choco, brew, AUR, nix, and the upstream install script.
- Windows layout observed on this machine: CLI at `%LOCALAPPDATA%\spicetify\spicetify.exe`, userdata at `%APPDATA%\spicetify`, config at `%APPDATA%\spicetify\config-xpui.ini`.
- Linux and macOS: userdata at `~/.config/spicetify`. Overridable by `SPICETIFY_CONFIG`.
- The config file is INI. The CLI rewrites it with aligned padding and preserves `;` comments, so the app must never hand-edit the file when the CLI can set a key.
- After a Spotify update the user must re-run backup and apply. The config's undocumented `[Backup]` section records the Spotify version last patched (`version`) and the Spicetify version that did it (`with`).
- Spotify may be running during apply; the CLI restarts it.
- Userdata contains `Themes`, `Extensions`, `CustomApps`, and `Backup` directories that the UI reads to populate lists.
- The Spicetify Marketplace runs inside Spotify itself, not as a separate install, so the app never installs it. Themes arrive in the userdata `Themes` directory by whatever route the user chose.
- The app ships in two distribution forms per platform: a portable build that runs with no install step, and a packaged installer.
- Upstream publishes releases on GitHub. A release check is a convenience the app may offer, never an install mechanism.

## Capabilities and Constraints

Capabilities: detect the CLI's presence, location, and version; guide CLI installation when it is absent; render every key the CLI reports as a form control; run apply and restore as permanent actions, plus the remaining CLI commands; stream command output; display the app version and the active CLI version.

Constraints:

- Never bundle, redistribute, fork, or recompile the Spicetify CLI, its Go packages, or its assets. The app is not a distributor of Spicetify.
- Never reimplement CLI behaviour. No config semantics, path resolution, extension discovery, or patching logic duplicated in the app. The app never filters extension or app files by format.
- Never auto-run a remote install script. Install options are shown per detected OS with the literal command visible, and execution requires an explicit click on that specific option.
- Never write `config-xpui.ini` directly when `spicetify config <key> <value>` can perform the change.
- Command execution uses argument arrays, never a shell string.
- Privileged operations, such as `chmod` on `/opt/spotify` or `/usr/share/spotify`, cannot be performed by the app. It surfaces the exact command for the user to run.
- Unofficial product. No Spicetify logo or wordmark assets.

Undecided: the exact update-detection heuristic for re-apply after a Spotify update.

## Brand Commitments

Name: Spicetify UI. Publicly described as an unofficial GUI. No Spicetify-owned visual assets. License MIT for the app itself, a choice the user delegated. A NOTICE file credits `spicetify/cli` under LGPL-2.1.

## Evidence on Hand

None. This is a greenfield repo with no existing code. Every CLI behaviour recorded above was verified on this machine against Spicetify 2.45.0 and Spotify 1.3.0.277. No screenshots, testimonials, or benchmarks exist, and future work must not fabricate them.

## Product Principles

1. The CLI is the source of truth. Ask it for versions, paths, and values; never duplicate its logic.
2. The app owns no Spicetify code and ships none of it. The LGPL boundary stays a boundary.
3. Nothing destructive happens without an explicit click that names what it does.
4. Portability comes from delegation, not from per-OS branching.
5. Terminal output is never hidden. The user can always see what the CLI actually said.

## Accessibility & Inclusion

Not yet established.