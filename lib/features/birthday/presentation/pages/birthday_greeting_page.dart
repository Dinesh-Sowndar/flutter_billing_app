// THESIS: Celebrate a best friend with a greeting, not a gate or dashboard.
// OWN-WORLD: Deep ink, quiet grain, softly lit teal and magenta, rounded dark panel.
// STORY: Make the birthday feel personal and the birth date unmistakable.
// FIRST VIEWPORT: A cake emblem, oversized greeting, heartfelt note, and date capsule.
// FORM: A centered, scroll-safe mobile composition; the billing experience stays separate.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BirthdayGreetingPage extends StatelessWidget {
  const BirthdayGreetingPage({super.key});

  static const Color _ink = Color(0xFF080B13);
  static const Color _panel = Color(0xFF111622);
  static const Color _teal = Color(0xFF65F2E0);
  static const Color _magenta = Color(0xFFF174D2);
  static const Color _text = Color(0xFFF5F7FC);
  static const Color _muted = Color(0xFFBEC7D7);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: _ink,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _ink,
        body: Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _BirthdayBackdropPainter()),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 24,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _buildGreetingPanel(context),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingPanel(BuildContext context) {
    final displayStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
          color: _text,
          fontSize: 42,
          height: 1.04,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151B29), _panel, Color(0xFF10131D)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: _teal.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.09),
            blurRadius: 38,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCakeEmblem(),
          const SizedBox(height: 30),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Happy\n'),
                  TextSpan(
                    text: 'Birthday!',
                    style: const TextStyle(color: _teal),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: displayStyle,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'To my favorite human — may your day be full of '
            'the little things that make you happiest.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: _muted,
                  height: 1.65,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 26),
          _buildBirthDate(context),
          const SizedBox(height: 26),
          Container(
            width: 42,
            height: 1,
            decoration: BoxDecoration(
              color: _magenta.withValues(alpha: 0.8),
              boxShadow: [
                BoxShadow(
                  color: _magenta.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Always cheering you on',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _text,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCakeEmblem() {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF161E2A),
        border: Border.all(color: _teal.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.cake_rounded,
            size: 54,
            color: _teal.withValues(alpha: 0.95),
          ),
          Positioned(
            top: 14,
            right: 20,
            child: Icon(
              Icons.auto_awesome,
              size: 17,
              color: _magenta.withValues(alpha: 0.95),
            ),
          ),
          Positioned(
            left: 17,
            bottom: 24,
            child: Icon(
              Icons.circle,
              size: 6,
              color: _magenta.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthDate(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF0C111B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_rounded, color: _magenta, size: 22),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    Text(
                      'BORN ON',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '28 October 2004',
                      semanticsLabel: '28 October 2004',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayBackdropPainter extends CustomPainter {
  const _BirthdayBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [BirthdayGreetingPage._ink, Color(0xFF0B0F19)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final tealGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          BirthdayGreetingPage._teal.withValues(alpha: 0.12),
          BirthdayGreetingPage._teal.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.88, size.height * 0.25),
          radius: size.width * 0.7,
        ),
      );
    canvas.drawRect(Offset.zero & size, tealGlow);

    final magentaGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          BirthdayGreetingPage._magenta.withValues(alpha: 0.09),
          BirthdayGreetingPage._magenta.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.08, size.height * 0.78),
          radius: size.width * 0.65,
        ),
      );
    canvas.drawRect(Offset.zero & size, magentaGlow);

    for (var index = 0; index < 105; index++) {
      final x = ((index * 73) % 997) / 997 * size.width;
      final y = ((index * 131) % 991) / 991 * size.height;
      final radius = index % 9 == 0 ? 1.15 : 0.55;
      final color = index % 4 == 0
          ? BirthdayGreetingPage._teal
          : Colors.white;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: 0.16),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BirthdayBackdropPainter oldDelegate) => false;
}
