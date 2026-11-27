import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../theme/app_theme.dart';
import '../models/category_model.dart';
import '../models/room_model.dart';
import '../models/friend_model.dart';
import '../services/socket_service.dart';
import '../services/audio_service.dart';
import '../services/voice_chat_service.dart';
import '../utils/platform_helper.dart';
import '../widgets/custom_button.dart';
import '../widgets/player_tile.dart';
import '../widgets/section_header.dart';
import 'auction_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final String category;
  final String? topic;
  final int itemCount;
  final int maxPlayers;
  final String username;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.category,
    this.topic,
    required this.itemCount,
    this.maxPlayers = 2,
    required this.username,
    this.isHost = false,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  bool _isStarting = false;
  bool _hasNavigatedToAuction = false;

  @override
  void initState() {
    super.initState();
    // Phase 2: Lobby MUST use portrait mode
    PlatformHelper.forcePortrait();
    VoiceChatService.instance.init(widget.roomCode);

    // Reset previous auction state so stale matches don't auto-navigate
    SocketService.instance.auctionNotifier.value = null;

    SocketService.instance.connect();

    // Listen for auction start broadcast to navigate automatically
    SocketService.instance.auctionNotifier.addListener(_onAuctionStateChanged);

    // Disband notification when host leaves in lobby
    SocketService.instance.onRoomDisbanded = (reason) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    };
  }

  @override
  void dispose() {
    SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
    SocketService.instance.onRoomDisbanded = null;
    super.dispose();
  }

  void _onAuctionStateChanged() {
    if (_hasNavigatedToAuction) return;
    final state = SocketService.instance.auctionNotifier.value;
    if (state != null && state.phase != 'LOBBY' && mounted) {
      _hasNavigatedToAuction = true;
      SocketService.instance.auctionNotifier.removeListener(_onAuctionStateChanged);
      AudioService().playSfx(SfxType.auctionStart);
      final room = SocketService.instance.currentRoomNotifier.value;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuctionScreen(
            categoryDisplayName: room?.categoryDisplayName ?? CategoryModel.defaultDisplayName(widget.category),
          ),
        ),
      );
    }
  }

  void _showHostSettingsModal(BuildContext context, RoomModel? room) {
    AudioService().playSfx(SfxType.buttonClick);

    // Initial category options preloaded from canonical categories
    List<CategoryModel> categoryOptions = CategoryModel.mergeAndDeduplicate([]);

    // Safely resolve initial selected category
    String selectedCategory = CategoryModel.resolveSelectedId(
      room?.category ?? widget.category,
      categoryOptions,
    );
    final maxP = room?.maxPlayers ?? widget.maxPlayers;
    final rawItemCount = room?.totalItems ?? widget.itemCount;
    int selectedItemCount = (rawItemCount >= 4) ? rawItemCount : (4 * maxP);
    int selectedTimerDuration = room?.timerDuration ?? 15;
    bool hasInitiatedLiveFetch = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!hasInitiatedLiveFetch) {
              hasInitiatedLiveFetch = true;
              if (SocketService.instance.isConnectedNotifier.value) {
                SocketService.instance.getCategories().then((liveCats) {
                  if (liveCats.isNotEmpty) {
                    final merged = CategoryModel.mergeAndDeduplicate(liveCats);
                    setModalState(() {
                      categoryOptions = merged;
                      selectedCategory = CategoryModel.resolveSelectedId(
                        selectedCategory,
                        categoryOptions,
                      );
                    });
                  }
                }).catchError((_) {
                  // Silently fallback to canonical list
                });
              }
            }

            // Ensure selectedCategory is guaranteed to exist in categoryOptions
            final safeSelectedCategory = CategoryModel.resolveSelectedId(
              selectedCategory,
              categoryOptions,
            );
            if (safeSelectedCategory != selectedCategory) {
              selectedCategory = safeSelectedCategory;
            }

            // Guarantee strictly unique DropdownMenuItem values
            final uniqueItems = <DropdownMenuItem<String>>[];
            final seenIds = <String>{};
            for (final cat in categoryOptions) {
              if (seenIds.add(cat.id)) {
                uniqueItems.add(
                  DropdownMenuItem<String>(
                    value: cat.id,
                    child: Text(
                      cat.name,
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ROOM CUSTOMIZATION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    dropdownColor: AppTheme.surfaceLight,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: uniqueItems,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Auction Characters Quota (Must Buy)', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [4, 5, 6].map((perP) {
                      final totalCnt = perP == 6 ? 70 : (perP == 5 ? 60 : 50);
                      final isSel = selectedItemCount == totalCnt;
                      return ChoiceChip(
                        label: Text('$totalCnt Pool (Must Buy $perP)'),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedItemCount = totalCnt);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Bidding Timer Duration', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [5, 10, 15, 20, 30, 45].map((t) {
                      final isSel = selectedTimerDuration == t;
                      return ChoiceChip(
                        label: Text('${t}s Timer'),
                        selected: isSel,
                        selectedColor: AppTheme.primary,
                        onSelected: (sel) {
                          if (sel) setModalState(() => selectedTimerDuration = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Apply Room Settings',
                    icon: Icons.check,
                    onPressed: () async {
                      AudioService().playSfx(SfxType.buttonClick);
                      Navigator.of(context).pop();
                      try {
                        final resolvedCharsPerPlayer = selectedItemCount == 70 ? 6 : (selectedItemCount == 60 ? 5 : 4);
                        await SocketService.instance.updateRoomSettings(
                          roomCode: widget.roomCode,
                          category: selectedCategory,
                          itemCount: selectedItemCount,
                          timerDuration: selectedTimerDuration,
                          charactersPerPlayer: resolvedCharsPerPlayer,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Room settings updated successfully.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString().replaceAll('Exception: ', '')),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleStartAuction() async {
    setState(() {
      _isStarting = true;
    });

    try {
      await SocketService.instance.startAuction();
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
          _isStarting = false;
        });
      }
    }
  }

  Future<void> _showInviteFriendsSheet(BuildContext context) async {
    AudioService().playSfx(SfxType.buttonClick);
    List<FriendModel> friends = [];
    bool loading = true;
    final Set<String> selectedPublicIds = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading) {
              SocketService.instance.getFriendsList().then((list) {
                if (ctx.mounted) {
                  setModalState(() {
                    friends = list;
                    loading = false;
                  });
                }
              }).catchError((_) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                  });
                }
              });
            }

            return SafeArea(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Invite Friends to Room',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (selectedPublicIds.isNotEmpty)
                          Text(
                            '${selectedPublicIds.length} Selected',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose friends to send an instant room invitation notification.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                      )
                    else if (friends.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 40, color: AppTheme.textSecondary),
                              SizedBox(height: 12),
                              Text(
                                'No friends found. Add friends using their Player ID.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (context, idx) {
                            final friend = friends[idx];
                            final isSelected = selectedPublicIds.contains(friend.publicPlayerId);

                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: AppTheme.accent,
                              checkColor: Colors.black,
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppTheme.primary,
                                    child: Text(
                                      friend.avatarText,
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          friend.username,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${friend.publicPlayerId} • ${friend.isOnline ? "Online" : "Offline"}',
                                          style: TextStyle(
                                            color: friend.isOnline ? AppTheme.success : AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedPublicIds.add(friend.publicPlayerId);
                                  } else {
                                    selectedPublicIds.remove(friend.publicPlayerId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: selectedPublicIds.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              try {
                                final res = await SocketService.instance.inviteFriendsToRoom(
                                  widget.roomCode,
                                  selectedPublicIds.toList(),
                                );
                                if (context.mounted) {
                                  if (res['success'] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Invitations sent to ${res['invitedCount'] ?? selectedPublicIds.length} friends!'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error'] ?? 'Failed to send invitations.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              }
                            },
                      child: Text(
                        selectedPublicIds.isEmpty
                            ? 'Select Friends to Invite'
                            : 'Send Invitations (${selectedPublicIds.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showShareInviteLinkSheet(BuildContext context) async {
    AudioService().playSfx(SfxType.buttonClick);
    String? inviteUrl = 'https://powerbid-game-server.onrender.com/join/${widget.roomCode}';
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (loading && inviteUrl == null && error == null) {
              SocketService.instance.createInviteLink(widget.roomCode).then((res) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                    if (res['success'] == true && res['inviteUrl'] != null) {
                      inviteUrl = res['inviteUrl'].toString();
                    } else {
                      error = res['error'] ?? 'Failed to generate link.';
                    }
                  });
                }
              }).catchError((e) {
                if (ctx.mounted) {
                  setModalState(() {
                    loading = false;
                    error = e.toString().replaceAll('Exception: ', '');
                  });
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Share Room Invitation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share an unguessable deep link. Friends can view the room preview and join directly.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                      )
                    else if (error != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.link_rounded, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                inviteUrl ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppTheme.accent, size: 20),
                              tooltip: 'Copy Link',
                              onPressed: () {
                                if (inviteUrl != null) {
                                  Clipboard.setData(ClipboardData(text: inviteUrl!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Invitation link copied to clipboard!'),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                final targetUrl = 'https://powerbid-game-server.onrender.com/join/${widget.roomCode}';
                                final msg = '🔥 Join my OCT-TION auction room!\n\n'
                                    'Room Code: ${widget.roomCode}\n\n'
                                    '👉 Tap to open in app: $targetUrl\n'
                                    '(Or open OCT-TION and enter code: ${widget.roomCode})';
                                Share.share(msg, subject: 'OCT-TION Auction Room ${widget.roomCode}');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Share Link', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () {
                                final targetUrl = 'https://powerbid-game-server.onrender.com/join/${widget.roomCode}';
                                final msg = '🔥 Join my OCT-TION auction room!\n\n'
                                    'Room Code: ${widget.roomCode}\n\n'
                                    '👉 Tap to open in app: $targetUrl\n'
                                    '(Or open OCT-TION and enter code: ${widget.roomCode})';
                                Share.share(msg, subject: 'OCT-TION Auction Room ${widget.roomCode}');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RoomModel?>(
      valueListenable: SocketService.instance.currentRoomNotifier,
      builder: (context, room, child) {
        final currentPlayers = room?.players ?? [];
        final hostId = room?.hostId;
        final currentSocketId = SocketService.instance.socketId;
        final isHost = widget.isHost ||
            (currentSocketId != null && hostId == currentSocketId) ||
            (room == null && widget.isHost) ||
            (room != null &&
                room.players.any((p) =>
                    p.isHost &&
                    (p.name == widget.username ||
                        (currentSocketId != null && p.id == currentSocketId))));

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              await SocketService.instance.leaveRoom();
            }
          },
          child: Scaffold(
          appBar: AppBar(
            title: const Text('Lobby Room'),
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                onPressed: () async {
                  await SocketService.instance.leaveRoom();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Room Code Header Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.surfaceLight),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ROOM CODE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.roomCode,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accent,
                                letterSpacing: 6,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy_rounded, color: AppTheme.textSecondary, size: 20),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: widget.roomCode));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Room code copied to clipboard')),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text('Category: ${room?.categoryDisplayName ?? CategoryModel.defaultDisplayName(widget.category)} • Topic: ${room?.topicDisplayName ?? (widget.topic != null ? CategoryModel.defaultDisplayName(widget.topic!) : room?.categoryDisplayName ?? CategoryModel.defaultDisplayName(widget.category))}'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            Chip(
                              label: Text('${room?.totalItems ?? widget.itemCount} Items'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                            ),
                            Chip(
                              label: Text('Timer: ${room?.timerDuration ?? 15}s'),
                              backgroundColor: AppTheme.surfaceLight,
                              labelStyle: const TextStyle(fontSize: 11, color: AppTheme.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Invite Friends', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showInviteFriendsSheet(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: const Text('Share Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () => _showShareInviteLinkSheet(context),
                              ),
                            ),
                          ],
                        ),
                        if (isHost) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('CUSTOMIZE ROOM SETTINGS', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showHostSettingsModal(context, room),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Players Section Header
                  SectionHeader(
                    title: 'Room Participants (${currentPlayers.length}/${room?.maxPlayers ?? widget.maxPlayers})',
                    subtitle: isHost
                        ? 'You are Host. Start when all players join.'
                        : 'Waiting for host to start match...',
                  ),
                  const SizedBox(height: 12),

                  // Synchronized Player Roster List with Voice Chat & Host One-By-One Control
                  Expanded(
                    child: currentPlayers.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.accent),
                          )
                        : ValueListenableBuilder<Map<String, PlayerVoiceState>>(
                            valueListenable: VoiceChatService.instance.playerStatesNotifier,
                            builder: (context, voiceStates, _) {
                              return ValueListenableBuilder<bool>(
                                valueListenable: VoiceChatService.instance.isMicMutedNotifier,
                                builder: (context, isSelfMuted, _) {
                                  return ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    cacheExtent: 500.0,
                                    itemCount: currentPlayers.length,
                                    itemBuilder: (context, index) {
                                      final player = currentPlayers[index];
                                      final isMe = player.id == currentSocketId;
                                      final voiceState = voiceStates[player.id];
                                      final isPlayerMuted = isMe ? isSelfMuted : (voiceState?.isMuted ?? true);
                                      final isSpeaking = !isPlayerMuted && (voiceState?.isSpeaking == true);

                                      return RepaintBoundary(
                                        key: ValueKey(player.id),
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: PlayerTile(
                                          name: player.name,
                                          isHost: player.isHost,
                                          isMe: isMe,
                                          isMuted: isPlayerMuted,
                                          isSpeaking: isSpeaking,
                                          canModerate: isHost && !isMe,
                                          winStreak: player.winStreak,
                                          onMicToggle: () async {
                                            if (isHost && !isMe) {
                                              final newMuted = !isPlayerMuted;
                                              VoiceChatService.instance.hostMutePlayer(player.id, newMuted);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(newMuted ? 'Host muted ${player.name}' : 'Host unmuted ${player.name}'),
                                                  duration: const Duration(milliseconds: 900),
                                                ),
                                              );
                                            } else if (isMe) {
                                              final res = await VoiceChatService.instance.toggleMic(context: context);
                                              if (mounted) {
                                                if (res['success'] == true) {
                                                  VoiceChatService.showMicNotification(context, isMuted: res['isMuted'] == true);
                                                } else if (res['message'] != null) {
                                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      behavior: SnackBarBehavior.floating,
                                                      width: 270,
                                                      backgroundColor: const Color(0xFF1B1626),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16),
                                                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                                                      ),
                                                      content: Text(
                                                        res['message'] as String,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(color: AppTheme.warmIvory, fontSize: 12),
                                                      ),
                                                      duration: const Duration(milliseconds: 1400),
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  );
                                },
                              );
                            },
                          ),
                  ),

                  // Host Start Button / Participant Waiting Banner
                  if (isHost)
                    CustomButton(
                      label: 'Start Real-Time Auction',
                      icon: Icons.play_arrow_rounded,
                      isLoading: _isStarting,
                      onPressed: _handleStartAuction,
                    )
                  else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Waiting for Host to start match...',
                                style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
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
    },
  );
}
}
