import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/hive_database.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingStep> _steps = const [
    _OnboardingStep(
      title: 'Bill Faster, Stress Less',
      description:
          'Create invoices in seconds, scan products quickly, and keep your counter moving during rush hours.',
      icon: Icons.bolt_rounded,
      startColor: Color(0xFF0EA5E9),
      endColor: Color(0xFF1D4ED8),
    ),
    _OnboardingStep(
      title: 'Track Stock Automatically',
      description:
          'Inventory updates itself after every sale so you always know what is available and what needs restocking.',
      icon: Icons.inventory_2_rounded,
      startColor: Color(0xFF14B8A6),
      endColor: Color(0xFF0F766E),
    ),
    _OnboardingStep(
      title: 'See Clear Business Insights',
      description:
          'Monitor customer dues and transaction history in one place to make better daily decisions.',
      icon: Icons.analytics_rounded,
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFEA580C),
    ),
  ];

  bool get _isLastPage => _currentIndex == _steps.length - 1;

  Future<void> _completeOnboarding() async {
    await HiveDatabase.settingsBox.put(_onboardingCompletedKey, true);
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              step.startColor.withValues(alpha: 0.14),
              Colors.white,
              step.endColor.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'QuickReceipt',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Container(
                            height: 230,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [current.startColor, current.endColor],
                              ),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      current.endColor.withValues(alpha: 0.28),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                current.icon,
                                size: 92,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 42),
                          Text(
                            current.title,
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            current.description,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF334155),
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: List.generate(
                          _steps.length,
                          (index) {
                            final isActive = index == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: isActive ? 24 : 9,
                              height: 9,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? step.endColor
                                    : const Color(0xFFCBD5E1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _goToNextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: step.endColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _isLastPage ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color startColor;
  final Color endColor;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.startColor,
    required this.endColor,
  });
}
