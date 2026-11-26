import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../models/category_model.dart';
import '../widgets/custom_button.dart';
import '../widgets/section_header.dart';
import '../widgets/room_preview_dialog.dart';
import 'lobby_screen.dart';
import 'mode_selection_screen.dart';

class CreateJoinRoomScreen extends StatefulWidget {
  final String selectedCategory;
  final String selectedTopic;
  final String gameMode;
  final int itemCount;

  const CreateJoinRoomScreen({
    super.key,
    this.selectedCategory = 'sports',
    this.selectedTopic = 'cricket',
    this.gameMode = 'AUCTION_TEAM_CHALLENGE',
    this.itemCount = 10,
  });

  @override
  State<CreateJoinRoomScreen> createState() => _CreateJoinRoomScreenState();
}

class _CreateJoinRoomScreenState extends State<CreateJoinRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _roomCodeController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _serverUrlController = TextEditingController();
  final SettingsService _settings = SettingsService();

  // Part 2: Exactly 7 selectable max players options: 2, 3, 4, 5, 6, 7, 8
  static const List<int> supportedMaxPlayers = [2, 3, 4, 5, 6, 7, 8];
  int _selectedMaxPlayers = 4;

  // 4 items minimum per player (8 players = 32 characters, 2 players = 8 characters)
  int _itemsPerPlayer = 4;
  int get _selectedItemCount => _selectedMaxPlayers * _itemsPerPlayer;

  // Part 2: Exactly 6 selectable duration options: 10s, 15s, 20s, 30s, 45s, 60s
  static const List<int> supportedTimerDurations = [10, 15, 20, 30, 45, 60];
  int _selectedTimerDuration = 15;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onThemeChanged);
    _tabController = TabController(length: 2, vsync: this);
    _serverUrlController.text = SocketService.instance.serverUrl;

    final currentName = AuthService.instance.currentUsername;
    if (currentName != null && currentName.isNotEmpty) {
      _usernameController.text = currentName;
    } else {
      _usernameController.text = AuthService.instance.defaultDisplayName;
    }

    SocketService.instance.connect();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _settings.removeListener(_onThemeChanged);
    _tabController.dispose();
    _roomCodeController.dispose();
    _usernameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  String _getTopicDisplayName() {
    if (widget.selectedCategory == 'marvel') {
      return 'Marvel Characters';
    }
    return CategoryModel.defaultDisplayName(widget.selectedTopic);
  }

  Future<void> _handleCreateRoom() async {
    final enteredName = _usernameController.text.trim();
    final username = enteredName.isNotEmpty
        ? enteredName
        : AuthService.instance.defaultDisplayName;

    if (enteredName.isNotEmpty && enteredName != AuthService.instance.currentUsername) {
      AuthService.instance.setUsername(enteredName);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SocketService.instance.createRoom(
        username: username,
        category: widget.selectedCategory,
        topic: widget.selectedTopic,
        gameMode: widget.gameMode,
        itemCount: _selectedItemCount,
        timerDuration: _selectedTimerDuration,
        maxPlayers: _selectedMaxPlayers,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: room.roomCode,
            category: room.category,
            topic: room.topic,
            itemCount: _selectedItemCount,
            maxPlayers: _selectedMaxPlayers,
            username: username,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleJoinRoom() async {
    final enteredName = _usernameController.text.trim();
    final username = enteredName.isNotEmpty
        ? enteredName
        : AuthService.instance.defaultDisplayName;

    if (enteredName.isNotEmpty && enteredName != AuthService.instance.currentUsername) {
      AuthService.instance.setUsername(enteredName);
    }
    final input = _roomCodeController.text.trim();

    if (input.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-character room code or invite link')),
      );
      return;
    }

    if (input.contains('/invite/') || input.length > 8) {
      final token = input.contains('/invite/') ? input.split('/invite/').last.split('?').first : input;
      RoomPreviewDialog.show(context, inviteToken: token, defaultUsername: username);
      return;
    }

    final roomCode = input;

    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SocketService.instance.joinRoom(
        username: username,
        roomCode: roomCode,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: room.roomCode,
            category: room.category,
            topic: room.topic,
            itemCount: room.totalItems,
            username: username,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleQuickMatch() async {
    final enteredName = _usernameController.text.trim();
    final username = enteredName.isNotEmpty
        ? enteredName
        : AuthService.instance.defaultDisplayName;

    if (enteredName.isNotEmpty && enteredName != AuthService.instance.currentUsername) {
      AuthService.instance.setUsername(enteredName);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final room = await SocketService.instance.findPublicRoom(category: widget.selectedCategory);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            roomCode: room.roomCode,
            category: room.category,
            topic: room.topic,
            itemCount: room.totalItems,
            username: username,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active public match found. Hosting a new public room for you...'),
          backgroundColor: AppTheme.trueChampagneGold,
        ),
      );
      try {
        await _handleCreateRoom();
      } catch (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.deepBlackBurgundy,
        appBar: AppBar(
          title: Text(
            'Online Multiplayer',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warmIvory),
          ),
          backgroundColor: AppTheme.darkCharcoalBurgundy,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.warmIvory),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.trueChampagneGold,
            indicatorWeight: 3,
            labelColor: AppTheme.trueChampagneGold,
            unselectedLabelColor: AppTheme.mutedText,
            tabs: const [
              Tab(text: 'Create Room'),
              Tab(text: 'Join Room'),
            ],
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Match Matchmaking Banner (Phase 5)
                _buildQuickMatchBanner(),
                const SizedBox(height: 20),

                // Player Profile Input Section
                SectionHeader(
                  title: 'Player Profile',
                  subtitle: 'Name displayed in room and live auction',
                  trailing: ValueListenableBuilder<bool>(
                    valueListenable: SocketService.instance.isConnectedNotifier,
                    builder: (context, isConnected, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : AppTheme.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConnected ? AppTheme.success : AppTheme.error,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isConnected ? AppTheme.success : AppTheme.error,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isConnected ? 'Online' : 'Connecting...',
                              style: TextStyle(
                                color: isConnected ? AppTheme.success : AppTheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _usernameController,
                  style: TextStyle(color: AppTheme.warmIvory, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: TextStyle(color: AppTheme.mutedText),
                    hintText: 'Enter your player name',
                    hintStyle: TextStyle(color: AppTheme.mutedText),
                    prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.trueChampagneGold),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.surfaceBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.trueChampagneGold, width: 1.8),
                    ),
                    filled: true,
                    fillColor: AppTheme.darkCharcoalBurgundy,
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Content
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return _tabController.index == 0
                        ? _buildCreateRoomContent()
                        : _buildJoinRoomContent();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMatchBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCharcoalBurgundy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.trueChampagneGold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.trueChampagneGold.withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.selectedCard,
              border: Border.all(color: AppTheme.trueChampagneGold),
            ),
            child: const Icon(Icons.flash_on_rounded, color: AppTheme.trueChampagneGold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Match (Public Lobby)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warmIvory,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Join available public ${_getTopicDisplayName()} match instantly',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleQuickMatch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.trueChampagneGold,
              foregroundColor: AppTheme.deepBlackBurgundy,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Play Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomContent() {
    final topicName = _getTopicDisplayName();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live Room Summary Panel (Part 2)
        _buildLiveRoomSummary(),
        const SizedBox(height: 20),

        // Catalogue Header Capsule
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.darkCharcoalBurgundy,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.category_rounded, color: AppTheme.trueChampagneGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.trueChampagneGold,
                      ),
                    ),
                    Text(
                      'Mode: ${widget.gameMode == "POWER_COMPARISON" ? "1v1 Power Comparison" : "Auction Team Challenge"}',
                      style: TextStyle(color: AppTheme.mutedText, fontSize: 11),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ModeSelectionScreen(
                        initialCategory: widget.selectedCategory,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.trueChampagneGold.withValues(alpha: 0.6), width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Change',
                        style: TextStyle(
                          color: AppTheme.warmIvory,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.tune_rounded, color: AppTheme.trueChampagneGold, size: 13),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 1. Max Players Selection (Part 2: 7 options)
        _buildMaxPlayersSelector(),
        const SizedBox(height: 20),

        // 2. Number of Items Selection (Part 2: 10 options)
        _buildItemCountSelector(),
        const SizedBox(height: 20),

        // 3. Bidding Timer Selection (Part 2: 6 options)
        _buildBiddingTimerSelector(),
        const SizedBox(height: 24),

        // Create Room Action Button
        CustomButton(
          label: 'Create Online Room',
          icon: Icons.add_circle_outline_rounded,
          isLoading: _isLoading,
          onPressed: _handleCreateRoom,
        ),
      ],
    );
  }

  Widget _buildLiveRoomSummary() {
    final topicName = _getTopicDisplayName();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCharcoalBurgundy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.trueChampagneGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.trueChampagneGold.withValues(alpha: 0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.trueChampagneGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Live Room Summary',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warmIvory,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.trueChampagneGold, width: 0.8),
                ),
                child: const Text(
                  'CONFIGURED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.trueChampagneGold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(
            icon: Icons.category_rounded,
            label: 'Category & Topic',
            value: topicName,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.groups_rounded,
            label: 'Max Players',
            value: '$_selectedMaxPlayers Players',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.format_list_numbered_rounded,
            label: 'Auction Characters',
            value: '$_selectedItemCount Characters ($_itemsPerPlayer / Player)',
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            icon: Icons.timer_rounded,
            label: 'Bidding Duration',
            value: '$_selectedTimerDuration seconds / item',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppTheme.trueChampagneGold),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.warmIvory,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxPlayersSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_rounded, color: AppTheme.trueChampagneGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Max Players Capacity',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.warmIvory,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.trueChampagneGold, width: 1.0),
              ),
              child: Text(
                '$_selectedMaxPlayers Players',
                style: const TextStyle(
                  color: AppTheme.trueChampagneGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final count in supportedMaxPlayers)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMaxPlayers = count;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: _selectedMaxPlayers == count
                          ? const Color(0xFFF8D366)
                          : AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedMaxPlayers == count
                            ? const Color(0xFFD97706)
                            : AppTheme.surfaceBorder,
                        width: _selectedMaxPlayers == count ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _selectedMaxPlayers == count
                            ? const Color(0xFF0F172A)
                            : AppTheme.warmIvory,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded, color: AppTheme.trueChampagneGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Auction Characters',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.warmIvory,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.trueChampagneGold, width: 1.0),
              ),
              child: Text(
                '$_selectedItemCount Characters ($_itemsPerPlayer / Player)',
                style: const TextStyle(
                  color: AppTheme.trueChampagneGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final perPlayer in [4, 5, 6])
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _itemsPerPlayer = perPlayer;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _itemsPerPlayer == perPlayer
                          ? const Color(0xFFF8D366)
                          : AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _itemsPerPlayer == perPlayer
                            ? const Color(0xFFD97706)
                            : AppTheme.surfaceBorder,
                        width: _itemsPerPlayer == perPlayer ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '$perPlayer Per Player (${_selectedMaxPlayers * perPlayer} Total)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _itemsPerPlayer == perPlayer
                            ? const Color(0xFF0F172A)
                            : AppTheme.warmIvory,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBiddingTimerSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_rounded, color: AppTheme.trueChampagneGold, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Bidding Duration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.warmIvory,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.secondaryBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.trueChampagneGold, width: 1.0),
              ),
              child: Text(
                '${_selectedTimerDuration}s',
                style: const TextStyle(
                  color: AppTheme.trueChampagneGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final duration in supportedTimerDurations)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimerDuration = duration;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTimerDuration == duration
                          ? const Color(0xFFF8D366)
                          : AppTheme.secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedTimerDuration == duration
                            ? const Color(0xFFD97706)
                            : AppTheme.surfaceBorder,
                        width: _selectedTimerDuration == duration ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${duration}s',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _selectedTimerDuration == duration
                              ? const Color(0xFF0F172A)
                              : AppTheme.warmIvory,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildJoinRoomContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.darkCharcoalBurgundy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _roomCodeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: AppTheme.trueChampagneGold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Enter 6-Character Room Code',
                  labelStyle: TextStyle(color: AppTheme.mutedText),
                  hintText: 'X7K9P2',
                  hintStyle: TextStyle(color: AppTheme.mutedText.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.trueChampagneGold),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.surfaceBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.trueChampagneGold, width: 2),
                  ),
                  filled: true,
                  fillColor: AppTheme.deepBlackBurgundy,
                ),
              ),
              const SizedBox(height: 16),
              CustomButton(
                label: 'Join Online Room',
                icon: Icons.login_rounded,
                isLoading: _isLoading,
                onPressed: _handleJoinRoom,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
