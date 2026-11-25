/// Central authentication configuration for PowerBid.
/// Handles OAuth client IDs, provider setup validation, and error descriptions.
class AuthConfig {
  /// Google OAuth Web Client ID (used as serverClientId on Android to request ID tokens).
  /// Pass via compile-time flag: --dart-define=GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '119401455456-e4i1blruhrf8esqun3uo4scu1702bi07.apps.googleusercontent.com',
  );

  /// Google Android Client ID (optional, Android Credential Manager matches package + SHA-1).
  static const String googleAndroidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue: '119401455456-gmfsd47fe78veuhcrv72i13k4uj62355.apps.googleusercontent.com',
  );

  /// Meta / Facebook App ID.
  /// Pass via compile-time flag: --dart-define=FACEBOOK_APP_ID=your_fb_app_id
  static const String facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '',
  );

  /// Package Name of the Android App (must match Google Cloud & Meta Developer Portal).
  static const String androidPackageName = 'com.auctiongame.mobile';

  /// Debug Signing Key Certificate Fingerprint (SHA-1).
  static const String debugSha1 = '64:20:B4:CD:1D:00:29:54:71:CC:92:4D:20:76:24:17:1B:0E:50:9E';

  /// Facebook Key Hash for Android Debug builds.
  static const String debugFacebookKeyHash = 'ZCC0zR0AKVRxzJJNIHYkFxsOUJ4=';

  /// Returns true if Google Sign-In is configured with a valid server client ID.
  static bool get isGoogleConfigured => googleServerClientId.trim().isNotEmpty;

  /// Returns true if Facebook Login is configured with a valid App ID.
  static bool get isFacebookConfigured =>
      facebookAppId.trim().isNotEmpty && !facebookAppId.contains('0000000');

  /// Helpful message when Google credentials are not set up yet.
  static String get googleSetupInstructions =>
      'Google Sign-In requires an OAuth 2.0 Web Client ID from Google Cloud Console.\n\n'
      '1. Open Google Cloud Console -> APIs & Services -> Credentials\n'
      '2. Create an "Android" Client ID with:\n'
      '   - Package: $androidPackageName\n'
      '   - SHA-1: $debugSha1\n'
      '3. Create a "Web application" Client ID and pass it as GOOGLE_CLIENT_ID.';

  /// Helpful message when Facebook credentials are not set up yet.
  static String get facebookSetupInstructions =>
      'Facebook Login requires a Meta Developer App ID and Client Token.\n\n'
      '1. Open https://developers.facebook.com/apps/\n'
      '2. In Android Settings, configure:\n'
      '   - Package: $androidPackageName\n'
      '   - Class: $androidPackageName.MainActivity\n'
      '   - Key Hash: $debugFacebookKeyHash\n'
      '3. Set facebook_app_id and facebook_client_token in strings.xml and backend environment.';
}
