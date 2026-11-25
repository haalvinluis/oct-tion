import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/avatar_service.dart';

class AvatarWidget extends StatelessWidget {
  final double radius;
  final bool isEditable;
  final VoidCallback? onEditPressed;
  final AvatarData? overrideData;

  const AvatarWidget({
    super.key,
    this.radius = 32,
    this.isEditable = false,
    this.onEditPressed,
    this.overrideData,
  });

  @override
  Widget build(BuildContext context) {
    if (overrideData != null) {
      return _buildAvatar(context, overrideData!);
    }

    return ValueListenableBuilder<AvatarData>(
      valueListenable: AvatarService.instance.avatarNotifier,
      builder: (context, avatarData, _) {
        return _buildAvatar(context, avatarData);
      },
    );
  }

  Widget _buildAvatar(BuildContext context, AvatarData avatarData) {
    final double diameter = radius * 2;
    final defaultItem = avatarData.defaultItem;

    Widget avatarContent;

    if (avatarData.isGallery && avatarData.imagePath != null) {
      final file = File(avatarData.imagePath!);
      if (file.existsSync()) {
        avatarContent = ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.file(
            file,
            key: ValueKey(avatarData.imagePath),
            width: diameter,
            height: diameter,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(defaultItem),
          ),
        );
      } else {
        avatarContent = _buildFallback(defaultItem);
      }
    } else {
      avatarContent = _buildFallback(defaultItem);
    }

    if (!isEditable) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: avatarData.isGallery ? AppTheme.goldHighlight : defaultItem.borderColor,
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (avatarData.isGallery ? AppTheme.goldHighlight : defaultItem.borderColor)
                  .withValues(alpha: 0.35),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipOval(child: avatarContent),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onEditPressed,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: avatarData.isGallery ? AppTheme.goldHighlight : defaultItem.borderColor,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (avatarData.isGallery ? AppTheme.goldHighlight : defaultItem.borderColor)
                      .withValues(alpha: 0.4),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(child: avatarContent),
          ),
        ),

        // Camera / Edit Badge
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onEditPressed,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                border: Border.all(color: AppTheme.pureWhite, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback(DefaultAvatarItem item) {
    return Container(
      decoration: BoxDecoration(
        gradient: item.gradient,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          item.icon,
          size: radius * 1.0,
          color: Colors.white,
        ),
      ),
    );
  }
}
