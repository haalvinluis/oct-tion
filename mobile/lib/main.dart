import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';
import 'screens/create_join_room_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AuctionGameApp());
}

class AuctionGameApp extends StatefulWidget {
  final Widget? home;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const AuctionGameApp({super.key, this.home});

  @override
  State<AuctionGameApp> createState() => _AuctionGameAppState();
}

class _AuctionGameAppState extends State<AuctionGameApp> {
  final SettingsService _settings = SettingsService();
  static const MethodChannel _deeplinkChannel = MethodChannel('com.auctiongame.mobile/deeplink');

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _initDeepLinks();
  }

  void _initDeepLinks() {
    _deeplinkChannel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        final link = call.arguments?.toString();
        if (link != null) _handleIncomingLink(link);
      }
    });

    _deeplinkChannel.invokeMethod<String>('getInitialLink').then((link) {
      if (link != null) _handleIncomingLink(link);
    }).catchError((_) {});
  }

  void _handleIncomingLink(String link) {
    try {
      final uri = Uri.parse(link);
      String? roomCode;
      if (uri.scheme == 'octtion') {
        // octtion://room/ABCDEF or octtion://join/ABCDEF
        if (uri.pathSegments.isNotEmpty) {
          roomCode = uri.pathSegments.first.toUpperCase().replaceAll('/', '');
        } else if (uri.queryParameters.containsKey('room')) {
          roomCode = uri.queryParameters['room']?.toUpperCase();
        }
      } else {
        // https://powerbid-game-server.onrender.com/join/ABCDEF
        if (uri.pathSegments.isNotEmpty) {
          final seg = uri.pathSegments.last.toUpperCase().replaceAll('/', '');
          if (seg != 'JOIN' && seg != 'INVITE') {
            roomCode = seg;
          }
        }
      }
      if (roomCode != null && roomCode.length >= 4) {
        Future.delayed(const Duration(milliseconds: 600), () {
          AuctionGameApp.navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => CreateJoinRoomScreen(
                initialRoomCode: roomCode,
              ),
            ),
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AuctionGameApp.navigatorKey,
      title: 'OCT-TION',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _settings.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_settings.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: widget.home ?? const LoadingScreen(),
    );
  }
}
