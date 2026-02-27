# codex-app.nix

> [!WARNING]
> DANGER: This package is currently experimental and **not thoroughly tested yet**.

This repository provides a minimal Nix flake for packaging the Codex desktop app on Linux (`x86_64-linux`).

The packaging logic lives in `package.nix`:

- `package.nix`

## How it works

At build time, the package process in `package.nix` does the following:

- Fetches a version-pinned Codex macOS release ZIP (`Codex-darwin-arm64-<version>.zip`) published via the appcast channel.
- Extracts the app payload (`app.asar` and `app.asar.unpacked`) from that archive.
- Unpacks the Electron application archive.
- Uses a Linux Electron 40 runtime.
- Rebuilds native modules (`better-sqlite3`, `node-pty`) for Linux.
- Replaces macOS-only pieces (`sparkle`, `electron-liquid-glass`) with Linux-safe stubs.
- Creates the `codex-app` launcher.
- Installs a desktop entry (`codex-app.desktop`) for graphical environments.

This improves reproducibility compared to the moving `Codex.dmg` URL, because the source file name includes the exact app version and is hash-pinned in Nix.

## Flake outputs

The flake exports `codex-app` as a package for `x86_64-linux` (and as the default package), plus a default app entry that points to the `codex-app` launcher.

## Updating

You can check for a new upstream release and auto-update `package.nix` with:

- `nix run .#update`

The update app reads the official appcast feed, picks the latest release entry, computes the new Nix SRI hash, and patches `codexVersion` plus the source hash in `package.nix`.
