/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/methods/video_state.dart';

import 'package:media_kit_video/media_kit_video_controls/src/controls/widgets/video_controls_theme_data_injector.dart';

/// Whether a [Video] present in the current [BuildContext] is in fullscreen or not.
bool isFullscreen(BuildContext context) =>
    FullscreenInheritedWidget.maybeOf(context) != null;

/// Makes the [Video] present in the current [BuildContext] enter fullscreen.
Future<void> enterFullscreen(BuildContext context) {
  return lock.synchronized(() async {
    if (!isFullscreen(context)) {
      if (context.mounted) {
        final stateValue = state(context);
        final contextNotifierValue = contextNotifier(context);
        final videoViewParametersNotifierValue =
            videoViewParametersNotifier(context);
        final controllerValue = controller(context);
        final player = controllerValue.player;
        final wasPlaying = player.state.playing;
        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => Material(
              child: VideoControlsThemeDataInjector(
                // NOTE: Make various *VideoControlsThemeData from the parent context available in the fullscreen context.
                context: context,
                child: VideoStateInheritedWidget(
                  state: stateValue,
                  contextNotifier: contextNotifierValue,
                  videoViewParametersNotifier: videoViewParametersNotifierValue,
                  disposeNotifiers: false,
                  child: FullscreenInheritedWidget(
                    parent: stateValue,
                    // Another [VideoStateInheritedWidget] inside [FullscreenInheritedWidget] is important to notify about the fullscreen [BuildContext].
                    child: VideoStateInheritedWidget(
                      state: stateValue,
                      contextNotifier: contextNotifierValue,
                      videoViewParametersNotifier:
                          videoViewParametersNotifierValue,
                      disposeNotifiers: false,
                      child: Video(
                        controller: controllerValue,
                        // Do not restrict the video's width & height in fullscreen mode:
                        width: null,
                        height: null,
                        fit: videoViewParametersNotifierValue.value.fit,
                        fill: videoViewParametersNotifierValue.value.fill,
                        alignment:
                            videoViewParametersNotifierValue.value.alignment,
                        aspectRatio:
                            videoViewParametersNotifierValue.value.aspectRatio,
                        filterQuality: videoViewParametersNotifierValue
                            .value.filterQuality,
                        controls:
                            videoViewParametersNotifierValue.value.controls,
                        // Do not acquire or modify existing wakelock in fullscreen mode:
                        wakelock: false,
                        pauseUponEnteringBackgroundMode:
                            stateValue.widget.pauseUponEnteringBackgroundMode,
                        resumeUponEnteringForegroundMode:
                            stateValue.widget.resumeUponEnteringForegroundMode,
                        subtitleViewConfiguration:
                            videoViewParametersNotifierValue
                                .value.subtitleViewConfiguration,
                        focusNode:
                            videoViewParametersNotifierValue.value.focusNode,
                        onEnterFullscreen: stateValue.widget.onEnterFullscreen,
                        onExitFullscreen: stateValue.widget.onExitFullscreen,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        await onEnterFullscreen(context)?.call();
        // On web, moving the <video> element in the DOM during the fullscreen
        // route transition can fire a browser 'pause' event, causing the player
        // state to flip to paused. Restore playback if this happened.
        if (wasPlaying && !player.state.playing) {
          await player.play();
        }
      }
    }
  });
}

/// Makes the [Video] present in the current [BuildContext] exit fullscreen.
Future<void> exitFullscreen(BuildContext context) {
  return lock.synchronized(() async {
    if (isFullscreen(context)) {
      if (context.mounted) {
        final player = controller(context).player;
        final wasPlaying = player.state.playing;
        await Navigator.of(context).maybePop();
        // It is known that this [context] will have a [FullscreenInheritedWidget] above it.
        if (context.mounted) {
          FullscreenInheritedWidget.of(context).parent.refreshView();
        }
        // On web, the route's full disposal moves the <video> element in the
        // DOM, which can fire a spurious browser 'pause' event across multiple
        // frames. Call play() now and watch the playing stream briefly to
        // re-play if a spurious pause arrives after the first frame.
        if (wasPlaying) {
          await WidgetsBinding.instance.endOfFrame;
          await player.play();
          StreamSubscription<bool>? sub;
          sub = player.stream.playing.listen((isPlaying) {
            if (!isPlaying) {
              sub?.cancel();
              sub = null;
              player.play();
            }
          });
          await Future.delayed(const Duration(milliseconds: 500));
          sub?.cancel();
        }
      }
      // [exitNativeFullscreen] is moved to [WillPopScope] in [FullscreenInheritedWidget].
      // This is because [exitNativeFullscreen] needs to be called when the user presses the back button.
    }
  });
}

/// Toggles fullscreen for the [Video] present in the current [BuildContext].
Future<void> toggleFullscreen(BuildContext context) {
  if (isFullscreen(context)) {
    return exitFullscreen(context);
  } else {
    return enterFullscreen(context);
  }
}

/// For synchronizing [enterFullscreen] & [exitFullscreen] operations.
final Lock lock = Lock();
