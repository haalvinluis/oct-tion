import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';

class AgeVerificationDialog extends StatefulWidget {
  final int initialAge;

  const AgeVerificationDialog({
    super.key,
    this.initialAge = 18,
  });

  /// Displays the Age Verification modal only if not already verified.
  /// Age cannot be changed once set.
  static Future<bool> show(BuildContext context, {bool forceShow = false}) async {
    if (AuthService.instance.isAgeVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your age (${AuthService.instance.playerAge}) is verified and cannot be changed.'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.cardBackground,
        ),
      );
      return true;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AgeVerificationDialog(
        initialAge: AuthService.instance.playerAge > 0
            ? AuthService.instance.playerAge
            : 18,
      ),
    );

    return result ?? AuthService.instance.isAgeVerified;
  }

  @override
  State<AgeVerificationDialog> createState() => _AgeVerificationDialogState();
}

class _AgeVerificationDialogState extends State<AgeVerificationDialog> {
  late int _age;
  bool _confirmed = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _age = widget.initialAge < 10 ? 18 : widget.initialAge;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.mutedText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.goldHighlight.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.goldHighlight, width: 1.2),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: AppTheme.goldHighlight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Player Age Verification',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.pureWhite,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Please verify your age. Once set, it cannot be changed.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppTheme.mutedText),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Age Counter Picker Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.goldBorderGlow,
                  width: 1.4,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'SELECT YOUR AGE',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.goldHighlight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Minus Button
                      IconButton(
                        onPressed: _age > 10
                            ? () {
                                setState(() => _age--);
                                AudioService().playButtonClick();
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        iconSize: 34,
                        color: _age > 10 ? AppTheme.goldHighlight : AppTheme.mutedText,
                      ),
                      const SizedBox(width: 16),

                      // Age Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.mainBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Text(
                          '$_age',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.goldHighlight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Plus Button
                      IconButton(
                        onPressed: _age < 99
                            ? () {
                                setState(() => _age++);
                                AudioService().playButtonClick();
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        iconSize: 34,
                        color: _age < 99 ? AppTheme.goldHighlight : AppTheme.mutedText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Permanent Lock Notice
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.mainBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.champagneGold),
                        SizedBox(width: 6),
                        Text(
                          'This age setting is permanent and cannot be modified later.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.champagneGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Accuracy Confirmation Checkbox
            GestureDetector(
              onTap: () {
                setState(() => _confirmed = !_confirmed);
              },
              child: Row(
                children: [
                  Checkbox(
                    value: _confirmed,
                    activeColor: AppTheme.goldHighlight,
                    checkColor: AppTheme.darkMaroonText,
                    onChanged: (val) {
                      setState(() => _confirmed = val ?? true);
                    },
                  ),
                  Expanded(
                    child: Text(
                      'I confirm this is my real age and understand it cannot be changed.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Confirm Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldHighlight,
                foregroundColor: AppTheme.darkMaroonText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: (!_confirmed || _isSaving)
                  ? null
                  : () async {
                      setState(() => _isSaving = true);
                      await AuthService.instance.setPlayerAge(_age);
                      if (!mounted) return;
                      Navigator.pop(context, true);
                    },
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.darkMaroonText,
                      ),
                    )
                  : const Text(
                      'Confirm & Lock Age',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
