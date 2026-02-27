# codex-app.nix

> [!WARNING]
> DANGER: This package is currently experimental and **not thoroughly tested yet**.

This repository provides a minimal Nix flake for packaging the Codex desktop app on Linux (`x86_64-linux`).

The packaging logic lives in `package.nix`:

- `package.nix`

## How it works

At build time, the package process in `package.nix` does the following:

- Fetches the official Codex DMG.
- Extracts the app payload (`app.asar` and `app.asar.unpacked`) with 7zip.
- Unpacks the Electron application archive.
- Uses a Linux Electron 40 runtime.
- Rebuilds native modules (`better-sqlite3`, `node-pty`) for Linux.
- Replaces macOS-only pieces (`sparkle`, `electron-liquid-glass`) with Linux-safe stubs.
- Creates the `codex-app` launcher.
- Installs a desktop entry (`codex-app.desktop`) for graphical environments.

## Flake outputs

The flake exports `codex-app` as a package for `x86_64-linux` (and as the default package), plus a default app entry that points to the `codex-app` launcher.
