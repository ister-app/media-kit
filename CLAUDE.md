# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a monorepo for **media_kit**, a cross-platform audio/video player library for Flutter/Dart, built on top of **libmpv**. It uses [Melos](https://melos.invertase.dev/) for workspace management.

## Package Structure

- **`media_kit/`** — Core player library (pure Dart + FFI). The primary package most changes will touch.
- **`media_kit_video/`** — Flutter video rendering widgets (`Video`, `VideoController`, controls).
- **`video_player_media_kit/`** — Drop-in `video_player` platform interface implementation.
- **`media_kit_test/`** — Example/test app that exercises all features across platforms.
- **`libs/`** — Platform-specific native library packages (Android, iOS, macOS, Windows, Linux) that bundle prebuilt libmpv binaries.

## Commands

All test commands run from within the `media_kit/` directory:

```bash
# Run all tests (Linux/macOS — requires libmpv installed)
cd media_kit && dart pub get && dart test

# Run web-only tests (no FFI)
cd media_kit && dart test --platform chrome

# Run a single test file
cd media_kit && dart test test/src/player/native/player_test.dart

# Build the test app (from media_kit_test/)
cd media_kit_test && flutter pub get && flutter build <platform>
# e.g.: flutter build apk --split-per-abi
#       flutter build linux
#       flutter build web --release
```

**Linux test prerequisites:**
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev mpv libmpv-dev
```

**macOS test prerequisites:**
```bash
# Uses a bundled dylib — see media_kit/test/ci/macos/scripts/setup_dylibs.sh
```

## Architecture

### Player stack

```
Player  (public API — media_kit/lib/src/player/player.dart)
  └─ PlatformPlayer  (abstract — platform_player.dart)
      ├─ NativePlayer  (Windows/macOS/Linux/Android/iOS)
      │   └─ media_kit/lib/src/player/native/player/real.dart  (~2000 lines)
      │       Uses FFI bindings: media_kit/lib/generated/libmpv/bindings.dart
      └─ WebPlayer  (Web/HTML5)
          └─ media_kit/lib/src/player/web/player/real.dart
```

`MediaKit.ensure()` must be called once at app startup to select the correct `PlatformPlayer` implementation.

### Key models (`media_kit/lib/src/models/`)

`Media`, `Playlist`, `PlayerState`, `PlayerStream`, `Track`, `AudioDevice`, `AudioParams`, `VideoParams`

`PlayerStream` exposes `Stream<T>` fields for reactive UI updates (position, duration, isPlaying, etc.).

### Video rendering (`media_kit_video/`)

`VideoController` manages the platform texture/surface lifecycle. The `Video` widget takes a `VideoController` and renders the frame. Controls (Material, Cupertino, adaptive) are layered on top.

### Platform-specific code pattern

Files use a **stub/real split**:
- `*_stub.dart` — no-op fallback imported on unsupported platforms
- `real.dart` — actual implementation

Platform selection uses conditional exports (`dart.library.js_interop` for web vs. native).

### FFI bindings

`media_kit/lib/generated/libmpv/bindings.dart` is **auto-generated** by `ffigen` from the libmpv C headers. Do not edit it manually — regenerate with `dart run ffigen` in `media_kit/`.

### Native library loading

On desktop, the native `.dll`/`.so`/`.dylib` is loaded at runtime via `DynamicLibrary.open()`. The `LIBMPV_LIBRARY_PATH` environment variable overrides the default search path (used in CI).

## Important Notes

- **Submodules**: The repo uses git submodules (`--submodules true` in CI). Run `git submodule update --init` after cloning.
- **Melos**: Workspace-level tasks use `melos exec`. Install with `dart pub global activate melos`.
- **No global lint script**: Each package lints independently via its own `analysis_options.yaml`.
- **Native tests require libmpv**: Tests under `test/src/player/native/` will fail without a libmpv binary present. Web tests skip these.
