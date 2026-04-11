import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/data/hive_database.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _dotsController;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  bool _isMinimiumSplashTimePassed = false;

  @override
  void initState() {
    super.initState();

    // Logo: scales up + fades in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // Text: slides up + fades in
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    // Dots: repeating pulse animation
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Sequence: logo first, then text
    _logoController.forward().then((_) {
      _textController.forward();
    });

    // Navigate after 3 seconds, but check auth state first
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _isMinimiumSplashTimePassed = true;
      _navigateBasedOnAuth();
    });
  }

  void _navigateBasedOnAuth() {
    final isOnboardingCompleted = HiveDatabase.settingsBox
        .get(HiveDatabase.onboardingCompletedKey, defaultValue: false) as bool;
    if (!isOnboardingCompleted) {
      context.go('/onboarding');
      return;
    }

    final authState = context.read<AuthBloc>().state;
    // If still resolving session, wait. (The router will handle it if it changes later,
    // but splash explicitly redirects right now).
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      // Just wait for stream to settle.
      return;
    }

    context.go('/');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              // If the timer finished but auth was still loading,
              // this listener catches when it finally resolves.
              if (_isMinimiumSplashTimePassed &&
                  state.status != AuthStatus.initial &&
                  state.status != AuthStatus.loading) {
                // If 3 seconds have passed, navigate.
                _navigateBasedOnAuth();
              }
            },
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Animated Logo
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(36),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/images/quick_receipt.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Animated App Name + Tagline
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                           Text(
                            'QuickReceipt',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28.sp,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Smart Billing, Simplified.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Loading dots
                  _AnimatedLoadingDots(controller: _dotsController),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLoadingDots extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedLoadingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final delay = index * 0.2;
        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(delay, delay + 0.6, curve: Curves.easeInOut),
        );
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  Colors.white.withValues(alpha: 0.3 + 0.7 * animation.value),
            ),
            transform: Matrix4.translationValues(0, -6 * animation.value, 0),
          ),
        );
      }),
    );
  }
}
