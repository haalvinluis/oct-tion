import 'package:flutter/services.dart';

class PlatformHelper {
  static const MethodChannel _orientationChannel =
      MethodChannel('com.auctiongame.mobile/orientation');
  static const MethodChannel _permissionChannel =
      MethodChannel('com.auctiongame.mobile/mic_permission');

  /// Forces the screen into horizontal landscape mode for the live auction arena.
  static Future<void> forceLandscape() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await _orientationChannel.invokeMethod('setLandscape');
    } catch (_) {}
  }

  /// Restores portrait mode for all other screens.
  static Future<void> forcePortrait() async {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await _orientationChannel.invokeMethod('setPortrait');
    } catch (_) {}
  }

  /// Checks if microphone permission has been granted natively.
  static Future<bool> checkMicPermission() async {
    try {
      final res = await _permissionChannel.invokeMethod<bool>('checkMicPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Requests runtime microphone permission from Android system dialog.
  static Future<bool> requestMicPermission() async {
    try {
      final res = await _permissionChannel.invokeMethod<bool>('requestMicPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
