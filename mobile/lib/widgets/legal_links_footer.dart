import 'package:flutter/material.dart';
import '../services/policy_service.dart';
import '../theme/app_theme.dart';

class LegalLinksFooter extends StatelessWidget {
  final bool showDisclaimer;
  final Color? linkColor;
  final Color? textColor;

  const LegalLinksFooter({
    super.key,
    this.showDisclaimer = true,
    this.linkColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLinkColor = linkColor ?? AppTheme.goldHighlight;
    final effectiveTextColor = textColor ?? AppTheme.mutedText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDisclaimer) ...[
          Text(
            'By continuing, you agree to OCT-TION\'s Terms & Conditions and acknowledge our Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: effectiveTextColor.withValues(alpha: 0.75),
              fontSize: 10.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            InkWell(
              onTap: () => PolicyService.openPrivacyPolicy(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: effectiveLinkColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: effectiveLinkColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            Text(
              '•',
              style: TextStyle(
                color: effectiveTextColor.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            InkWell(
              onTap: () => PolicyService.openTermsOfService(context),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: effectiveLinkColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: effectiveLinkColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
