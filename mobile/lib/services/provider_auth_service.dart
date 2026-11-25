import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import '../config/auth_config.dart';

/// Result of a native third-party OAuth provider authentication flow.
class ProviderAuthResult {
  final bool success;
  final bool cancelled;
  final String? token; // Google id_token OR Facebook access_token
  final String? provider; // 'google' or 'facebook'
  final String? email;
  final String? displayName;
  final String? error;

  ProviderAuthResult({
    required this.success,
    this.cancelled = false,
    this.token,
    this.provider,
    this.email,
    this.displayName,
    this.error,
  });

  factory ProviderAuthResult.success({
    required String token,
    required String provider,
    String? email,
    String? displayName,
  }) =>
      ProviderAuthResult(
        success: true,
        token: token,
        provider: provider,
        email: email,
        displayName: displayName,
      );

  factory ProviderAuthResult.cancelled(String provider) => ProviderAuthResult(
        success: false,
        cancelled: true,
        provider: provider,
        error: '$provider sign-in was cancelled.',
      );

  factory ProviderAuthResult.failure({
    required String provider,
    required String error,
  }) =>
      ProviderAuthResult(
        success: false,
        provider: provider,
        error: error,
      );
}

/// Service managing genuine native Google Sign-In and Facebook Login flows.
/// Opens provider consent dialogs and retrieves cryptographically signed provider tokens.
class ProviderAuthService {
  static final ProviderAuthService _instance = ProviderAuthService._internal();
  static ProviderAuthService get instance => _instance;

  ProviderAuthService._internal();

  bool _initialized = false;

  /// Initializes provider SDKs. Called at application startup.
  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;

    try {
      final serverClientId = AuthConfig.googleServerClientId.trim();
      await GoogleSignIn.instance.initialize(
        serverClientId: serverClientId.isNotEmpty ? serverClientId : null,
      );
      _initialized = true;
      debugPrint('[ProviderAuthService] Google Sign-In initialized (serverClientId=$serverClientId)');
    } catch (e) {
      debugPrint('[ProviderAuthService] Google Sign-In initialization error: $e');
    }
  }

  /// Initiates genuine Google Sign-In, opening the native account chooser and consent sheet.
  /// Obtains the cryptographically signed Google ID token (JWT).
  Future<ProviderAuthResult> authenticateWithGoogle() async {
    try {
      if (!_initialized) {
        await init();
      }

      // Check if server client ID is configured
      if (!AuthConfig.isGoogleConfigured) {
        return ProviderAuthResult.failure(
          provider: 'Google',
          error:
              'Google Sign-In requires an OAuth 2.0 Web Client ID from Google Cloud Console.\n\n'
              'Please configure GOOGLE_CLIENT_ID in lib/config/auth_config.dart or pass via --dart-define. Tap "OAuth Developer Setup" below for details.',
        );
      }

      // Starts interactive sign-in process with Google Credential Manager
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();

      final auth = account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        return ProviderAuthResult.failure(
          provider: 'Google',
          error:
              'No Google ID token received. Ensure the Web Client ID is configured in AuthConfig and matches Google Cloud Console.',
        );
      }

      return ProviderAuthResult.success(
        token: idToken,
        provider: 'Google',
        email: account.email,
        displayName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      debugPrint('[ProviderAuthService] GoogleSignInException: code=${e.code}, description=${e.description}');
      final desc = e.description?.trim() ?? '';
      final isRealError = desc.contains('16') ||
          desc.toLowerCase().contains('reauth') ||
          desc.toLowerCase().contains('failed') ||
          desc.toLowerCase().contains('developer') ||
          desc.toLowerCase().contains('error') ||
          desc.contains('10') ||
          desc.contains('12500');

      if (e.code == GoogleSignInExceptionCode.canceled && !isRealError) {
        return ProviderAuthResult.cancelled('Google');
      }

      String detailedError;
      if (desc.contains('16') || desc.toLowerCase().contains('reauth')) {
        detailedError =
            'Google Sign-In failed: Account re-authentication failed (Code 16).\n\n'
            'To resolve this in Google Cloud Console:\n'
            '1. If your OAuth Consent Screen is in "Testing" status, add your Google email under "Test Users".\n'
            '2. Create an Android OAuth Client ID for package "${AuthConfig.androidPackageName}" with SHA-1 "${AuthConfig.debugSha1}" under the same project as your Web Client ID.';
      } else if (desc.contains('10') || desc.toLowerCase().contains('developer')) {
        detailedError =
            'Google Developer Configuration Error (Code 10).\n\n'
            'Verify that package "${AuthConfig.androidPackageName}" and SHA-1 "${AuthConfig.debugSha1}" match your Android OAuth Client in Google Cloud Console.';
      } else if (desc.isNotEmpty) {
        detailedError = desc;
      } else {
        detailedError = 'Google Sign-In failed (${e.code.name}).';
      }

      return ProviderAuthResult.failure(
        provider: 'Google',
        error: detailedError,
      );
    } on PlatformException catch (e) {
      debugPrint('[ProviderAuthService] PlatformException: ${e.code} - ${e.message}');
      final msg = e.message ?? '';
      final isCancel = (e.code == 'sign_in_canceled' || e.code == 'canceled') &&
          !msg.contains('16') &&
          !msg.toLowerCase().contains('reauth') &&
          !msg.toLowerCase().contains('failed');
      if (isCancel) {
        return ProviderAuthResult.cancelled('Google');
      }
      if (e.code == '10' || e.code == '12500' || msg.contains('10')) {
        return ProviderAuthResult.failure(
          provider: 'Google',
          error:
              'Google configuration error (code ${e.code}). Please verify SHA-1 (${AuthConfig.debugSha1}) and package name (${AuthConfig.androidPackageName}) in Google Cloud Console.',
        );
      }
      if (e.code == '16' || msg.contains('16') || msg.toLowerCase().contains('reauth')) {
        return ProviderAuthResult.failure(
          provider: 'Google',
          error:
              'Google Sign-In failed: Account re-authentication failed (Code 16).\n\n'
              'Please add your email as a "Test User" in Google Cloud Console OAuth consent screen, and verify the Android OAuth Client ID matches package "${AuthConfig.androidPackageName}" and SHA-1 "${AuthConfig.debugSha1}".',
        );
      }
      return ProviderAuthResult.failure(
        provider: 'Google',
        error: e.message ?? 'Platform error during Google Sign-In.',
      );
    } catch (e) {
      debugPrint('[ProviderAuthService] Unexpected Google sign-in error: $e');
      final errStr = e.toString();
      final isCancel = (errStr.contains('canceled') || errStr.contains('cancelled')) &&
          !errStr.contains('16') &&
          !errStr.toLowerCase().contains('reauth');
      if (isCancel) {
        return ProviderAuthResult.cancelled('Google');
      }
      return ProviderAuthResult.failure(
        provider: 'Google',
        error: 'Unable to complete Google Sign-In: $e',
      );
    }
  }

  /// Initiates genuine Facebook Login, opening the native Facebook app or web dialog.
  /// Obtains the cryptographically verified user Access Token from Meta.
  Future<ProviderAuthResult> authenticateWithFacebook() async {
    try {
      if (!AuthConfig.isFacebookConfigured) {
        return ProviderAuthResult.failure(
          provider: 'Facebook',
          error:
              'Facebook Login is not configured. Please set FACEBOOK_APP_ID and FACEBOOK_CLIENT_TOKEN in strings.xml and backend environment.',
        );
      }

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: const ['public_profile', 'email'],
      );

      switch (result.status) {
        case LoginStatus.success:
          final accessToken = result.accessToken?.tokenString;
          if (accessToken == null || accessToken.trim().isEmpty) {
            return ProviderAuthResult.failure(
              provider: 'Facebook',
              error: 'Facebook returned empty access token.',
            );
          }
          return ProviderAuthResult.success(
            token: accessToken,
            provider: 'Facebook',
          );

        case LoginStatus.cancelled:
          return ProviderAuthResult.cancelled('Facebook');

        case LoginStatus.failed:
          return ProviderAuthResult.failure(
            provider: 'Facebook',
            error: result.message ?? 'Facebook login failed.',
          );

        case LoginStatus.operationInProgress:
          return ProviderAuthResult.failure(
            provider: 'Facebook',
            error: 'Facebook login is already in progress.',
          );
      }
    } on PlatformException catch (e) {
      debugPrint('[ProviderAuthService] Facebook PlatformException: ${e.code} - ${e.message}');
      if (e.code == 'CANCELLED') {
        return ProviderAuthResult.cancelled('Facebook');
      }
      return ProviderAuthResult.failure(
        provider: 'Facebook',
        error: e.message ?? 'Facebook authentication failed.',
      );
    } catch (e) {
      debugPrint('[ProviderAuthService] Unexpected Facebook sign-in error: $e');
      final errStr = e.toString();
      if (errStr.contains('canceled') || errStr.contains('cancelled')) {
        return ProviderAuthResult.cancelled('Facebook');
      }
      return ProviderAuthResult.failure(
        provider: 'Facebook',
        error: 'Unable to complete Facebook Login: $e',
      );
    }
  }

  /// Signs out from native provider sessions when the user logs out.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}
