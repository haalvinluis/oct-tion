import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PolicyService {
  PolicyService._();

  static const String privacyPolicyUrl = 'https://haalvinluis.github.io/oct-tion/privacy.html';
  static const String termsOfServiceUrl = 'https://haalvinluis.github.io/oct-tion/terms.html';
  static const String supportEmail = 'oct.tion@gmail.com';

  /// Launches the official Privacy Policy in the external system browser or Custom Tab.
  static Future<bool> openPrivacyPolicy(BuildContext context) {
    return openUrl(
      context,
      privacyPolicyUrl,
      title: 'Privacy Policy',
    );
  }

  /// Launches the official Terms & Conditions in the external system browser or Custom Tab.
  static Future<bool> openTermsOfService(BuildContext context) {
    return openUrl(
      context,
      termsOfServiceUrl,
      title: 'Terms & Conditions',
    );
  }

  /// Launches default email app with support recipient or copies email as fallback.
  static Future<bool> openSupportEmail(BuildContext context) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent('OCT-TION Support & Feedback')}',
    );

    bool launched = false;
    try {
      launched = await launchUrl(
        emailUri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('[PolicyService] mailto platformDefault failed: $e');
    }

    if (!launched) {
      try {
        launched = await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('[PolicyService] mailto externalApplication failed: $e');
      }
    }

    if (!launched && context.mounted) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Email app not detected. Copied $supportEmail to clipboard!',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppTheme.accent,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    return true;
  }

  /// Launches any policy URL in the device's system browser with layered fallback strategies.
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

    bool launched = false;

    // Strategy 1: platformDefault (opens Chrome / default browser or Custom Tab cleanly)
    try {
      launched = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      debugPrint('[PolicyService] LaunchMode.platformDefault error for $title: $e');
    }

    // Strategy 2: inAppBrowserView (opens in Chrome Custom Tab if external app fails)
    if (!launched && (uri.scheme == 'http' || uri.scheme == 'https')) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
      } catch (e) {
        debugPrint('[PolicyService] LaunchMode.inAppBrowserView error for $title: $e');
      }
    }

    // Strategy 3: externalApplication
    if (!launched) {
      try {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('[PolicyService] LaunchMode.externalApplication error for $title: $e');
      }
    }

    // Strategy 4: Fallback dialog with direct copy option
    if (!launched) {
      if (context.mounted) {
        await Clipboard.setData(ClipboardData(text: urlString));
        _showFallbackDialog(context, title, urlString);
      }
      return false;
    }
    return true;
  }

  static void _showFallbackDialog(BuildContext context, String title, String urlString) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.open_in_browser_rounded, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Could not automatically launch the browser. The link has been copied to your clipboard so you can open it directly in Chrome:',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
              ),
              child: SelectableText(
                urlString,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
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
