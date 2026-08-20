# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a monorepo for **media_kit**, a cross-platform audio/video player library for Flutter/Dart, built on top of **libmpv**. It uses [Melos](https://melos.invertase.dev/) for workspace management.

## This is a fork

`ister-app/media-kit` is the fork the Ister player pins, by commit sha, in its `pubspec.yaml`
(`media_kit`, `media_kit_video`, `media_kit_libs_*`) and `pubspec.lock`. Changing anything here
means: commit, push, then re-pin the sha in the player and run `flutter pub get` twice — the
pub-cache git mirror can otherwise serve a stale checkout.

### Divergences worth knowing

- **`libs/*` point at `ister-app` builds of libmpv**, not media-kit's:
  `libmpv-darwin-build` (macOS/iOS, tag `vX.Y.Z`), `libmpv-android-video-build` (jars by md5) and
  `libmpv-win32-video-cmake` (`mpv-dev-*.7z` by md5). Each of those repos has its own CLAUDE.md.
  They ship **mpv 0.41.0 with ffmpeg 9.0.1**; upstream media-kit is still on mpv 0.36, which
  predates `--video-crop`.
- Since mpv 0.41 links libplacebo and libass unconditionally, the darwin `Package.swift` files
  list extra binary targets (`Placebo`, and the libass font stack in the *audio* variants too).
  Forgetting one is a link error, not a runtime one.
- `media_kit_video`'s video controllers size the output from **`video-out-params`**, not
  `video-params`, so a server-set `video-crop` reaches the texture/surface. See below.

### Rules the video controllers depend on

- **Never do real work inside an `observeProperty` listener.** `NativePlayer` awaits those
  callbacks *inside* libmpv's single-threaded event pump; blocking there stalls every further mpv
  event, and anything waiting on a player command (which needs the pump) deadlocks. Schedule the
  work and return.
- **Read `*-params` as one snapshot.** mpv answers a single `video-out-params` read with the whole
  node as JSON. Fetching `video-out-params/dw` and `/dh` separately tears: mpv updates between the
  two reads, and the pair describes a size that never existed (a 960x1080 surface for a 960x540
  video), which then triggers an endless resize loop.
- **`video-out-params` is not always about your video.** With `--force-window` (the Android
  controller sets it) mpv keeps a 960x540 rgba placeholder around whenever nothing is on screen —
  including while your own resize re-initializes `--vo`. It describes the video only when its
  coded `w`/`h` match `video-params`; a crop changes `dw`/`dh`, never `w`/`h`. When they differ,
  keep the current size: falling back to `video-params` there pushes the *uncropped* size and
  bounces the surface between the two forever.
- Every surface resize re-initializes `--vo` and, with it, the decoder. Treat a resize as
  expensive and only do it on a real, verified size change.

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
