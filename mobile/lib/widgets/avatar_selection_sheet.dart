import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/avatar_service.dart';

class AvatarSelectionSheet extends StatefulWidget {
  final String? username;

  const AvatarSelectionSheet({super.key, this.username});

  static Future<void> show(BuildContext context, {String? username}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarSelectionSheet(username: username),
    );
  }

  @override
  State<AvatarSelectionSheet> createState() => _AvatarSelectionSheetState();
}

class _AvatarSelectionSheetState extends State<AvatarSelectionSheet> {
  bool _isPicking = false;

  Future<void> _handlePickGallery() async {
    setState(() => _isPicking = true);

    try {
      final success = await AvatarService.instance.pickAndSetGalleryPhoto(
        username: widget.username,
      );

      if (mounted) {
        setState(() => _isPicking = false);
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile photo updated from gallery!'),
              backgroundColor: AppTheme.blueAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPicking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBorder, width: 1.5),
        ),
      ),
      child: ValueListenableBuilder<AvatarData>(
        valueListenable: AvatarService.instance.avatarNotifier,
        builder: (context, currentData, _) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
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

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Profile Avatar',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.pureWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.mutedText),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 1. Gallery Photo Action Button
                GestureDetector(
                  onTap: _isPicking ? null : _handlePickGallery,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.secondarySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: currentData.isGallery ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                        width: currentData.isGallery ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.blueAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: _isPicking
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_library_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select from Phone Gallery',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.pureWhite,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentData.isGallery
                                    ? 'Custom photo currently active'
                                    : 'Pick a photo from your Android gallery',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.mutedText,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (currentData.isGallery)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.goldHighlight,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Default Curated Avatars Heading
                const Text(
                  'Or Pick a Default OCT-TION Avatar',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Avatars Grid (8 choices)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: AvatarService.defaultAvatars.length,
                  itemBuilder: (context, index) {
                    final item = AvatarService.defaultAvatars[index];
                    final isSelected = !currentData.isGallery && currentData.defaultAvatarId == item.id;

                    return GestureDetector(
                      onTap: () async {
                        await AvatarService.instance.selectDefaultAvatar(
                          item.id,
                          username: widget.username,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Avatar changed to ${item.label}!'),
                              backgroundColor: AppTheme.blueAccent,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: item.gradient,
                                  border: Border.all(
                                    color: isSelected ? AppTheme.goldHighlight : Colors.transparent,
                                    width: isSelected ? 2.5 : 0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.borderColor.withValues(alpha: isSelected ? 0.5 : 0.25),
                                      blurRadius: isSelected ? 12 : 6,
                                    ),
                                  ],
                                ),
                                child: Icon(item.icon, color: Colors.white, size: 28),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.navySurface,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppTheme.goldHighlight,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: isSelected ? AppTheme.goldHighlight : AppTheme.pureWhite,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
