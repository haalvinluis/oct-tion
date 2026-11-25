import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/avatar_service.dart';
import '../services/provider_auth_service.dart';
import '../services/socket_service.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  String _statusText = 'Initializing OCT-TION...';
  double _progressValue = 0.15;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Enforce portrait orientation by default on app launch
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _startInitialization();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startInitialization() async {
    // Stage 1: Load Local Services
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      _statusText = 'Restoring player profile...';
      _progressValue = 0.40;
    });

    try {
      await AuthService.instance.init();
      await AvatarService.instance.init();
      await ProviderAuthService.instance.init();
      SettingsService();
    } catch (e) {
      debugPrint('[LoadingScreen] Local init exception: $e');
    }

    // Stage 2: Initialize Socket / Cloud Gateway
    if (!mounted) return;
    setState(() {
      _statusText = 'Connecting to auction network...';
      _progressValue = 0.75;
    });

    try {
      await SocketService.instance.init().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[LoadingScreen] Socket init timed out, proceeding in offline/fallback mode');
        },
      );
      AuthService.instance.refreshAccountStatus();
    } catch (e) {
      debugPrint('[LoadingScreen] Network init exception: $e');
    }

    // Stage 3: Ready
    if (!mounted) return;
    setState(() {
      _statusText = 'Welcome to OCT-TION';
      _progressValue = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    _navigateToHome();
  }

  void _navigateToHome() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const deepBlackBurgundy = Color(0xFF160609);
    const darkWine = Color(0xFF21080D);
    const champagneGold = Color(0xFFD6AD70);
    const softIvory = Color(0xFFF5EBDD);

    return Scaffold(
      backgroundColor: deepBlackBurgundy,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: deepBlackBurgundy,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.15),
              radius: 1.1,
              colors: [
                darkWine,
                deepBlackBurgundy,
                Color(0xFF0D0305),
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Center Branding & Emblem
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Animated Logo Emblem
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2A1014),
                                    Color(0xFF1A070B),
                                  ],
                                ),
                                border: Border.all(
                                  color: champagneGold.withValues(alpha: _glowAnimation.value),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: champagneGold.withValues(alpha: _glowAnimation.value * 0.35),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFE50914).withValues(alpha: 0.2),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 72,
                                  height: 72,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                    Icons.gavel_rounded,
                                    size: 58,
                                    color: champagneGold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // App Title
                      const Text(
                        'OCT-TION',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: softIvory,
                          letterSpacing: 6.0,
                          shadows: [
                            Shadow(
                              color: Color(0xFFD6AD70),
                              blurRadius: 18,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tagline
                      Text(
                        'MULTIPLAYER CINEMATIC AUCTIONS',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.5,
                          color: champagneGold.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Progress Indicator & Status
                Positioned(
                  left: 36,
                  right: 36,
                  bottom: 50,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 4.5,
                          child: LinearProgressIndicator(
                            value: _progressValue,
                            backgroundColor: const Color(0xFF2A1014),
                            valueColor: const AlwaysStoppedAnimation<Color>(champagneGold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Status message
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: softIvory.withValues(alpha: 0.75),
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
