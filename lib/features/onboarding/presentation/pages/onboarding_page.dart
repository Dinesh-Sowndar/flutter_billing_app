import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';
import '../widgets/onboarding_illustrations.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingStep> _steps = const [
    _OnboardingStep(
      title: 'Billing That Flows Like Magic',
      description:
          'Create polished bills in seconds and keep your counter moving with lightning-fast checkout.',
      highlights: ['Instant invoices', 'Smooth checkout', 'Fewer queue delays'],
      illustration: BillingIllustration(),
      startColor: Color(0xFF0EA5E9),
      endColor: Color(0xFF1D4ED8),
      chipColor: Color(0xFFBFDBFE),
    ),
    _OnboardingStep(
      title: 'Inventory That Updates Itself',
      description:
          'Every sale updates stock instantly so you always know what is available and what needs a refill.',
      highlights: ['Live stock sync', 'Low stock alerts', 'Less manual tracking'],
      illustration: InventoryIllustration(),
      startColor: Color(0xFF14B8A6),
      endColor: Color(0xFF0F766E),
      chipColor: Color(0xFF99F6E4),
    ),
    _OnboardingStep(
      title: 'Customer Dues, Crystal Clear',
      description:
          'Track due payments and customer history in one place, and make smarter day-to-day decisions.',
      highlights: ['Due reminders', 'Complete history', 'Better cash control'],
      illustration: DuesIllustration(),
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFEA580C),
      chipColor: Color(0xFFFED7AA),
    ),
  ];

  bool get _isLastPage => _currentIndex == _steps.length - 1;

  Future<void> _completeOnboarding() async {
    await HiveDatabase.settingsBox
        .put(HiveDatabase.onboardingCompletedKey, true);
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _goToNextPage() async {
    if (_isLastPage) {
      await _completeOnboarding();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentIndex];
    final size = MediaQuery.of(context).size;
    final isSmallHeight = size.height < 730;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              step.startColor.withValues(alpha: 0.16),
              const Color(0xFFF8FAFC),
              step.endColor.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _backgroundOrb(
                size: 220,
                color: step.startColor.withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -50,
              child: _backgroundOrb(
                size: 250,
                color: step.endColor.withValues(alpha: 0.20),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: step.endColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'QuickReceipt',
                                style: GoogleFonts.sora(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _completeOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.outfit(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _steps.length,
                        physics: const BouncingScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final current = _steps[index];
                          return Column(
                            children: [
                              const Spacer(),
                              _heroCard(current, isSmallHeight),
                              SizedBox(height: isSmallHeight ? 18 : 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                switchInCurve: Curves.easeOutCubic,
                                transitionBuilder: (child, animation) {
                                  final slide = Tween<Offset>(
                                    begin: const Offset(0.04, 0),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: slide,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  key: ValueKey(current.title),
                                  children: [
                                    Text(
                                      current.title,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.sora(
                                        fontSize: 26.sp,
                                        fontWeight: FontWeight.w700,
                                        height: 1.14,
                                        letterSpacing: -0.7,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      current.description,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.sp,
                                        color: const Color(0xFF334155),
                                        height: 1.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: current.highlights
                                          .map(
                                            (highlight) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 7,
                                              ),
                                              decoration: BoxDecoration(
                                                color: current.chipColor,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.85),
                                                ),
                                              ),
                                              child: Text(
                                                highlight,
                                                style: GoogleFonts.outfit(
                                                  color:
                                                      const Color(0xFF0F172A),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                            ],
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${_currentIndex + 1}/${_steps.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 12.sp,
                            color: const Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: List.generate(_steps.length, (index) {
                              final isActive = index == _currentIndex;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  height: 9,
                                  margin: EdgeInsets.only(
                                    right: index == _steps.length - 1 ? 0 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: isActive
                                        ? LinearGradient(
                                            colors: [
                                              step.startColor,
                                              step.endColor,
                                            ],
                                          )
                                        : null,
                                    color: isActive
                                        ? null
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [step.startColor, step.endColor],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: step.endColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _goToNextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLastPage ? 'Get Started' : 'Continue',
                                style: GoogleFonts.sora(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
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
    );
  }

  Widget _backgroundOrb({required double size, required Color color}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.93, end: 1.07),
      duration: const Duration(milliseconds: 1800),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _heroCard(_OnboardingStep step, bool isSmallHeight) {
    return Container(
      height: isSmallHeight ? 260 : 300,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            step.startColor,
            step.endColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: step.endColor.withValues(alpha: 0.34),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -14,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -8,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: isSmallHeight ? 210 : 240,
              height: isSmallHeight ? 210 : 240,
              child: step.illustration,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String description;
  final List<String> highlights;
  final Widget illustration;
  final Color startColor;
  final Color endColor;
  final Color chipColor;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.highlights,
    required this.illustration,
    required this.startColor,
    required this.endColor,
    required this.chipColor,
  });
}
