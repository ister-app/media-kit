/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:safe_local_storage/safe_local_storage.dart';
import 'package:synchronized/synchronized.dart';

import 'package:media_kit/ffi/src/allocation.dart';
import 'package:media_kit/src/player/native/utils/temp_file.dart';
import 'package:media_kit/src/values.dart';

/// Callback invoked to notify about the released references.
typedef NativeReferenceHolderCallback = void Function(List<Pointer<Void>>);

/// {@template native_reference_holder}
///
/// NativeReferenceHolder
/// ---------------------
/// Holds references to [Pointer<generated.mpv_handle>]s created during the application runtime.
/// These references can be used to dispose the [Pointer<generated.mpv_handle>]s when they are no longer needed i.e. upon hot-restart or when a new isolate replaces the one that created them.
///
/// {@endtemplate}
class NativeReferenceHolder {
  /// Maximum number of references that can be held.
  static const int kReferenceBufferSize = 512;

  /// Prefix shared by every reference buffer file.
  static const String kFilePrefix =
      'com.alexmercerind.media_kit.NativeReferenceHolder.';

  /// Singleton instance.
  static final NativeReferenceHolder instance = NativeReferenceHolder._();

  /// Whether the [instance] is initialized.
  static bool initialized = false;

  /// {@macro native_reference_holder}
  NativeReferenceHolder._();

  /// Initializes the instance.
  static void ensureInitialized(NativeReferenceHolderCallback callback) {
    if (!kDebugMode && !_releaseCleanupSupported) return;
    if (initialized) return;
    initialized = true;
    instance._ensureInitialized(callback);
  }

  /// Whether leaked handles are cleaned up in profile/release mode as well.
  ///
  /// On Android the OS process routinely outlives the isolate that created
  /// the handles: a foreground service (or a recreated Activity) keeps the
  /// process alive while the engine is torn down & a new isolate runs `main()`
  /// again. Every `NativeCallable` trampoline dies with that isolate, but the
  /// [Pointer<generated.mpv_handle>]s it created keep running with the — now
  /// dangling — wakeup callback still registered. The next time libmpv wakes
  /// that client (any event; in practice a log message forwarded from ffmpeg's
  /// demuxer thread) it jumps into freed memory & the process dies with
  /// SIGSEGV. Running the cleanup from the next `main()` is the only chance to
  /// clear those callbacks.
  ///
  /// Every other platform ties the process to the app's lifetime, so there is
  /// nothing left behind to clean up — and [_processToken], which is what makes
  /// locating a buffer from *this* process safe, is unavailable there.
  static bool get _releaseCleanupSupported => Platform.isAndroid;

  void _ensureInitialized(NativeReferenceHolderCallback callback) async {
    final token = _processToken;
    final located = await _locateReferenceBuffer(token);
    if (located == null) {
      // Allocate reference buffer.
      _referenceBuffer = calloc<IntPtr>(kReferenceBufferSize);
      final address = _referenceBuffer.address;
      await _file.write_('$address:$token');
      print('$kTag Allocated $address');
    } else {
      // Locate reference buffer.
      _referenceBuffer = Pointer<IntPtr>.fromAddress(located);
      print('$kTag Located $located');
    }

    final references = <Pointer<Void>>[];

    for (int i = 0; i < kReferenceBufferSize; i++) {
      final referencePtr = _referenceBuffer + i;
      final referenceAddress = referencePtr.value;
      referencePtr.value = 0;
      if (referenceAddress != 0) {
        references.add(Pointer.fromAddress(referenceAddress));
      }
    }

    callback(references);

    _completer.complete();

    unawaited(_pruneStaleFiles());
  }

  /// Address of a reference buffer that was allocated earlier *by this very
  /// process*, or `null` when there is none.
  ///
  /// The file name carries the pid, which the OS reuses: a file written by a
  /// previous process that happened to get the same pid points at an address
  /// that means nothing here, and walking it would dereference a wild pointer.
  /// [_processToken] tells the two apart.
  Future<int?> _locateReferenceBuffer(String token) async {
    if (!await _file.exists_()) return null;
    final contents = (await _file.readAsString_())?.trim() ?? '';
    final separator = contents.indexOf(':');
    if (separator == -1) return null;
    if (contents.substring(separator + 1) != token) {
      print('$kTag Discarding reference buffer of an earlier process.');
      return null;
    }
    return int.tryParse(contents.substring(0, separator));
  }

  /// A value unique to this OS process, used to recognise a reference buffer
  /// file left behind by an earlier process with the same pid.
  ///
  /// Linux & Android expose the process start time (in clock ticks since boot)
  /// as field 22 of `/proc/self/stat`, which is exactly that. Elsewhere the pid
  /// in the file name has to do on its own — same as before this existed.
  static String get _processToken {
    if (!Platform.isAndroid && !Platform.isLinux) return '';
    try {
      final stat = File('/proc/self/stat').readAsStringSync();
      // The comm field may itself contain spaces & brackets, so start parsing
      // past the last ')' instead of splitting the whole line.
      final fields =
          stat.substring(stat.lastIndexOf(')') + 1).trim().split(' ');
      // fields[0] is field 3 (state), so field 22 (starttime) sits at index 19.
      return fields[19];
    } catch (_) {
      return '';
    }
  }

  /// Deletes reference buffer files left behind by processes that are long
  /// gone. They are tiny, but one is written per process launch & nothing else
  /// ever removes them. Recent ones are kept: another instance of the app may
  /// still be running against one.
  Future<void> _pruneStaleFiles() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final name = path.basename(_file.path);
      await for (final entity
          in Directory(TempFile.directory).list(followLinks: false)) {
        if (entity is! File) continue;
        final basename = path.basename(entity.path);
        if (!basename.startsWith(kFilePrefix)) continue;
        if (basename == name) continue;
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
      }
    } catch (_) {
      // Housekeeping: a file we may not touch is not worth failing startup for.
    }
  }

  /// Saves the reference.
  Future<void> add(Pointer reference) async {
    if (!initialized) return;
    if (reference == nullptr) return;
    await _completer.future;
    return _lock.synchronized(() async {
      for (int i = 0; i < kReferenceBufferSize; i++) {
        final referenceValue = _referenceBuffer + i;
        final referencePtr = Pointer.fromAddress(referenceValue.value);
        // NOTE: Do not compare .value with .address. Bad things may happen on 32-bit systems.
        if (referencePtr.address == 0) {
          referenceValue.value = reference.address;
          break;
        }
      }
    });
  }

  /// Removes the reference.
  Future<void> remove(Pointer reference) async {
    if (!initialized) return;
    if (reference == nullptr) return;
    await _completer.future;
    return _lock.synchronized(() async {
      for (int i = 0; i < kReferenceBufferSize; i++) {
        final referenceValue = _referenceBuffer + i;
        final referencePtr = Pointer.fromAddress(referenceValue.value);
        // NOTE: Do not compare .value with .address. Bad things may happen on 32-bit systems.
        if (referencePtr.address == reference.address) {
          referenceValue.value = 0;
          break;
        }
      }
    });
  }

  /// [Lock] used to synchronize access to the reference buffer.
  final Lock _lock = Lock();

  /// [Completer] used to wait for the reference buffer to be allocated.
  final Completer<void> _completer = Completer<void>();

  /// [File] used to store [int] address to the reference buffer.
  /// This is necessary to have a persistent to the reference buffer across hot-restarts.
  final File _file = File(
    path.join(
      TempFile.directory,
      '$kFilePrefix$pid',
    ),
  );

  /// [Pointer] to the reference buffer.
  late final Pointer<IntPtr> _referenceBuffer;

  static const String kTag = 'media_kit: NativeReferenceHolder:';
}
