import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';

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
      title: 'Bill Faster, Stress Less',
      description:
          'Create invoices in seconds, scan products quickly, and keep your counter moving during rush hours.',
      highlights: ['Fast invoice flow', 'Quick barcode scan'],
      icon: Icons.bolt_rounded,
      startColor: Color(0xFF0EA5E9),
      endColor: Color(0xFF1D4ED8),
    ),
    _OnboardingStep(
      title: 'Track Stock Automatically',
      description:
          'Inventory updates itself after every sale so you always know what is available and what needs restocking.',
      highlights: ['Auto stock updates', 'Low-stock visibility'],
      icon: Icons.inventory_2_rounded,
      startColor: Color(0xFF14B8A6),
      endColor: Color(0xFF0F766E),
    ),
    _OnboardingStep(
      title: 'See Clear Business Insights',
      description:
          'Monitor customer dues and transaction history in one place to make better daily decisions.',
      highlights: ['Due tracking', 'Actionable reports'],
      icon: Icons.analytics_rounded,
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFEA580C),
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
    final isSmallHeight = size.height < 720;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              step.startColor.withValues(alpha: 0.18),
              const Color(0xFFF8FAFC),
              step.endColor.withValues(alpha: 0.16),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Text(
                        'QuickReceipt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _completeOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _steps.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final current = _steps[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          Container(
                            height: isSmallHeight ? 220 : 260,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [current.startColor, current.endColor],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      current.endColor.withValues(alpha: 0.30),
                                  blurRadius: 30,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -30,
                                  right: -26,
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -34,
                                  left: -18,
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.16),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      current.icon,
                                      size: 58,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallHeight ? 24 : 34),
                          Text(
                            current.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1.12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            current.description,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: current.highlights
                                .map(
                                  (highlight) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.84),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: current.endColor
                                            .withValues(alpha: 0.24),
                                      ),
                                    ),
                                    child: Text(
                                      highlight,
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const Spacer(),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${_currentIndex + 1}/${_steps.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: List.generate(
                          _steps.length,
                          (index) {
                            final isActive = index == _currentIndex;
                            return Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                height: 8,
                                margin: EdgeInsets.only(
                                  right: index == _steps.length - 1 ? 0 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? step.endColor
                                      : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goToNextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: step.endColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      _isLastPage ? 'Get Started' : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _OnboardingStep {
  final String title;
  final String description;
  final List<String> highlights;
  final IconData icon;
  final Color startColor;
  final Color endColor;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.highlights,
    required this.icon,
    required this.startColor,
    required this.endColor,
  });
}
