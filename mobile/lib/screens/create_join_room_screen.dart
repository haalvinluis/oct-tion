import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/section_header.dart';
import '../widgets/room_preview_dialog.dart';
import '../config/app_config.dart';
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

  int _selectedTimerDuration = 15;
  static const List<int> supportedTimerDurations = [5, 10, 15, 20, 30, 45];
  int _selectedItemCount = 10;
  static const List<int> supportedMatchSizes = [5, 8, 10];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedItemCount = supportedMatchSizes.contains(widget.itemCount) ? widget.itemCount : 10;
    _tabController = TabController(length: 2, vsync: this);
    _serverUrlController.text = SocketService.instance.serverUrl;

    // Authoritatively populate username from AuthService
    final currentName = AuthService.instance.currentUsername;
    if (currentName != null && currentName.isNotEmpty) {
      _usernameController.text = currentName;
    } else {
      _usernameController.text = AuthService.instance.defaultDisplayName;
    }

    SocketService.instance.connect();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    _usernameController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  String _getCatalogueName(String cat) {
    switch (cat.toLowerCase()) {
      case 'anime':
        return 'Anime Characters Catalogue';
      case 'sports':
        return 'Sports Characters Catalogue';
      case 'cartoons':
        return 'Cartoon Characters Catalogue';
      case 'superheroes':
        return 'Superhero Characters Catalogue';
      case 'marvel':
        return 'Marvel Characters Catalogue';
      case 'other':
      default:
        return 'Special Characters Catalogue';
    }
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
      final timerDuration = supportedTimerDurations.contains(_selectedTimerDuration)
          ? _selectedTimerDuration
          : 15;

      final room = await SocketService.instance.createRoom(
        username: username,
        category: widget.selectedCategory,
        topic: widget.selectedTopic,
        gameMode: widget.gameMode,
        itemCount: _selectedItemCount,
        timerDuration: timerDuration,
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

    // Support deep link or invite token input
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppTheme.deepNavyBg,
        appBar: AppBar(
          title: const Text('Online Multiplayer Room'),
          backgroundColor: AppTheme.navySurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.accent,
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
              // Username Input Section
              SectionHeader(
                title: 'Player Profile',
                subtitle: 'Set your name for room display',
                trailing: ValueListenableBuilder<bool>(
                  valueListenable: SocketService.instance.isConnectedNotifier,
                  builder: (context, isConnected, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isConnected ? AppTheme.success : AppTheme.error).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isConnected ? AppTheme.success : AppTheme.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 4,
                            backgroundColor: isConnected ? AppTheme.success : AppTheme.error,
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
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your player name',
                  prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
              ),
              const SizedBox(height: 14),

              // Server URL Config Input
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                onChanged: (val) => SocketService.instance.updateServerUrl(val),
                decoration: InputDecoration(
                  labelText: 'Game Server URL',
                  hintText: AppConfig.defaultServerUrl,
                  helperText: 'Environment: ${AppConfig.environment.toUpperCase()} • ${AppConfig.defaultServerUrl}',
                  helperStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  prefixIcon: const Icon(Icons.dns_rounded, color: AppTheme.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: AppTheme.surface,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Create Room Tab
                    SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.navySurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.category_rounded, color: AppTheme.goldHighlight, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getCatalogueName(widget.selectedCategory),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: AppTheme.accent,
                                        ),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.goldHighlight.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppTheme.goldHighlight.withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Change',
                                              style: TextStyle(
                                                color: AppTheme.goldHighlight,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 2),
                                            Icon(Icons.tune_rounded, color: AppTheme.goldHighlight, size: 13),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Mode: ${widget.gameMode == "POWER_COMPARISON" ? "Mode A: Power Comparison" : "Mode B: Auction Team Challenge"}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Auction Match Size Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.navySurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.format_list_numbered_rounded, color: AppTheme.goldHighlight, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Auction Match Size',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.goldHighlight.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.goldHighlight, width: 1),
                                      ),
                                      child: Text(
                                        '$_selectedItemCount Items',
                                        style: const TextStyle(
                                          color: AppTheme.goldHighlight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Exact number of character items auctioned in this room',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: supportedMatchSizes.map((count) {
                                    final isSelected = _selectedItemCount == count;
                                    return ChoiceChip(
                                      key: Key('match_size_chip_$count'),
                                      label: Text('$count Items'),
                                      selected: isSelected,
                                      selectedColor: AppTheme.primary,
                                      backgroundColor: AppTheme.surface,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: isSelected ? AppTheme.goldHighlight : AppTheme.surfaceBorder,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedItemCount = count;
                                          });
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Bidding Timer Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.navySurface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.timer_outlined, color: AppTheme.accent, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Bidding Timer',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accent.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.accent, width: 1),
                                      ),
                                      child: Text(
                                        '$_selectedTimerDuration Seconds',
                                        style: const TextStyle(
                                          color: AppTheme.accent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Per-item countdown limit before highest bid wins',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: supportedTimerDurations.map((duration) {
                                    final isSelected = _selectedTimerDuration == duration;
                                    return ChoiceChip(
                                      key: Key('timer_chip_$duration'),
                                      label: Text('${duration}s'),
                                      selected: isSelected,
                                      selectedColor: AppTheme.primary,
                                      backgroundColor: AppTheme.surface,
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _selectedTimerDuration = duration;
                                          });
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            label: 'Create Online Room',
                            icon: Icons.add_circle_outline_rounded,
                            isLoading: _isLoading,
                            onPressed: _handleCreateRoom,
                          ),
                        ],
                      ),
                    ),

                    // Join Room Tab
                    SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _roomCodeController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              labelText: 'Enter 6-Character Room Code',
                              hintText: 'X7K9P2',
                              prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.accent),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: AppTheme.surface,
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
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
