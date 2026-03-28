/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Registers a [fullscreenchange] listener on the browser document.
/// Calls [onExit] when the browser exits native fullscreen (e.g. via Escape).
/// Returns a cancel function that removes the listener.
VoidCallback listenForBrowserFullscreenExit(VoidCallback onExit) {
  late final web.EventListener listener;
  listener = (web.Event _) {
    if (web.document.fullscreenElement == null) {
      onExit();
    }
  }.toJS;
  web.document.addEventListener('fullscreenchange', listener);
  return () => web.document.removeEventListener('fullscreenchange', listener);
}
