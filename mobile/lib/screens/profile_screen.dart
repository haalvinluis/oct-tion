import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/provider_auth_service.dart';
import '../config/auth_config.dart';
import '../widgets/stat_badge.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/avatar_selection_sheet.dart';
import '../widgets/powerbid_bottom_nav_bar.dart';
import 'match_history_screen.dart';
import 'settings_screen.dart';
import '../widgets/legal_links_footer.dart';
import '../widgets/age_verification_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  final Map<String, dynamic>? initialProfileData;
  final bool autoFetch;

  const ProfileScreen({
    super.key,
    this.initialTab = 0,
    this.initialProfileData,
    this.autoFetch = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _achievementsList = [];
  List<Map<String, dynamic>> _historyList = [];
  bool _isLoading = true;
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    if (widget.initialProfileData != null) {
      _profileData = widget.initialProfileData;
      _isLoading = false;
    }
    if (widget.autoFetch) {
      SocketService.instance.connect();
      _fetchProfileData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        SocketService.instance.getPlayerProfile(),
        SocketService.instance.getAchievements(),
        SocketService.instance.getMatchHistory(limit: 5),
      ]);
      final prof = results[0] as Map<String, dynamic>?;
      final ach = results[1] as List<Map<String, dynamic>>? ?? [];
      final hist = results[2] as List<Map<String, dynamic>>? ?? [];

      if (mounted) {
        final localCustomName = AuthService.instance.currentUsername;
        final hasLocalCustom = localCustomName != null &&
            localCustomName.trim().isNotEmpty &&
            !localCustomName.startsWith('Guest_') &&
            !localCustomName.startsWith('Player_');

        if (prof != null && prof['username'] != null) {
          final uname = (prof['username'] as String).trim();
          final isGenericFallback = uname.isEmpty ||
              uname == 'GuestPlayer' ||
              uname.startsWith('Guest_') ||
              uname.startsWith('Player_');

          if (!isGenericFallback && uname.isNotEmpty) {
            AuthService.instance.setUsername(uname);
          } else if (hasLocalCustom) {
            final targetName = localCustomName.trim();
            prof['username'] = targetName;
            SocketService.instance.updateUsername(targetName);
          }
        } else if (hasLocalCustom && prof != null) {
          final targetName = localCustomName.trim();
          prof['username'] = targetName;
          SocketService.instance.updateUsername(targetName);
        }

        if (prof != null && prof['coinBalance'] != null) {
          AuthService.instance.updateCoinBalance(prof['coinBalance'] as int);
        }
        AuthService.instance.refreshAccountStatus();

        setState(() {
          _profileData = prof;
          _achievementsList = ach;
          _historyList = hist;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEditUsernameDialog() {
    final localCustomName = AuthService.instance.currentUsername;
    final serverName = _profileData?['username'] as String?;
    final isServerGeneric = serverName == null ||
        serverName.isEmpty ||
        serverName == 'GuestPlayer' ||
        serverName.startsWith('Guest_') ||
        serverName.startsWith('Player_');
    final hasLocalCustom = localCustomName != null &&
        localCustomName.trim().isNotEmpty &&
        !localCustomName.startsWith('Guest_') &&
        !localCustomName.startsWith('Player_');

    _usernameController.text = hasLocalCustom
        ? localCustomName.trim()
        : (!isServerGeneric ? serverName : AuthService.instance.defaultDisplayName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.navySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppTheme.surfaceBorder, width: 1.2),
          ),
          title: Text(
            'Update Username',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _usernameController,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'New Username (3-20 chars)',
                  labelStyle: TextStyle(color: AppTheme.mutedText),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.blueAccent),
                  ),
                  filled: true,
                  fillColor: AppTheme.secondarySurface,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppTheme.mutedText)),
            ),
            ElevatedButton(
              onPressed: _isUpdatingName ? null : _handleUpdateUsername,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleUpdateUsername() async {
    final newName = _usernameController.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isUpdatingName = true;
    });

    final res = await SocketService.instance.updateUsername(newName);
    if (mounted) {
      setState(() {
        _isUpdatingName = false;
      });
      Navigator.pop(context);

      if (res['success'] == true && res['profile'] != null) {
        final updatedName = res['profile']['username'] as String? ?? newName;
        AuthService.instance.setUsername(updatedName);
        setState(() {
          _profileData = res['profile'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username updated successfully!'),
            backgroundColor: AppTheme.blueAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to update username.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localCustomName = AuthService.instance.currentUsername;
    final serverName = _profileData?['username'] as String?;
    final isServerGeneric = serverName == null ||
        serverName.isEmpty ||
        serverName == 'GuestPlayer' ||
        serverName.startsWith('Guest_') ||
        serverName.startsWith('Player_');
    final hasLocalCustom = localCustomName != null &&
        localCustomName.trim().isNotEmpty &&
        !localCustomName.startsWith('Guest_') &&
        !localCustomName.startsWith('Player_');

    final username = hasLocalCustom
        ? localCustomName.trim()
        : (!isServerGeneric
            ? serverName
            : AuthService.instance.defaultDisplayName);
    final matchesPlayed = _profileData?['matchesPlayed'] ?? 0;
    final matchesWon = _profileData?['matchesWon'] ?? 0;
    final matchesTied = _profileData?['matchesTied'] ?? 0;
    final winRate = _profileData?['winRate'] ?? 0;
    final totalPurchased = _profileData?['totalCharactersPurchased'] ?? 0;
    final unlockedCount = _profileData?['achievementsUnlockedCount'] ?? 0;
    final totalAchCount = _profileData?['totalAchievementsCount'] ?? 7;
    final winStreak = _profileData?['winStreak'] ?? 0;
    final bestWinStreak = _profileData?['bestWinStreak'] ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.mainBackground,
        elevation: 0,
        title: Text(
          'Player Profile',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_rounded, color: AppTheme.textPrimary, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppTheme.textPrimary, size: 22),
            onPressed: _fetchProfileData,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.goldHighlight))
            : NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildUserHeaderCard(context, username),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        indicatorColor: AppTheme.arcadeRed,
                        indicatorWeight: 3,
                        labelColor: AppTheme.arcadeRed,
                        unselectedLabelColor: AppTheme.textSecondary,
                        labelStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        tabs: const [
                          Tab(text: 'Stats & Badges'),
                          Tab(text: 'Match History'),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatsAndAchievementsTab(
                      matchesPlayed: matchesPlayed,
                      matchesWon: matchesWon,
                      matchesTied: matchesTied,
                      winRate: winRate,
                      totalPurchased: totalPurchased,
                      unlockedCount: unlockedCount,
                      totalAchCount: totalAchCount,
                      winStreak: winStreak,
                      bestWinStreak: bestWinStreak,
                    ),
                    _buildRecentHistoryTab(),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const PowerBidBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildUserHeaderCard(BuildContext context, String username) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Edit Camera badge
              AvatarWidget(
                radius: 34,
                isEditable: true,
                onEditPressed: () => AvatarSelectionSheet.show(context, username: username),
              ),
              const SizedBox(width: 14),

              // Username & Actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _showEditUsernameDialog,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppTheme.secondarySurface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: AppTheme.goldHighlight,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Edit Photo / Avatar Pill Button
                    GestureDetector(
                      onTap: () => AvatarSelectionSheet.show(context, username: username),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppTheme.secondarySurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.blueAccent.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_camera_rounded, size: 12, color: AppTheme.textPrimary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Change Avatar',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.textPrimary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),

          // Player ID, Coins, and Account Link status pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // PB-ID Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: AppTheme.secondarySurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.softMustardYellow,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_rounded, size: 14, color: Color(0xFFB45309)),
                    const SizedBox(width: 5),
                    Text(
                      () {
                        String rawId = _profileData?['publicPlayerId'] ?? AuthService.instance.publicPlayerId ?? _profileData?['playerId'] ?? 'OCT-PENDING';
                        if (rawId.startsWith('PB-')) {
                          return 'OCT-${rawId.substring(3)}';
                        }
                        return rawId;
                      }(),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Color(0xFFB45309),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),

              // Copy ID Button
              GestureDetector(
                onTap: () {
                  String idToCopy = _profileData?['publicPlayerId'] ?? AuthService.instance.publicPlayerId ?? _profileData?['playerId'] ?? '';
                  if (idToCopy.startsWith('PB-')) {
                    idToCopy = 'OCT-${idToCopy.substring(3)}';
                  }
                  if (idToCopy.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: idToCopy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('OCT-TION Player ID copied to clipboard!'),
                        backgroundColor: AppTheme.blueAccent,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: AppTheme.secondarySurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: AppTheme.mutedText),
                      SizedBox(width: 4),
                      Text(
                        'Copy ID',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Link Account / Registered Pill
              ValueListenableBuilder<bool>(
                valueListenable: AuthService.instance.isLoggedInNotifier,
                builder: (context, isLoggedIn, _) {
                  return GestureDetector(
                    onTap: () => _showAuthModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isLoggedIn
                            ? const Color(0xFF065F46).withValues(alpha: 0.4)
                            : AppTheme.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLoggedIn ? const Color(0xFF10B981) : AppTheme.blueAccent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLoggedIn ? Icons.verified_user_rounded : Icons.link_rounded,
                            size: 13,
                            color: isLoggedIn ? const Color(0xFF10B981) : AppTheme.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isLoggedIn ? 'Registered' : 'Link Account',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: isLoggedIn ? const Color(0xFF10B981) : AppTheme.blueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Age Verification Pill (Unchangeable)
              ValueListenableBuilder<bool>(
                valueListenable: AuthService.instance.isAgeVerifiedNotifier,
                builder: (context, isVerified, _) {
                  final age = AuthService.instance.playerAge;
                  return GestureDetector(
                    onTap: () => AgeVerificationDialog.show(context),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isVerified ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.verified_user_rounded : Icons.shield_outlined,
                            size: 13,
                            color: isVerified ? AppTheme.goldHighlight : AppTheme.mutedText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Age $age (Verified)' : 'Verify Age',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: isVerified ? AppTheme.goldHighlight : AppTheme.mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsAndAchievementsTab({
    required int matchesPlayed,
    required int matchesWon,
    required int matchesTied,
    required int winRate,
    required int totalPurchased,
    required int unlockedCount,
    required int totalAchCount,
    required int winStreak,
    required int bestWinStreak,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Matches Played & Won
          Row(
            children: [
              Expanded(
                child: StatBadge(
                  label: 'MATCHES PLAYED',
                  value: '$matchesPlayed',
                  icon: Icons.sports_esports_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBadge(
                  label: 'MATCHES WON',
                  value: '$matchesWon',
                  icon: Icons.emoji_events_rounded,
                  color: AppTheme.goldHighlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Win Rate & Tied
          Row(
            children: [
              Expanded(
                child: StatBadge(
                  label: 'WIN RATE',
                  value: '$winRate%',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBadge(
                  label: 'MATCHES TIED',
                  value: '$matchesTied',
                  icon: Icons.handshake_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Characters Won
          StatBadge(
            label: 'TOTAL CHARACTERS PURCHASED',
            value: '$totalPurchased Characters',
            icon: Icons.shopping_bag_rounded,
            color: AppTheme.purpleAccent,
          ),
          const SizedBox(height: 10),

          // Row 4: Win Streak & Best Streak
          Row(
            children: [
              Expanded(
                child: StatBadge(
                  label: 'CURRENT STREAK',
                  value: '🔥 $winStreak',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatBadge(
                  label: 'BEST STREAK',
                  value: '🏆 $bestWinStreak',
                  icon: Icons.military_tech_rounded,
                  color: AppTheme.goldHighlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Achievements Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACHIEVEMENTS',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '$unlockedCount / $totalAchCount Unlocked',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Color(0xFFB45309),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Achievements List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _achievementsList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ach = _achievementsList[index];
              final title = ach['title'] ?? 'Achievement';
              final desc = ach['description'] ?? '';
              final iconText = ach['iconText'] ?? '🏆';
              final isUnlocked = ach['isUnlocked'] == true;
              final progress = ach['progress'] ?? 0;
              final threshold = ach['threshold'] ?? 1;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.pureWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUnlocked ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                    width: isUnlocked ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? AppTheme.goldHighlight.withValues(alpha: 0.15)
                            : AppTheme.secondarySurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnlocked ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          iconText,
                          style: TextStyle(
                            fontSize: 18,
                            color: isUnlocked ? AppTheme.textPrimary : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.mutedText,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: threshold > 0 ? (progress / threshold).clamp(0.0, 1.0) : 0,
                              backgroundColor: AppTheme.secondarySurface,
                              color: isUnlocked ? AppTheme.goldHighlight : AppTheme.blueAccent,
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      isUnlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                      color: isUnlocked ? AppTheme.goldHighlight : AppTheme.mutedText,
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHistoryTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (_historyList.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset + 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, color: AppTheme.mutedText, size: 48),
              SizedBox(height: 12),
              Text(
                'No Recent Matches Played',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.mutedText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 80),
      child: Column(
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _historyList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rec = _historyList[index];
              final category = (rec['category'] ?? 'Cricket').toString().toUpperCase();
              final winnerName = rec['winnerName'] ?? 'Unknown';
              final itemsCount = rec['itemCount'] ?? 10;
              final completedAt = rec['completedAt'] ?? '';
              final dateStr = completedAt.length >= 10 ? completedAt.substring(0, 10) : 'Recent';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Winner: $winnerName • $dateStr',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.mutedText,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$itemsCount Items',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.goldHighlight,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history_edu_rounded, size: 18),
            label: const Text('View Full Match History Log'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const _AuthModalWidget(),
      ),
    ).then((_) {
      if (mounted && widget.autoFetch) {
        _fetchProfileData();
      }
    });
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _ProfileTabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppTheme.mainBackground,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_ProfileTabBarDelegate oldDelegate) {
    return false;
  }
}

class _AuthModalWidget extends StatefulWidget {
  const _AuthModalWidget();

  @override
  State<_AuthModalWidget> createState() => _AuthModalWidgetState();
}

class _AuthModalWidgetState extends State<_AuthModalWidget> {
  bool _isSocialLoginMode = false; // false = Link guest account, true = Sign in to existing account
  bool _isLoading = false;
  String? _activeProvider; // 'google'
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AuthService.instance.refreshAccountStatus();
  }

  Future<void> _handleRealGoogleAuth({bool isLinkMode = true}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _activeProvider = 'google';
      _errorMessage = null;
    });

    try {
      final res = await ProviderAuthService.instance.authenticateWithGoogle();
      if (!mounted) return;

      if (res.cancelled) {
        setState(() {
          _isLoading = false;
          _activeProvider = null;
        });
        return;
      }

      if (!res.success || res.token == null) {
        setState(() {
          _isLoading = false;
          _activeProvider = null;
          _errorMessage = res.error ?? 'Google authentication failed.';
        });
        return;
      }

      // Send authentic verified ID token to backend
      var backendRes = isLinkMode
          ? await AuthService.instance.linkGoogle(idToken: res.token!)
          : await AuthService.instance.loginGoogle(idToken: res.token!);

      if (!mounted) return;

      // If linking failed because this Google account is already registered,
      // seamlessly sign into the existing account and restore all profile data.
      bool autoSwitchedToLogin = false;
      if (isLinkMode &&
          backendRes['success'] != true &&
          (backendRes['error']?.toString().contains('already linked') == true)) {
        backendRes = await AuthService.instance.loginGoogle(idToken: res.token!);
        autoSwitchedToLogin = true;
      }

      if (!mounted) return;

      if (backendRes['success'] == true) {
        Navigator.pop(context);
        if (!AuthService.instance.isAgeVerified) {
          await AgeVerificationDialog.show(context);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              autoSwitchedToLogin
                  ? 'Welcome back! Signed into your existing Google account.'
                  : (isLinkMode
                      ? 'Google account linked! Match history and stats protected.'
                      : 'Welcome back! Signed in with Google.'),
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        final rawError = backendRes['error']?.toString() ?? 'Backend verification failed.';
        final isNetwork = backendRes['isNetworkError'] == true ||
            rawError.toLowerCase().contains('connect') ||
            rawError.toLowerCase().contains('unreachable') ||
            rawError.toLowerCase().contains('timed out');

        String userFriendlyError = rawError;
        if (isNetwork) {
          userFriendlyError = 'Cannot reach OCT-TION server at:\n${SocketService.instance.serverUrl}\n\n'
              'Troubleshooting:\n'
              '• Ensure backend is running.\n'
              '• If using USB connection, run: adb reverse tcp:3000 tcp:3000\n'
              '• If using Wi-Fi, verify device and PC are on the same network.';
        }

        setState(() {
          _isLoading = false;
          _activeProvider = null;
          _errorMessage = userFriendlyError;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeProvider = null;
          _errorMessage = 'An error occurred during Google Sign-In: $e';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    await AuthService.instance.logout();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out. Reverted to guest session.'),
          backgroundColor: AppTheme.blueAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.instance.isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        return ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: AuthService.instance.accountStatusNotifier,
          builder: (context, accountStatus, _) {
            final userEmail = AuthService.instance.currentUserEmailNotifier.value;

            return Container(
              decoration: BoxDecoration(
                color: AppTheme.navySurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppTheme.surfaceBorder, width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: isLoggedIn
                      ? _buildLoggedInContent(userEmail, accountStatus)
                      : _buildUnlinkedAuthContent(accountStatus),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoggedInContent(String? email, Map<String, dynamic>? accountStatus) {
    final googleLinked = accountStatus?['googleLinked'] == true;
    final googleEmail = accountStatus?['googleEmail'] as String?;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protected Account',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email ?? googleEmail ?? 'Verified Player',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Providers status cards
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.secondarySurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Linked Authentication Provider',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _buildProviderRow(
                icon: Icons.g_mobiledata_rounded,
                title: 'Google',
                isLinked: googleLinked,
                subtitle: googleEmail ?? (googleLinked ? 'Connected' : 'Not linked'),
                onLinkTap: googleLinked ? null : () => _handleRealGoogleAuth(isLinkMode: true),
              ),
              if (email != null && email.isNotEmpty) ...[
                Divider(color: AppTheme.surfaceBorder, height: 16),
                _buildProviderRow(
                  icon: Icons.email_rounded,
                  title: 'Email',
                  isLinked: true,
                  subtitle: email,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleLogout,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
            foregroundColor: Colors.redAccent,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.redAccent),
            ),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                )
              : const Icon(Icons.logout_rounded, size: 18),
          label: const Text(
            'Log Out (Switch to Guest)',
            style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 16),
        const LegalLinksFooter(showDisclaimer: false),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildUnlinkedAuthContent(Map<String, dynamic>? accountStatus) {
    return SafeArea(
      top: false,
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
          const SizedBox(height: 14),

          // Header with Title and explicit Close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.goldHighlight.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_rounded, color: AppTheme.goldHighlight, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link Your Account',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Secure your stats & match history',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11.5,
                        color: AppTheme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppTheme.mutedText, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              ),
            ],
          ),
          SizedBox(height: 16),

          // Mode Selector: Link Guest (Keep Stats) vs Sign In (Existing User)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading ? null : () => setState(() {
                    _isSocialLoginMode = false;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: !_isSocialLoginMode ? AppTheme.goldHighlight.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_isSocialLoginMode ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                      ),
                    ),
                    child: Text(
                      'Link Guest (Keep Stats)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: !_isSocialLoginMode ? AppTheme.goldHighlight : AppTheme.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: _isLoading ? null : () => setState(() {
                    _isSocialLoginMode = true;
                    _errorMessage = null;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: _isSocialLoginMode ? AppTheme.blueAccent.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isSocialLoginMode ? AppTheme.blueAccent : AppTheme.surfaceBorder,
                      ),
                    ),
                    child: Text(
                      'Sign In (Existing User)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: _isSocialLoginMode ? AppTheme.pureWhite : AppTheme.mutedText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            !_isSocialLoginMode
                ? 'Connect your verified Google account. Your match history, stats, and profile will be permanently linked.'
                : 'Sign in to an existing Google-linked account. Your previously saved account data will be restored on this device.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: AppTheme.mutedText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.redAccent,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Provider: Google Sign-In / Account Linking
          InkWell(
            onTap: _isLoading ? null : () => _handleRealGoogleAuth(isLinkMode: !_isSocialLoginMode),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.secondarySurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.goldHighlight.withValues(alpha: 0.45),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldHighlight.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.g_mobiledata_rounded, color: AppTheme.goldHighlight, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          !_isSocialLoginMode ? 'Link with Google' : 'Sign in with Google',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Genuine Google Sign-In with Play Services',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.mutedText,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isLoading && _activeProvider == 'google'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldHighlight),
                        )
                      : const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.goldHighlight, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const SizedBox(height: 10),

          Center(
            child: TextButton.icon(
              onPressed: () => _showOAuthSetupInfo(context),
              icon: Icon(Icons.help_outline_rounded, size: 14, color: AppTheme.mutedText),
              label: Text(
                'Google OAuth Setup & SHA-1',
                style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.mutedText, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 12),
          const LegalLinksFooter(showDisclaimer: true),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showOAuthSetupInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.surfaceBorder, width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppTheme.goldHighlight, size: 20),
            const SizedBox(width: 8),
            Text(
              'Google OAuth Setup',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Android Package Name:',
                style: TextStyle(color: AppTheme.goldHighlight, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              SelectableText(
                AuthConfig.androidPackageName,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
              ),
              SizedBox(height: 10),
              Text(
                'Debug Keystore SHA-1:',
                style: TextStyle(color: AppTheme.goldHighlight, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              SelectableText(
                AuthConfig.debugSha1,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontFamily: 'monospace'),
              ),
              SizedBox(height: 12),
              Text(
                'Google Client ID: ${AuthConfig.isGoogleConfigured ? 'Configured' : 'Needs Web Client ID'}',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.blueAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderRow({
    required IconData icon,
    required String title,
    required bool isLinked,
    required String subtitle,
    VoidCallback? onLinkTap,
  }) {
    return Row(
      children: [
        Icon(icon, color: isLinked ? const Color(0xFF10B981) : AppTheme.mutedText, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: isLinked ? const Color(0xFF10B981) : AppTheme.mutedText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        if (isLinked)
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18)
        else if (onLinkTap != null)
          GestureDetector(
            onTap: onLinkTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.blueAccent),
              ),
              child: const Text(
                'Link',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.blueAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
