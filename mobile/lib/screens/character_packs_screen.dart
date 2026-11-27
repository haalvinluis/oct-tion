import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';

class CharacterPacksScreen extends StatefulWidget {
  const CharacterPacksScreen({super.key});

  @override
  State<CharacterPacksScreen> createState() => _CharacterPacksScreenState();
}

class _CharacterPacksScreenState extends State<CharacterPacksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _packs = [];
  List<Map<String, dynamic>> _unlockedCharacters = [];
  bool _isLoadingPacks = true;
  bool _isLoadingUnlocks = false;
  String? _purchasingPackId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPacks();
    _loadUnlockedCharacters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoadingPacks = true);
    try {
      final packs = await SocketService.instance.getCharacterPacks();
      if (mounted) {
        setState(() {
          _packs = packs;
          _isLoadingPacks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPacks = false);
    }
  }

  Future<void> _loadUnlockedCharacters() async {
    setState(() => _isLoadingUnlocks = true);
    try {
      final unlocks = await SocketService.instance.getUnlockedCharacters();
      if (mounted) {
        setState(() {
          _unlockedCharacters = unlocks;
          _isLoadingUnlocks = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingUnlocks = false);
    }
  }

  Future<void> _handlePurchase(Map<String, dynamic> pack) async {
    final packId = pack['id'] as String;
    final packName = pack['name'] as String? ?? 'Character Pack';
    final priceCoins = pack['priceCoins'] as int? ?? 5000;
    final currentCoins = AuthService.instance.coinBalance;

    if (currentCoins < priceCoins) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Insufficient coins! You need ${priceCoins - currentCoins} more coins.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.surfaceBorder, width: 1.2),
        ),
        title: Text(
          'Unlock $packName?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.pureWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'This will deduct $priceCoins virtual in-game coins from your balance. No real-money transaction will occur.',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.mutedText,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: TextStyle(color: AppTheme.mutedText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldHighlight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('BUY FOR $priceCoins COINS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _purchasingPackId = packId);
    AudioService().playSfx(SfxType.buttonClick);

    try {
      final res = await SocketService.instance.purchaseCharacterPack(packId);
      if (!mounted) return;

      if (res['success'] == true && res['result'] != null) {
        final result = res['result'] as Map;
        final unlocked = (result['unlockedCharacters'] as List?) ?? [];

        AudioService().playSfx(SfxType.matchVictory);
        _loadUnlockedCharacters();

        _showUnlockSuccessDialog(packName, unlocked);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Failed to complete pack purchase.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _purchasingPackId = null);
    }
  }

  void _showUnlockSuccessDialog(String packName, List<dynamic> unlocked) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navySurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppTheme.goldHighlight, width: 1.5),
        ),
        title: Column(
          children: [
            const Icon(Icons.stars_rounded, color: AppTheme.goldHighlight, size: 44),
            const SizedBox(height: 8),
            Text(
              'Pack Unlocked!',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.pureWhite,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              packName,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.goldHighlight,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You unlocked the following character cards:',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: unlocked.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final char = unlocked[idx] as Map;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondarySurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  color: AppTheme.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  char['characterName'] ?? 'Character',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.pureWhite,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  (char['categoryId'] ?? 'CATALOG').toString().toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.mutedText,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldHighlight,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('AWESOME!', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showEligibleCharactersModal(Map<String, dynamic> pack) {
    final previews = (pack['eligibleCharactersPreview'] as List?) ?? [];
    final packName = pack['name'] as String? ?? 'Character Pack';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navySurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              packName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.pureWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Sample Eligible Character Cards',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.mutedText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AppTheme.mutedText),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(color: AppTheme.surfaceBorder, height: 24),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: previews.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final item = previews[idx] as Map;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.secondarySurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.surfaceBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF356DFF), Color(0xFF713CFF)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['displayName'] ?? 'Character',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        color: AppTheme.pureWhite,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      (item['categoryId'] ?? 'CATALOG').toString().toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        color: AppTheme.mutedText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.deepNavyBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.surfaceBorder),
                                ),
                                child: Text(
                                  'Base ₹${item['basePrice'] ?? 50}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.goldHighlight,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavyBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navySurface,
        elevation: 0,
        title: Text(
          'Character Packs',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: AppTheme.pureWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          // Coin Balance Capsule
          ValueListenableBuilder<int>(
            valueListenable: AuthService.instance.coinBalanceNotifier,
            builder: (context, coins, _) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.goldHighlight.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: AppTheme.goldHighlight, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$coins',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.goldHighlight,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.goldHighlight,
          indicatorWeight: 3,
          labelColor: AppTheme.pureWhite,
          unselectedLabelColor: AppTheme.mutedText,
          labelStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Available Packs'),
            Tab(text: 'My Collection'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPacksTab(),
          _buildCollectionTab(),
        ],
      ),
    );
  }

  Widget _buildPacksTab() {
    if (_isLoadingPacks) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.blueAccent));
    }

    if (_packs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, color: AppTheme.mutedText, size: 48),
            const SizedBox(height: 12),
            Text(
              'No character packs available.',
              style: TextStyle(color: AppTheme.mutedText, fontFamily: AppTheme.fontFamily),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadPacks,
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.blueAccent),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: AuthService.instance.coinBalanceNotifier,
      builder: (context, userCoins, _) {
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: _packs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 18),
          itemBuilder: (context, idx) {
            final pack = _packs[idx];
            return _buildPackCard(pack, userCoins);
          },
        );
      },
    );
  }

  Widget _buildPackCard(Map<String, dynamic> pack, int userCoins) {
    final packId = pack['id'] as String;
    final name = pack['name'] as String? ?? 'Character Pack';
    final desc = pack['description'] as String? ?? '';
    final count = pack['characterCount'] as int? ?? 5;
    final price = pack['priceCoins'] as int? ?? 5000;
    final badge = pack['badge'] as String? ?? 'PACK';
    final previews = (pack['eligibleCharactersPreview'] as List?) ?? [];

    final canAfford = userCoins >= price;
    final isPurchasing = _purchasingPackId == packId;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: count == 10 ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
          width: count == 10 ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (count == 10 ? AppTheme.goldHighlight : AppTheme.blueAccent).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: count == 10
                      ? AppTheme.goldHighlight.withValues(alpha: 0.2)
                      : AppTheme.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: count == 10 ? AppTheme.goldHighlight : AppTheme.blueAccent,
                  ),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: count == 10 ? AppTheme.goldHighlight : const Color(0xFF93C5FD),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.style_rounded, color: AppTheme.mutedText, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$count CARDS',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.pureWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pack Name
          Text(
            name,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.pureWhite,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppTheme.mutedText,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),

          // Eligible Preview Horizontal Chips
          if (previews.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Eligible Characters Preview:',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEligibleCharactersModal(pack),
                  child: const Text(
                    'See All Preview >',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.blueAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: previews.take(5).length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, pIdx) {
                  final p = previews[pIdx] as Map;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: Center(
                      child: Text(
                        p['displayName'] ?? '',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.pureWhite,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Buy Button / Pricing
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (canAfford && !isPurchasing) ? () => _handlePurchase(pack) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAfford ? AppTheme.goldHighlight : AppTheme.secondarySurface,
                foregroundColor: canAfford ? Colors.black : AppTheme.mutedText,
                disabledBackgroundColor: AppTheme.secondarySurface,
                disabledForegroundColor: AppTheme.mutedText,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: isPurchasing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canAfford ? Icons.shopping_bag_rounded : Icons.lock_outline_rounded,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canAfford
                                ? 'BUY FOR $price COINS'
                                : 'NEED ${price - userCoins} MORE COINS',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionTab() {
    if (_isLoadingUnlocks) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.blueAccent));
    }

    if (_unlockedCharacters.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, color: AppTheme.mutedText, size: 56),
              const SizedBox(height: 14),
              Text(
                'No Character Cards Unlocked Yet',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.pureWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Purchase 5-card or 10-card packs in the Available Packs tab with in-game coins to build your deck.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.mutedText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('BROWSE PACKS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: _unlockedCharacters.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = _unlockedCharacters[idx];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navySurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF356DFF), Color(0xFF713CFF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['characterName'] ?? 'Character Card',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.pureWhite,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (item['categoryId'] ?? 'CATALOG').toString().toUpperCase(),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondarySurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, color: AppTheme.success, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'OWNED',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
