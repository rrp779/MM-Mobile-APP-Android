import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Service for managing Shorebird Over-The-Air (OTA) updates.
///
/// Update strategy: MANUAL. `shorebird.yaml` sets `auto_update: false`, so the
/// engine never checks on its own; this service is the single owner of
/// check -> download -> "restart required". A downloaded patch is applied by
/// the Shorebird engine on the next cold start of the app.
///
/// Logs use `debugPrint` with an `[OTA]` prefix so they also appear in release
/// builds (Shorebird only works in release builds):
///   Android: `adb logcat | grep "\[OTA\]"`
///   iOS:     Xcode > Devices > Open Console (or Console.app), filter `[OTA]`
class OtaService {
  static final OtaService _instance = OtaService._internal();
  factory OtaService() => _instance;
  OtaService._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Minimum gap between checks triggered by the app returning to foreground.
  static const Duration _minCheckInterval = Duration(minutes: 30);

  Future<void>? _inFlight;
  DateTime? _lastCheck;

  /// Becomes true once a patch has been downloaded and needs an app restart.
  final ValueNotifier<bool> restartRequired = ValueNotifier<bool>(false);

  /// Whether the app was built with the Shorebird updater engine.
  bool get isShorebirdAvailable => _updater.isAvailable;

  /// Check for, and download, a new patch.
  ///
  /// Safe to call repeatedly: overlapping calls share one in-flight check, and
  /// when [force] is false calls within [_minCheckInterval] are skipped.
  Future<void> checkForUpdates({bool force = true}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final last = _lastCheck;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minCheckInterval) {
      return Future.value();
    }

    _lastCheck = DateTime.now();
    final future = _runCheck().whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<void> _runCheck() async {
    _log('Platform: ${Platform.operatingSystem}, release mode: $kReleaseMode');

    if (!isShorebirdAvailable) {
      _log('Shorebird updater UNAVAILABLE. This build was not made with '
          '`shorebird release`/`shorebird preview` (or is a debug build), '
          'so it cannot receive OTA patches.');
      return;
    }
    _log('Shorebird updater available.');

    try {
      final current = await _updater.readCurrentPatch();
      final next = await _updater.readNextPatch();
      _log(
          'Current patch: ${_describe(current)}, next patch: ${_describe(next)}');

      if (_isNewer(next, current)) {
        _log('Patch ${_describe(next)} already downloaded; restart required.');
        _markRestartRequired();
        return;
      }

      final status = await _updater.checkForUpdate();
      _log('Update status: ${status.name}');

      switch (status) {
        case UpdateStatus.outdated:
          _log('New patch available. Downloading...');
          await _updater.update();
          final downloaded = await _updater.readNextPatch();
          _log('Download complete: ${_describe(downloaded)}. '
              'It will be applied on next app restart.');
          if (downloaded?.number != current?.number) {
            _markRestartRequired();
          } else {
            _log('No different patch was staged after download.');
          }
        case UpdateStatus.restartRequired:
          _log('Patch already downloaded; restart required.');
          _markRestartRequired();
        case UpdateStatus.upToDate:
          _log('App is up to date.');
        case UpdateStatus.unavailable:
          _log('Update status unavailable.');
      }
    } on UpdateException catch (e) {
      _log('Update failed (${e.reason.name}): ${e.message}');
    } on ReadPatchException catch (e) {
      _log('Failed to read patch info: ${e.message}');
    } catch (e, st) {
      _log('Unexpected error during update check: $e\n$st');
    }
  }

  /// Get current patch number if applied.
  Future<int?> getCurrentPatchNumber() async {
    if (!isShorebirdAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      _log('Failed to read current patch number: $e');
      return null;
    }
  }

  void _markRestartRequired() {
    restartRequired.value = true;
  }

  static bool _isNewer(Patch? next, Patch? current) {
    if (next == null) return false;
    return current == null || next.number > current.number;
  }

  static String _describe(Patch? patch) =>
      patch == null ? 'none (base release)' : '#${patch.number}';

  static void _log(String message) => debugPrint('[OTA] $message');
}
