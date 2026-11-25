import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/loading_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AuctionGameApp());
}

class AuctionGameApp extends StatefulWidget {
  final Widget? home;
  const AuctionGameApp({super.key, this.home});

  @override
  State<AuctionGameApp> createState() => _AuctionGameAppState();
}

class _AuctionGameAppState extends State<AuctionGameApp> {
  final SettingsService _settings = SettingsService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
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
