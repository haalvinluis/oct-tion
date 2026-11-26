import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyTextScale = 'settings_text_scale';
  static const String _keyMasterSound = 'settings_master_sound';
  static const String _keySfxEnabled = 'settings_sfx_enabled';
  static const String _keyMusicEnabled = 'settings_music_enabled';
  static const String _keyButtonTouchSound = 'settings_button_touch_sound';
  static const String _keyMasterVolume = 'settings_master_volume';
  static const String _keyVibrationEnabled = 'settings_vibration_enabled';
  static const String _keyConfirmBidDialog = 'settings_confirm_bid_dialog';
  static const String _keyConfirmLeaveMatch = 'settings_confirm_leave_match';

  // Audio Settings
  bool _masterSound = true;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;
  bool _buttonTouchSound = true;
  double _masterVolume = 1.0;

  // Gameplay Settings
  bool _vibrationEnabled = true;
  bool _confirmBidDialog = false;
  bool _confirmLeaveMatch = true;

  // Display & Accessibility Settings
  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = 1.0; // 0.85, 1.0, 1.15, 1.30

  // Getters
  bool get masterSound => _masterSound;
  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  bool get buttonTouchSound => _buttonTouchSound;
  double get masterVolume => _masterVolume;

  bool get vibrationEnabled => _vibrationEnabled;
  bool get confirmBidDialog => _confirmBidDialog;
  bool get confirmLeaveMatch => _confirmLeaveMatch;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr == 'light') {
        _themeMode = ThemeMode.light;
      } else if (modeStr == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (modeStr == 'system') {
        _themeMode = ThemeMode.system;
      }
      _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
      _masterSound = prefs.getBool(_keyMasterSound) ?? true;
      _sfxEnabled = prefs.getBool(_keySfxEnabled) ?? true;
      _musicEnabled = prefs.getBool(_keyMusicEnabled) ?? true;
      _buttonTouchSound = prefs.getBool(_keyButtonTouchSound) ?? true;
      _masterVolume = prefs.getDouble(_keyMasterVolume) ?? 1.0;
      _vibrationEnabled = prefs.getBool(_keyVibrationEnabled) ?? true;
      _confirmBidDialog = prefs.getBool(_keyConfirmBidDialog) ?? false;
      _confirmLeaveMatch = prefs.getBool(_keyConfirmLeaveMatch) ?? true;
      notifyListeners();
    } catch (_) {}
  }

  // Setters
  void setMasterSound(bool val) {
    _masterSound = val;
    notifyListeners();
    _saveBool(_keyMasterSound, val);
  }

  void setSfxEnabled(bool val) {
    _sfxEnabled = val;
    notifyListeners();
    _saveBool(_keySfxEnabled, val);
  }

  void setMusicEnabled(bool val) {
    _musicEnabled = val;
    notifyListeners();
    _saveBool(_keyMusicEnabled, val);
  }

  void setButtonTouchSound(bool val) {
    _buttonTouchSound = val;
    notifyListeners();
    _saveBool(_keyButtonTouchSound, val);
  }

  void setMasterVolume(double val) {
    _masterVolume = val.clamp(0.0, 1.0);
    notifyListeners();
    _saveDouble(_keyMasterVolume, _masterVolume);
  }

  void setVibrationEnabled(bool val) {
    _vibrationEnabled = val;
    notifyListeners();
    _saveBool(_keyVibrationEnabled, val);
  }

  void setConfirmBidDialog(bool val) {
    _confirmBidDialog = val;
    notifyListeners();
    _saveBool(_keyConfirmBidDialog, val);
  }

  void setConfirmLeaveMatch(bool val) {
    _confirmLeaveMatch = val;
    notifyListeners();
    _saveBool(_keyConfirmLeaveMatch, val);
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyThemeMode, mode.name);
    } catch (_) {}
  }

  void setTextScale(double scale) {
    _textScale = scale;
    notifyListeners();
    _saveDouble(_keyTextScale, scale);
  }

  void _saveBool(String key, bool val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, val);
    } catch (_) {}
  }

  void _saveDouble(String key, double val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, val);
    } catch (_) {}
  }

  void restoreDefaults() {
    _masterSound = true;
    _sfxEnabled = true;
    _musicEnabled = true;
    _masterVolume = 1.0;

    _vibrationEnabled = true;
    _confirmBidDialog = false;
    _confirmLeaveMatch = true;

    _themeMode = ThemeMode.system;
    _textScale = 1.0;

    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyThemeMode);
      prefs.remove(_keyTextScale);
      prefs.remove(_keyMasterSound);
      prefs.remove(_keySfxEnabled);
      prefs.remove(_keyMusicEnabled);
      prefs.remove(_keyButtonTouchSound);
      prefs.remove(_keyMasterVolume);
      prefs.remove(_keyVibrationEnabled);
      prefs.remove(_keyConfirmBidDialog);
      prefs.remove(_keyConfirmLeaveMatch);
    }).catchError((_) {});
  }
}
