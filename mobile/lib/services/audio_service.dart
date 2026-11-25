import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'settings_service.dart';

enum SfxType {
  buttonClick,
  playerJoin,
  auctionStart,
  itemAnnounced,
  bidAccepted,
  highestBidder,
  outbid,
  timerWarning,
  itemSold,
  itemUnsold,
  matchVictory,
  matchTie,
  error,
}

class AudioService with WidgetsBindingObserver {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const MethodChannel _soundChannel =
      MethodChannel('com.auctiongame.mobile/sound');

  final Map<SfxType, DateTime> _lastPlayedMap = {};
  static const int _dedupWindowMs = 200;
  bool _isForeground = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _isForeground = false;
      stopAllSounds();
    } else if (state == AppLifecycleState.resumed) {
      _isForeground = true;
    }
  }

  /// Immediately stop all ongoing audio and sound effects
  void stopAllSounds() {
    try {
      _soundChannel.invokeMethod('stopAllSound');
    } catch (_) {}
  }

  /// Play SFX with audio preference checks and deduplication filter.
  void playSfx(SfxType type) {
    if (!_isForeground) return;
    final settings = SettingsService();

    // Check audio preferences
    if (!settings.masterSound || !settings.sfxEnabled || settings.masterVolume <= 0) {
      return;
    }

    // Deduplication check
    final now = DateTime.now();
    final lastPlayed = _lastPlayedMap[type];
    if (lastPlayed != null && now.difference(lastPlayed).inMilliseconds < _dedupWindowMs) {
      return; // Skip duplicate trigger within debounce window
    }

    _lastPlayedMap[type] = now;

    final String soundName = switch (type) {
      SfxType.buttonClick => 'click',
      SfxType.auctionStart => 'gavel_strike',
      SfxType.itemAnnounced => 'gavel_strike',
      SfxType.bidAccepted => 'coin_bid',
      SfxType.highestBidder => 'coin_bid',
      SfxType.outbid => 'outbid_alert',
      SfxType.timerWarning => 'timer_tick',
      SfxType.itemSold => 'gavel_strike',
      SfxType.itemUnsold => 'outbid_alert',
      SfxType.matchVictory => 'victory',
      SfxType.matchTie => 'coin_bid',
      _ => 'click',
    };

    try {
      _soundChannel.invokeMethod('playSound', {'sound': soundName});
    } catch (_) {}

    if (kDebugMode) {
      print('[AudioService] Play SFX: ${type.name} -> $soundName');
    }
  }

  /// Play short, premium UI button click sound
  void playButtonClick() {
    if (!_isForeground) return;
    final settings = SettingsService();
    if (!settings.masterSound || !settings.buttonTouchSound || settings.masterVolume <= 0) {
      return;
    }

    final now = DateTime.now();
    final lastPlayed = _lastPlayedMap[SfxType.buttonClick];
    if (lastPlayed != null && now.difference(lastPlayed).inMilliseconds < 100) {
      return;
    }
    _lastPlayedMap[SfxType.buttonClick] = now;

    try {
      _soundChannel.invokeMethod('playSound', {'sound': 'click'});
    } catch (_) {}

    if (settings.vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Trigger haptic/vibration feedback if enabled in settings
  void triggerHaptic() {
    final settings = SettingsService();
    if (settings.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }
  }
}
