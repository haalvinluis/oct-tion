import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PolicyService {
  PolicyService._();

  static const String privacyPolicyUrl = 'https://haalvinluis.github.io/Powerbid/privacy.html';
  static const String termsOfServiceUrl = 'https://haalvinluis.github.io/Powerbid/terms.html';

  /// Launches the official Privacy Policy in the external system browser.
  static Future<bool> openPrivacyPolicy(BuildContext context) {
    return openUrl(
      context,
      privacyPolicyUrl,
      title: 'Privacy Policy',
    );
  }

  /// Launches the official Terms & Conditions in the external system browser.
  static Future<bool> openTermsOfService(BuildContext context) {
    return openUrl(
      context,
      termsOfServiceUrl,
      title: 'Terms & Conditions',
    );
  }

  /// Launches any policy URL in the device's system browser with robust error handling.
  static Future<bool> openUrl(
    BuildContext context,
    String urlString, {
    required String title,
  }) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null || !uri.hasScheme) {
      _showErrorSnackBar(context, 'Invalid URL format for $title.');
      return false;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (context.mounted) {
          _showErrorSnackBar(context, 'Could not open $title in your browser. Please visit: $urlString');
        }
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[PolicyService] Error launching $title ($urlString): $e');
      if (context.mounted) {
        _showErrorSnackBar(context, 'Unable to open browser for $title. Please visit: $urlString');
      }
      return false;
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
