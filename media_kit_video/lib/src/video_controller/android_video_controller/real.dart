/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/utils/query_decoders.dart';
import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';

/// {@template android_video_controller}
///
/// AndroidVideoController
/// ----------------------
///
/// The [PlatformVideoController] implementation based on native JNI & C/C++ used on Android.
///
/// {@endtemplate}
class AndroidVideoController extends PlatformVideoController {
  /// Whether [AndroidVideoController] is supported on the current platform or not.
  static bool get supported => Platform.isAndroid;

  /// Pointer address to the global object reference of `android.view.Surface` i.e. `(intptr_t)(*android.view.Surface)`.
  final ValueNotifier<int?> wid = ValueNotifier<int?>(null);

  /// Whether the SurfaceView output currently drives rendering. Constant when
  /// [VideoControllerConfiguration.androidSurfaceView] is plainly on or off;
  /// toggled by fullscreen enter/exit in the fullscreen-only (dual) mode.
  final ValueNotifier<bool> surfaceViewActive = ValueNotifier<bool>(false);

  /// Last known texture output (id + surface pointer), kept while the
  /// SurfaceView output is active so switching back is immediate.
  int? _textureId;
  int _textureWid = 0;

  /// Last known SurfaceView output surface pointer.
  int _surfaceViewWid = 0;

  /// `--vo` for the currently active output; overrides [configuration.vo]
  /// after a runtime mode switch (that field is immutable).
  String? _voOverride;

  bool get _dualMode =>
      configuration.androidSurfaceView &&
      configuration.androidSurfaceViewFullscreenOnly;

  /// The texture id to render when the texture output is active. [id] itself
  /// is `-1` while the SurfaceView output drives rendering.
  int? get textureId => _textureId;

  /// [Lock] used to synchronize [onLoadHooks], [onUnloadHooks] & [subscription].
  final lock = Lock();

  NativePlayer get platform => player.platform as NativePlayer;

  Future<void> setProperty(String key, String value) async {
    await platform.setProperty(key, value, waitForInitialization: false);
  }

  Future<void> setProperties(Map<String, String> properties) async {
    for (final entry in properties.entries) {
      await setProperty(entry.key, entry.value);
    }
  }

  /// Listener for updating the --wid property.
  Future<void> widListener() {
    return lock.synchronized(() async {
      final width = rect.value?.width.toInt() ?? 1;
      final height = rect.value?.height.toInt() ?? 1;
      final androidSurfaceSizeValue = [width, height].join('x');
      final widValue = wid.value?.toString() ?? '0';
      // When --wid is 0, vo=null is required to avoid SIGSEGV.
      final voValue = widValue == '0' ? 'null' : (_voOverride ?? configuration.vo!);
      final vidValue = widValue == '0' ? 'no' : 'auto';
      // It is important to re-initialize --vo after --android-surface-size.
      await setProperty('vo', 'null');
      await setProperties(
        {
          // ORDER IS IMPORTANT.
          'android-surface-size': androidSurfaceSizeValue,
          'wid': widValue,
          'vo': voValue,
          // It is important to re-initialize --vid in-case of --vo=mediacodec_embed.
          // Not doing so causes error "Could not open codec." & video never gets rendered.
          if (configuration.vo == 'mediacodec_embed') 'vid': vidValue,
        },
      );
      // Instead of seeking to the start (Duration.zero), seek to the current playback position
      // without jumping the user to the start of the media.
      final currentPosition = player.state.position;
      await player.seek(currentPosition);
    });
  }

  /// mpv properties for the texture (GL, tone-mapped) output.
  static const _textureModeProperties = {
    'opengl-es': 'yes',
    'gpu-context': 'android',
    'target-colorspace-hint': 'no',
  };

  /// mpv properties for the SurfaceView (Vulkan, HDR passthrough) output.
  /// `opengl-es` is left untouched: it only affects GL context creation,
  /// which this mode does not use.
  static const _surfaceViewModeProperties = {
    'gpu-context': 'androidvk',
    'target-colorspace-hint': 'yes',
  };

  /// Fullscreen hook for the dual (fullscreen-only) mode: switches mpv
  /// between the texture output (embedded, tone-mapped SDR) and the
  /// SurfaceView output (fullscreen, HDR passthrough). No-op otherwise.
  Future<void> onFullscreenChanged(bool fullscreen) async {
    if (!_dualMode) return;
    if (surfaceViewActive.value == fullscreen) return;
    surfaceViewActive.value = fullscreen;
    // Detach mpv from the old surface before re-configuring: the properties
    // below change the GPU context, which only takes effect on vo re-init.
    await lock.synchronized(() async {
      await setProperty('vo', 'null');
      // configuration.hwdec is the emulator-aware texture-path default; the
      // SurfaceView path needs the copy-back decoder (see create).
      final baseHwdec = configuration.hwdec!;
      await setProperties({
        'hwdec': fullscreen
            ? (baseHwdec == 'no' ? 'no' : 'mediacodec-copy')
            : baseHwdec,
        ...(fullscreen ? _surfaceViewModeProperties : _textureModeProperties),
      });
      _voOverride = fullscreen ? 'gpu-next' : 'gpu';
    });
    // Hand the stored surface of the target output to mpv. On the first
    // fullscreen entry the SurfaceView surface does not exist yet (0) — its
    // platform view mounts right after this and delivers the wid through
    // VideoOutput.Resize.
    if (fullscreen) {
      id.value = -1;
      wid.value = _surfaceViewWid;
    } else {
      id.value = _textureId;
      wid.value = _textureWid;
    }
  }

  /// [StreamSubscription] for listening to video [Rect].
  StreamSubscription<VideoParams>? videoParamsSubscription;

  /// {@macro android_video_controller}
  AndroidVideoController._(
    super.player,
    super.configuration,
  ) {
    wid.addListener(widListener);
    videoParamsSubscription = player.stream.videoParams.listen(
      (event) => _refreshSurfaceSize(fallback: event),
    );
  }

  /// Pushes the video output's size to the native side (the `android.view.Surface`
  /// mpv renders into).
  ///
  /// The size is read from `video-out-params` — the output size *after*
  /// filters, rotation metadata and any `video-crop` — not from
  /// `video-params` ([fallback], the decoded size), which knows nothing about
  /// cropping: sizing the surface from it letterboxes a cropped video back
  /// into the uncropped aspect. `video-out-params` is also observed (see
  /// [_observeVideoOutParams]) because a `video-crop` set after the load emits
  /// no [VideoParams] event.
  Future<void> _refreshSurfaceSize({VideoParams? fallback}) =>
      lock.synchronized(() async {
        final (outParams, mayFallBack) = await _readVideoOutParams();
        if (outParams == null && !mayFallBack) return;
        int? dw, dh, rotate;
        if (outParams != null) {
          (dw, dh, rotate) = outParams;
        } else {
          fallback ??= player.state.videoParams;
          dw = fallback?.dw;
          dh = fallback?.dh;
          rotate = fallback?.rotate ?? 0;
        }

        final int width;
        final int height;
        if (rotate == 0 || rotate == 180) {
          width = dw ?? 0;
          height = dh ?? 0;
        } else {
          // width & height are swapped for 90 or 270 degrees rotation.
          width = dh ?? 0;
          height = dw ?? 0;
        }

        final isZero = width == 0 || height == 0;
        // The surface is only re-created on an actual size change: every
        // resize also re-initializes --vo through [widListener] and seeks to
        // the current position.
        final isSame = width == rect.value?.width.toInt() &&
            height == rect.value?.height.toInt();
        if (isZero || isSame) {
          return;
        }

        final handle = await player.handle;

        await _channel.invokeMethod(
          'VideoOutputManager.SetSurfaceSize',
          {
            'handle': handle.toString(),
            'width': width.toString(),
            'height': height.toString(),
          },
        );

        rect.value = Rect.fromLTWH(
          0.0,
          0.0,
          width.toDouble(),
          height.toDouble(),
        );

        if (!waitUntilFirstFrameRenderedCompleter.isCompleted) {
          waitUntilFirstFrameRenderedCompleter.complete();
        }
      });


  /// Reads `dw`/`dh`/`rotate` from `video-out-params` in a *single* property
  /// fetch, which mpv answers with the whole node as JSON.
  ///
  /// Fetching `video-out-params/dw` and `/dh` separately can tear: mpv may
  /// update between the two reads, which yields a size that never existed
  /// (a 960x1080 surface for a 960x540 video). Every such bogus size triggers
  /// a surface resize, which re-initializes the video output, which produces
  /// new parameters — an endless resize loop that never renders a frame.
  /// The output size to give the video output, or null to leave it alone.
  ///
  /// Returns `(null, true)` while the size is simply not known yet, so the
  /// caller can fall back to [VideoParams]; `(null, false)` when the video
  /// output is busy showing something that is not our video.
  Future<((int, int, int)?, bool)> _readVideoOutParams() async {
    try {
      final decoded = await _readParams('video-params');
      // Nothing is decoding: all mpv can report is the --force-window
      // placeholder, so there is no size worth pushing.
      if (decoded == null) return (null, false);
      final out = await _readParams('video-out-params');
      if (out == null) return (null, true);
      // The video output also renders mpv's --force-window placeholder (a
      // 960x540 rgba frame) whenever nothing is on screen — including the
      // moment our own resize re-initializes --vo — and reports *that* through
      // `video-out-params`. It describes our video only when the coded
      // dimensions match; a crop changes dw/dh, never w/h. Falling back to
      // [VideoParams] here would push the *uncropped* size and bounce the
      // surface between the two forever.
      if (out['w'] != decoded['w'] || out['h'] != decoded['h']) {
        return (null, false);
      }
      int asInt(Object? v) => v is num ? v.toInt() : 0;
      return ((asInt(out['dw']), asInt(out['dh']), asInt(out['rotate'])), false);
    } catch (_) {
      return (null, true);
    }
  }

  /// Reads one of mpv's `*-params` node properties, which it answers as JSON.
  /// Null when the property is empty, which is what it reports while nothing
  /// is decoding.
  Future<Map?> _readParams(String property) async {
    final raw = await platform.getProperty(
      property,
      waitForInitialization: false,
    );
    if (raw.isEmpty) return null;
    final map = json.decode(raw);
    return map is Map && map['w'] is num && (map['w'] as num) > 0 ? map : null;
  }

  /// Property observed for output-size changes that emit no [VideoParams]
  /// event (e.g. setting `video-crop` during playback).
  static const _observedOutParams = ['video-out-params'];

  Future<void> _observeVideoOutParams() async {
    for (final property in _observedOutParams) {
      await platform.observeProperty(
        property,
        // The listener is awaited *inside* libmpv's event pump, which
        // processes one event at a time. Refreshing here would block every
        // further mpv event for as long as [_refreshSurfaceSize] waits on
        // [lock] — and [widListener] holds that lock while it awaits player
        // commands that only complete once the pump runs again. Schedule the
        // refresh and return immediately instead.
        (_) async => unawaited(_refreshSurfaceSize()),
        // This runs during VideoController creation; waiting on the video
        // controller's own initialization would deadlock.
        waitForInitialization: false,
      );
    }
  }

  /// Whether `container-fps` is being observed (SurfaceView mode only).
  bool _observingContainerFps = false;

  /// Last frame rate pushed to the platform side, to dedupe the property
  /// observer's re-emissions (every --vo re-init re-reports the same value).
  double? _lastPushedFps;

  /// Observes the content frame rate and forwards it to the SurfaceView's
  /// `Surface.setFrameRate`, so Android can switch the display to a matching
  /// refresh rate (e.g. 23.976 Hz for film content).
  Future<void> _observeContainerFps() async {
    _observingContainerFps = true;
    await platform.observeProperty(
      'container-fps',
      // Do not await inside libmpv's event pump — see [_observeVideoOutParams].
      (value) async => unawaited(_pushFrameRate(value)),
      waitForInitialization: false,
    );
  }

  Future<void> _pushFrameRate(String value) async {
    final parsed = double.tryParse(value) ?? 0.0;
    final fps = parsed.isFinite && parsed > 0 ? parsed : 0.0;
    if (fps == _lastPushedFps) return;
    _lastPushedFps = fps;
    try {
      final handle = await player.handle;
      await _channel.invokeMethod(
        'VideoOutputManager.SetFrameRate',
        {
          'handle': handle.toString(),
          'fps': fps.toString(),
        },
      );
    } catch (exception) {
      debugPrint(exception.toString());
    }
  }

  /// {@macro android_video_controller}
  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    Future<String> getDefaultHwdec() async {
      // Enforce software rendering in emulators.
      bool hw = configuration.enableHardwareAcceleration;
      final bool isEmulator = await _channel.invokeMethod('Utils.IsEmulator');
      if (isEmulator) {
        hw = false;
        debugPrint('media_kit: Emulator detected.');
        debugPrint('media_kit: Enforcing S/W rendering.');
      }
      return hw ? 'auto-safe' : 'no';
    }

    // In the fullscreen-only (dual) mode playback starts on the texture path;
    // fullscreen enter/exit switches outputs at runtime.
    final startInSurfaceView = configuration.androidSurfaceView &&
        !configuration.androidSurfaceViewFullscreenOnly;

    // Update [configuration] to have default values.
    //
    // The SurfaceView path renders through vo=gpu-next on a Vulkan context:
    // --target-colorspace-hint (HDR passthrough) only exists on gpu-next, and
    // only libplacebo's Vulkan swapchain implements it — the GL swapchain
    // ignores the hint entirely.
    configuration = configuration.copyWith(
      vo: configuration.vo ?? (startInSurfaceView ? 'gpu-next' : 'gpu'),
      hwdec: configuration.hwdec ??
          (startInSurfaceView
              // The direct mediacodec interop (hwdec_aimagereader) is GL-only;
              // on the Vulkan context used by the SurfaceView path only the
              // copy-back variant works — hardware decode into system memory,
              // Vulkan upload.
              ? (configuration.enableHardwareAcceleration
                  ? 'mediacodec-copy'
                  : 'no')
              : await getDefaultHwdec()),
    );

    // Retrieve the native handle of the [Player].
    final handle = await player.handle;
    // Return the existing [VideoController] if it's already created.
    if (_controllers.containsKey(handle)) {
      return _controllers[handle]!;
    }

    // In case no video-decoders are found, this means media_kit_libs_***_audio is being used.
    // Thus, --vid=no is required to prevent libmpv from trying to decode video (otherwise bad things may happen).
    //
    // Search for common H264 decoder to check if video support is available.
    final decoders = await queryDecoders(handle);
    if (!decoders.contains('h264')) {
      throw UnsupportedError(
        '[VideoController] is not available.'
        ' '
        'Please use media_kit_libs_***_video instead of media_kit_libs_***_audio.',
      );
    }

    // Creation:
    final controller = AndroidVideoController._(
      player,
      configuration,
    );

    // Register [_dispose] for execution upon [Player.dispose].
    player.platform?.release.add(controller._dispose);

    // Store the [VideoController] in the [_controllers].
    _controllers[handle] = controller;

    controller.surfaceViewActive.value = startInSurfaceView;

    // Dual mode registers *both* outputs: the texture output renders embedded
    // playback, the SurfaceView output takes over in fullscreen.
    if (!configuration.androidSurfaceView || controller._dualMode) {
      await _channel.invokeMethod(
        'VideoOutputManager.Create',
        {
          'handle': handle.toString(),
          'surfaceView': false,
        },
      );
    }
    if (configuration.androidSurfaceView) {
      await _channel.invokeMethod(
        'VideoOutputManager.Create',
        {
          'handle': handle.toString(),
          'surfaceView': true,
        },
      );
    }

    await controller.setProperties(
      {
        // It is necessary to set vo=null here to avoid SIGSEGV, --wid must be assigned before vo=gpu is set.
        'vo': 'null',
        'hwdec': configuration.hwdec!,
        'vid': 'auto',
        ...(startInSurfaceView
            ? _surfaceViewModeProperties
            : _textureModeProperties),
        'force-window': 'yes',
        'sub-use-margins': 'no',
        'sub-font-provider': 'none',
        'sub-scale-with-window': 'yes',
        'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
      },
    );

    await controller._observeVideoOutParams();
    if (configuration.androidSurfaceView &&
        configuration.androidMatchContentFrameRate) {
      await controller._observeContainerFps();
    }

    // Return the [PlatformVideoController].
    return controller;
  }

  /// Sets the required size of the video output.
  /// This may yield substantial performance improvements if a small [width] & [height] is specified.
  ///
  /// Remember:
  /// * “Premature optimization is the root of all evil”
  /// * “With great power comes great responsibility”
  @override
  Future<void> setSize({
    int? width,
    int? height,
  }) {
    throw UnsupportedError(
      '[AndroidVideoController.setSize] is not available on Android',
    );
  }

  /// Disposes the instance. Releases allocated resources back to the system.
  Future<void> _dispose() async {
    super.dispose();
    surfaceViewActive.dispose();
    wid.dispose();
    wid.removeListener(widListener);
    await videoParamsSubscription?.cancel();
    for (final property in [
      ..._observedOutParams,
      if (_observingContainerFps) 'container-fps',
    ]) {
      try {
        await platform.unobserveProperty(property,
            waitForInitialization: false);
      } catch (_) {
        // Player may already be disposed; unobserving is best-effort.
      }
    }
    final handle = await player.handle;
    _controllers.remove(handle);
    await _channel.invokeMethod(
      'VideoOutputManager.Dispose',
      {
        'handle': handle.toString(),
      },
    );
  }

  /// Currently created [AndroidVideoController]s.
  static final _controllers = HashMap<int, AndroidVideoController>();

  /// [MethodChannel] for invoking platform specific native implementation.
  static final _channel =
      const MethodChannel('com.alexmercerind/media_kit_video')
        ..setMethodCallHandler(
          (MethodCall call) async {
            try {
              debugPrint(call.method.toString());
              debugPrint(call.arguments.toString());
              switch (call.method) {
                case 'VideoOutput.Resize':
                  {
                    // Notify about updated texture ID & [Rect].
                    final int handle = call.arguments['handle'];
                    final Rect rect = Rect.fromLTWH(
                      call.arguments['rect']['left'] * 1.0,
                      call.arguments['rect']['top'] * 1.0,
                      call.arguments['rect']['width'] * 1.0,
                      call.arguments['rect']['height'] * 1.0,
                    );
                    final int id = call.arguments['id'];
                    final int wid = call.arguments['wid'];
                    final controller = _controllers[handle];
                    if (controller == null) break;
                    // id == -1 marks the SurfaceView output. Both outputs
                    // exist at once in dual mode: always store, but only the
                    // active output may drive mpv (wid) and the widget.
                    final bool fromSurfaceView = id == -1;
                    if (fromSurfaceView) {
                      controller._surfaceViewWid = wid;
                    } else {
                      controller._textureId = id;
                      controller._textureWid = wid;
                    }
                    if (fromSurfaceView == controller.surfaceViewActive.value) {
                      controller.rect.value = rect;
                      controller.id.value = id;
                      controller.wid.value = wid;
                    }
                    break;
                  }
                case 'VideoOutput.WaitUntilFirstFrameRenderedNotify':
                  {
                    // Notify about updated texture ID & [Rect].
                    final int handle = call.arguments['handle'];
                    debugPrint(handle.toString());
                    // Notify about the first frame being rendered.
                    final completer = _controllers[handle]
                        ?.waitUntilFirstFrameRenderedCompleter;
                    if (!(completer?.isCompleted ?? true)) {
                      completer?.complete();
                    }
                    break;
                  }
                default:
                  {
                    break;
                  }
              }
            } catch (exception, stacktrace) {
              debugPrint(exception.toString());
              debugPrint(stacktrace.toString());
            }
          },
        );
}
