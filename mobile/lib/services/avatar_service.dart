import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'socket_service.dart';

class DefaultAvatarItem {
  final String id;
  final String label;
  final IconData icon;
  final String symbol;
  final LinearGradient gradient;
  final Color borderColor;

  const DefaultAvatarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.symbol,
    required this.gradient,
    required this.borderColor,
  });
}

class AvatarData {
  final bool isGallery;
  final String? imagePath;
  final String defaultAvatarId;

  const AvatarData({
    this.isGallery = false,
    this.imagePath,
    this.defaultAvatarId = 'gavel',
  });

  DefaultAvatarItem get defaultItem {
    return AvatarService.defaultAvatars.firstWhere(
      (a) => a.id == defaultAvatarId,
      orElse: () => AvatarService.defaultAvatars.first,
    );
  }
}

class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  static AvatarService get instance => _instance;

  AvatarService._internal();

  static const String _keyAvatarType = 'powerbid_avatar_type';
  static const String _keyDefaultId = 'powerbid_default_avatar_id';
  static const String _keyImagePath = 'powerbid_custom_image_path';

  static const List<DefaultAvatarItem> defaultAvatars = [
    DefaultAvatarItem(
      id: 'gavel',
      label: 'Power Gavel',
      icon: Icons.gavel_rounded,
      symbol: '🔨',
      gradient: LinearGradient(
        colors: [Color(0xFF356DFF), Color(0xFF713CFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppTheme.blueAccent,
    ),
    DefaultAvatarItem(
      id: 'crown',
      label: 'Golden Crown',
      icon: Icons.workspace_premium_rounded,
      symbol: '👑',
      gradient: LinearGradient(
        colors: [Color(0xFFF5C451), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: AppTheme.goldHighlight,
    ),
    DefaultAvatarItem(
      id: 'flame',
      label: 'Blazing Flame',
      icon: Icons.local_fire_department_rounded,
      symbol: '🔥',
      gradient: LinearGradient(
        colors: [Color(0xFFFF5722), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFFFF5722),
    ),
    DefaultAvatarItem(
      id: 'trophy',
      label: 'Champion Trophy',
      icon: Icons.emoji_events_rounded,
      symbol: '🏆',
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFF10B981),
    ),
    DefaultAvatarItem(
      id: 'controller',
      label: 'Pro Gamer',
      icon: Icons.sports_esports_rounded,
      symbol: '🎮',
      gradient: LinearGradient(
        colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFF06B6D4),
    ),
    DefaultAvatarItem(
      id: 'shield',
      label: 'Guardian Shield',
      icon: Icons.shield_rounded,
      symbol: '🛡️',
      gradient: LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFF8B5CF6),
    ),
    DefaultAvatarItem(
      id: 'diamond',
      label: 'Diamond Elite',
      icon: Icons.diamond_rounded,
      symbol: '💎',
      gradient: LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFF38BDF8),
    ),
    DefaultAvatarItem(
      id: 'rocket',
      label: 'Cosmic Bidder',
      icon: Icons.rocket_launch_rounded,
      symbol: '🚀',
      gradient: LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFF9333EA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderColor: Color(0xFFEC4899),
    ),
  ];

  final ValueNotifier<AvatarData> avatarNotifier = ValueNotifier<AvatarData>(
    const AvatarData(defaultAvatarId: 'gavel'),
  );

  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// Loads saved avatar configuration from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final type = prefs.getString(_keyAvatarType) ?? 'default';
      final defaultId = prefs.getString(_keyDefaultId) ?? 'gavel';
      final imagePath = prefs.getString(_keyImagePath);

      if (type == 'gallery' && imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (await file.exists()) {
          avatarNotifier.value = AvatarData(
            isGallery: true,
            imagePath: imagePath,
            defaultAvatarId: defaultId,
          );
          return;
        }
      }

      // Fallback or default
      avatarNotifier.value = AvatarData(
        isGallery: false,
        imagePath: null,
        defaultAvatarId: defaultId,
      );
    } catch (e) {
      debugPrint('[AvatarService] Error loading avatar: $e');
      avatarNotifier.value = const AvatarData(defaultAvatarId: 'gavel');
    }
  }

  /// Sets one of the built-in default avatars.
  Future<void> selectDefaultAvatar(String avatarId, {String? username}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatarType, 'default');
      await prefs.setString(_keyDefaultId, avatarId);

      final item = defaultAvatars.firstWhere(
        (a) => a.id == avatarId,
        orElse: () => defaultAvatars.first,
      );

      avatarNotifier.value = AvatarData(
        isGallery: false,
        imagePath: null,
        defaultAvatarId: avatarId,
      );

      // Sync avatar symbol to backend profile if username is available
      if (username != null && username.isNotEmpty) {
        SocketService.instance.updateUsername(username, avatarText: item.symbol);
      }
    } catch (e) {
      debugPrint('[AvatarService] Failed to set default avatar: $e');
    }
  }

  /// Prompts user to pick a photo from device gallery.
  Future<bool> pickAndSetGalleryPhoto({String? username}) async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        _isProcessing = false;
        return false; // User cancelled
      }

      // Copy to persistent application documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = '${docsDir.path}/powerbid_profile_avatar.jpg';
      final savedFile = await File(pickedFile.path).copy(targetPath);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAvatarType, 'gallery');
      await prefs.setString(_keyImagePath, savedFile.path);

      avatarNotifier.value = AvatarData(
        isGallery: true,
        imagePath: savedFile.path,
        defaultAvatarId: avatarNotifier.value.defaultAvatarId,
      );

      // Sync avatar symbol to backend
      if (username != null && username.isNotEmpty) {
        SocketService.instance.updateUsername(username, avatarText: '📷');
      }

      _isProcessing = false;
      return true;
    } catch (e) {
      debugPrint('[AvatarService] Error picking image: $e');
      _isProcessing = false;
      return false;
    }
  }
}
