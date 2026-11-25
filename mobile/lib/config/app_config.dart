import 'package:flutter/foundation.dart';

/// Centralized configuration for PowerBid mobile client.
/// Eliminates hardcoded URLs and provides environment-aware endpoints (dev, staging, production).
class AppConfig {
  /// Build environment: 'development', 'staging', or 'production'.
  /// Can be overridden at build time via:
  /// `flutter build apk --dart-define=ENV=production`
  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  /// Production Cloud Server URL (HTTPS / WSS).
  /// Configure this with your live cloud hosting domain (e.g. Render, Railway, Fly.io, or VPS).
  static const String productionServerUrl = 'https://powerbid-game-server.onrender.com';

  /// Staging Cloud Server URL for pre-release testing.
  static const String stagingServerUrl = 'https://staging-api.powerbid.game';

  /// Local Development Server URLs:
  /// For physical devices over Wi-Fi: use your host machine's LAN IP (http://10.238.8.1:3000)
  /// For Android Emulator: use http://10.0.2.2:3000
  /// For physical devices over USB (ADB reverse): use http://127.0.0.1:3000
  static const String developmentServerUrl = 'http://10.238.8.1:3000';
  static const String emulatorServerUrl = 'http://10.0.2.2:3000';
  static const String localhostServerUrl = 'http://127.0.0.1:3000';

  /// Fallback candidates for local network environments
  static const List<String> localFallbackCandidates = [
    'http://127.0.0.1:3000',
    'http://10.0.2.2:3000',
    'http://10.238.8.1:3000',
  ];

  /// Returns the active server URL.
  /// Priority:
  /// 1. Explicit compile-time `--dart-define=SERVER_URL=...`
  /// 2. Environment default (production vs staging vs development)
  static String get defaultServerUrl {
    const customUrl = String.fromEnvironment('SERVER_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }

    switch (environment.toLowerCase()) {
      case 'staging':
        return stagingServerUrl;
      case 'production':
      case 'prod':
        // If production domain is the unhosted placeholder api.powerbid.game,
        // fallback to development URL to allow local testing and prevent network deadlock.
        if (productionServerUrl == 'https://api.powerbid.game') {
          return developmentServerUrl;
        }
        return productionServerUrl;
      case 'development':
      case 'dev':
      case 'local':
      default:
        return developmentServerUrl;
    }
  }

  /// Whether the app is running in production mode.
  static bool get isProduction =>
      environment.toLowerCase() == 'production' || environment.toLowerCase() == 'prod';

  /// Whether the app is running in development mode.
  static bool get isDevelopment =>
      environment.toLowerCase() == 'development' || environment.toLowerCase() == 'dev';
}
