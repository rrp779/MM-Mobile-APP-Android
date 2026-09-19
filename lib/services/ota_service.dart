import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Service for managing Shorebird Over-The-Air (OTA) updates.
///
/// Automatically checks for new patches from Shorebird CDN on startup,
/// downloads them silently in the background, and prepares them for
/// instant activation on next app launch.
class OtaService {
  static final OtaService _instance = OtaService._internal();
  factory OtaService() => _instance;
  OtaService._internal();

  final ShorebirdUpdater _updater = ShorebirdUpdater();

  /// Whether the app was built with the Shorebird updater engine.
  bool get isShorebirdAvailable => _updater.isAvailable;

  /// Check for and download updates in the background.
  Future<void> checkForUpdates() async {
    try {
      if (!isShorebirdAvailable) {
        if (kDebugMode) {
          debugPrint('[OTA] Shorebird engine not detected (standard local build).');
        }
        return;
      }

      final currentPatch = await _updater.readCurrentPatch();
      if (kDebugMode) {
        final patchNum = currentPatch?.number;
        final patchText = patchNum != null ? '#$patchNum' : 'Base Release';
        debugPrint('[OTA] Current installed patch: $patchText');
      }

      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        if (kDebugMode) {
          debugPrint('[OTA] New patch available! Downloading in background...');
        }
        await _updater.update();
        if (kDebugMode) {
          debugPrint('[OTA] Patch downloaded successfully. It will apply on next restart.');
        }
      } else if (status == UpdateStatus.restartRequired) {
        if (kDebugMode) {
          debugPrint('[OTA] Patch already downloaded and ready. Restart required to apply.');
        }
      } else if (status == UpdateStatus.upToDate) {
        if (kDebugMode) {
          debugPrint('[OTA] App is already on the latest patch.');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OTA] Error checking for OTA updates: $e');
      }
    }
  }

  /// Get current patch number if applied.
  Future<int?> getCurrentPatchNumber() async {
    if (!isShorebirdAvailable) return null;
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (_) {
      return null;
    }
  }
}
