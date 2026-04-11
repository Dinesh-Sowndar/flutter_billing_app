import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Screen 1 – Billing / Receipt illustration
// ─────────────────────────────────────────────────────────────
class BillingIllustration extends StatelessWidget {
  const BillingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BillingPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _BillingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 10;

    // Background soft circle
    canvas.drawCircle(
      Offset(cx, cy),
      unit * 4.2,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // Receipt body
    final receiptW = unit * 4.2;
    final receiptH = unit * 5.8;
    final receiptLeft = cx - receiptW / 2;
    final receiptTop = cy - receiptH / 2 - unit * 0.2;

    // Receipt shadow
    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(receiptLeft + 4, receiptTop + 6, receiptW, receiptH),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      shadowRect,
      Paint()..color = const Color(0xFF1D4ED8).withValues(alpha: 0.18),
    );

    // Receipt main body
    final receiptRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(receiptLeft, receiptTop, receiptW, receiptH),
      const Radius.circular(12),
    );
    canvas.drawRRect(receiptRect, Paint()..color = Colors.white);

    // Receipt top accent bar
    final accentRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(receiptLeft, receiptTop, receiptW, unit * 1.2),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      accentRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF1D4ED8)],
        ).createShader(
            Rect.fromLTWH(receiptLeft, receiptTop, receiptW, unit * 1.2)),
    );
    // Clip bottom corners of the accent
    canvas.drawRect(
      Rect.fromLTWH(
          receiptLeft, receiptTop + unit * 0.8, receiptW, unit * 0.4),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF1D4ED8)],
        ).createShader(
            Rect.fromLTWH(receiptLeft, receiptTop, receiptW, unit * 1.2)),
    );

    // Receipt header text placeholder lines (white on accent)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.18;
    canvas.drawLine(
      Offset(receiptLeft + unit * 0.8, receiptTop + unit * 0.45),
      Offset(receiptLeft + receiptW - unit * 0.8, receiptTop + unit * 0.45),
      linePaint,
    );
    linePaint.color = Colors.white.withValues(alpha: 0.5);
    linePaint.strokeWidth = unit * 0.12;
    canvas.drawLine(
      Offset(receiptLeft + unit * 1.2, receiptTop + unit * 0.8),
      Offset(receiptLeft + receiptW - unit * 1.2, receiptTop + unit * 0.8),
      linePaint,
    );

    // Content lines on receipt body
    final bodyLinePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.14;

    final lineY = receiptTop + unit * 1.7;
    for (int i = 0; i < 5; i++) {
      final y = lineY + i * unit * 0.65;
      final isShort = i == 2 || i == 4;
      bodyLinePaint.color = const Color(0xFFCBD5E1);
      canvas.drawLine(
        Offset(receiptLeft + unit * 0.7, y),
        Offset(
            receiptLeft + (isShort ? receiptW * 0.55 : receiptW - unit * 0.7),
            y),
        bodyLinePaint,
      );
      // Right-aligned "amount"
      if (!isShort) {
        bodyLinePaint.color = const Color(0xFF94A3B8);
        canvas.drawLine(
          Offset(receiptLeft + receiptW - unit * 1.5, y),
          Offset(receiptLeft + receiptW - unit * 0.7, y),
          bodyLinePaint,
        );
      }
    }

    // Dashed separator line
    final dashY = receiptTop + unit * 4.8;
    final dashPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (double dx = receiptLeft + unit * 0.6;
        dx < receiptLeft + receiptW - unit * 0.5;
        dx += unit * 0.35) {
      canvas.drawLine(
          Offset(dx, dashY), Offset(dx + unit * 0.18, dashY), dashPaint);
    }

    // Total line (bold)
    bodyLinePaint.color = const Color(0xFF0F172A);
    bodyLinePaint.strokeWidth = unit * 0.2;
    canvas.drawLine(
      Offset(receiptLeft + unit * 0.7, receiptTop + unit * 5.2),
      Offset(receiptLeft + unit * 2.0, receiptTop + unit * 5.2),
      bodyLinePaint,
    );
    bodyLinePaint.color = const Color(0xFF0EA5E9);
    canvas.drawLine(
      Offset(receiptLeft + receiptW - unit * 2.0, receiptTop + unit * 5.2),
      Offset(receiptLeft + receiptW - unit * 0.7, receiptTop + unit * 5.2),
      bodyLinePaint,
    );

    // Floating checkmark badge
    final badgeCx = receiptLeft + receiptW - unit * 0.2;
    final badgeCy = receiptTop + unit * 1.4;
    canvas.drawCircle(
      Offset(badgeCx, badgeCy),
      unit * 0.8,
      Paint()..color = const Color(0xFF22C55E),
    );
    // Checkmark
    final checkPath = Path()
      ..moveTo(badgeCx - unit * 0.32, badgeCy + unit * 0.02)
      ..lineTo(badgeCx - unit * 0.08, badgeCy + unit * 0.28)
      ..lineTo(badgeCx + unit * 0.32, badgeCy - unit * 0.22);
    canvas.drawPath(
      checkPath,
      Paint()
        ..color = Colors.white
        ..strokeWidth = unit * 0.14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Floating coins
    _drawCoin(canvas, Offset(cx - unit * 3.6, cy - unit * 1.8), unit * 0.65,
        const Color(0xFFFBBF24));
    _drawCoin(canvas, Offset(cx + unit * 3.4, cy + unit * 1.2), unit * 0.52,
        const Color(0xFFFBBF24));
    _drawCoin(canvas, Offset(cx - unit * 3.0, cy + unit * 2.2), unit * 0.42,
        const Color(0xFFF59E0B));

    // Small sparkles
    _drawSparkle(
        canvas, Offset(cx + unit * 3.2, cy - unit * 2.6), unit * 0.25);
    _drawSparkle(
        canvas, Offset(cx - unit * 3.8, cy + unit * 0.2), unit * 0.18);
  }

  void _drawCoin(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      radius * 0.65,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final dx = math.cos(angle) * size;
      final dy = math.sin(angle) * size;
      if (i == 0) {
        path.moveTo(center.dx + dx, center.dy + dy);
      } else {
        path.lineTo(center.dx + dx, center.dy + dy);
      }
      if (i < 3) {
        path.lineTo(center.dx, center.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// Screen 2 – Inventory / Stock illustration
// ─────────────────────────────────────────────────────────────
class InventoryIllustration extends StatelessWidget {
  const InventoryIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _InventoryPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _InventoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 10;

    // Background soft circle
    canvas.drawCircle(
      Offset(cx, cy),
      unit * 4.2,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // Shelf / platform
    final shelfY = cy + unit * 1.8;
    final shelfRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - unit * 3.8, shelfY, unit * 7.6, unit * 0.35),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      shelfRect,
      Paint()..color = const Color(0xFF0F766E).withValues(alpha: 0.3),
    );

    // Box 1 – large (teal)
    _drawBox(
      canvas,
      left: cx - unit * 2.8,
      top: shelfY - unit * 2.8,
      width: unit * 2.4,
      height: unit * 2.8,
      color1: const Color(0xFF14B8A6),
      color2: const Color(0xFF0F766E),
      unit: unit,
    );

    // Box 2 – medium (lighter teal)
    _drawBox(
      canvas,
      left: cx - unit * 0.1,
      top: shelfY - unit * 2.2,
      width: unit * 2.0,
      height: unit * 2.2,
      color1: const Color(0xFF2DD4BF),
      color2: const Color(0xFF14B8A6),
      unit: unit,
    );

    // Box 3 – small stacked on top of box 1
    _drawBox(
      canvas,
      left: cx - unit * 2.4,
      top: shelfY - unit * 4.4,
      width: unit * 1.6,
      height: unit * 1.5,
      color1: const Color(0xFF5EEAD4),
      color2: const Color(0xFF2DD4BF),
      unit: unit,
    );

    // Barcode tag on box 1
    final tagLeft = cx - unit * 2.4;
    final tagTop = shelfY - unit * 1.6;
    final tagRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tagLeft, tagTop, unit * 1.6, unit * 0.9),
      const Radius.circular(3),
    );
    canvas.drawRRect(tagRect, Paint()..color = Colors.white);
    // Barcode lines
    final barPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 6; i++) {
      final x = tagLeft + unit * 0.25 + i * unit * 0.2;
      final h = (i % 2 == 0) ? unit * 0.5 : unit * 0.35;
      canvas.drawLine(
        Offset(x, tagTop + unit * 0.15),
        Offset(x, tagTop + unit * 0.15 + h),
        barPaint,
      );
    }

    // Clipboard / count sheet floating to the right
    final clipLeft = cx + unit * 2.2;
    final clipTop = cy - unit * 2.6;
    final clipW = unit * 2.0;
    final clipH = unit * 3.0;

    // Clipboard shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(clipLeft + 3, clipTop + 4, clipW, clipH),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF0F766E).withValues(alpha: 0.15),
    );
    // Clipboard body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(clipLeft, clipTop, clipW, clipH),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white,
    );
    // Clipboard clip
    final clipClip = RRect.fromRectAndRadius(
      Rect.fromLTWH(clipLeft + clipW * 0.25, clipTop - unit * 0.15,
          clipW * 0.5, unit * 0.35),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      clipClip,
      Paint()..color = const Color(0xFF14B8A6),
    );

    // Checklist lines
    final checkLinePaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = unit * 0.1;
    for (int i = 0; i < 4; i++) {
      final ly = clipTop + unit * 0.6 + i * unit * 0.58;
      // Checkbox
      final cbRect = Rect.fromLTWH(
          clipLeft + unit * 0.25, ly - unit * 0.1, unit * 0.22, unit * 0.22);
      canvas.drawRect(
        cbRect,
        Paint()
          ..color =
              i < 2 ? const Color(0xFF14B8A6) : const Color(0xFFCBD5E1)
          ..style = i < 2 ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      if (i < 2) {
        // Small check
        final cp = Path()
          ..moveTo(cbRect.left + 2, cbRect.center.dy)
          ..lineTo(cbRect.center.dx - 1, cbRect.bottom - 2)
          ..lineTo(cbRect.right - 2, cbRect.top + 2);
        canvas.drawPath(
          cp,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      // Line
      checkLinePaint.color =
          i < 2 ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0);
      canvas.drawLine(
        Offset(clipLeft + unit * 0.6, ly),
        Offset(clipLeft + clipW - unit * 0.3, ly),
        checkLinePaint,
      );
    }

    // Refresh / sync arrows
    _drawSyncArrows(canvas, Offset(cx - unit * 0.5, cy - unit * 3.4), unit);

    // Small decorative dots
    canvas.drawCircle(
      Offset(cx + unit * 3.8, cy + unit * 2.6),
      unit * 0.18,
      Paint()..color = const Color(0xFF14B8A6).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(cx - unit * 4.0, cy - unit * 1.0),
      unit * 0.22,
      Paint()..color = const Color(0xFF2DD4BF).withValues(alpha: 0.5),
    );
    canvas.drawCircle(
      Offset(cx + unit * 2.0, cy + unit * 3.2),
      unit * 0.15,
      Paint()..color = const Color(0xFF5EEAD4).withValues(alpha: 0.6),
    );
  }

  void _drawBox(
    Canvas canvas, {
    required double left,
    required double top,
    required double width,
    required double height,
    required Color color1,
    required Color color2,
    required double unit,
  }) {
    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 3, top + 4, width, height),
        const Radius.circular(6),
      ),
      Paint()..color = color2.withValues(alpha: 0.2),
    );
    // Main box
    final rect = Rect.fromLTWH(left, top, width, height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..shader =
            LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color1, color2])
                .createShader(rect),
    );
    // Box fold / tape
    final tapeRect = Rect.fromLTWH(
        left + width * 0.3, top, width * 0.4, height * 0.15);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tapeRect, const Radius.circular(2)),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
    // Cross tape
    canvas.drawLine(
      Offset(left + width * 0.5, top),
      Offset(left + width * 0.5, top + height * 0.15),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.0,
    );
  }

  void _drawSyncArrows(Canvas canvas, Offset center, double unit) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.16
      ..strokeCap = StrokeCap.round;

    final r = unit * 0.6;
    // Top arc
    final arcRect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(arcRect, -math.pi * 0.8, math.pi * 0.9, false, paint);
    // Bottom arc
    canvas.drawArc(arcRect, math.pi * 0.2, math.pi * 0.9, false, paint);

    // Arrowheads
    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Top arrow
    final topAngle = -math.pi * 0.8 + math.pi * 0.9;
    final tx = center.dx + r * math.cos(topAngle);
    final ty = center.dy + r * math.sin(topAngle);
    final tp = Path()
      ..moveTo(tx + unit * 0.18, ty - unit * 0.12)
      ..lineTo(tx, ty + unit * 0.12)
      ..lineTo(tx - unit * 0.12, ty - unit * 0.15)
      ..close();
    canvas.drawPath(tp, arrowPaint);

    // Bottom arrow
    final botAngle = math.pi * 0.2 + math.pi * 0.9;
    final bx = center.dx + r * math.cos(botAngle);
    final by = center.dy + r * math.sin(botAngle);
    final bp = Path()
      ..moveTo(bx - unit * 0.18, by + unit * 0.12)
      ..lineTo(bx, by - unit * 0.12)
      ..lineTo(bx + unit * 0.12, by + unit * 0.15)
      ..close();
    canvas.drawPath(bp, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────
// Screen 3 – Customer Dues / Payments illustration
// ─────────────────────────────────────────────────────────────
class DuesIllustration extends StatelessWidget {
  const DuesIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DuesPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _DuesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final unit = size.width / 10;

    // Background soft circle
    canvas.drawCircle(
      Offset(cx, cy),
      unit * 4.2,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );

    // Main wallet / card shape
    final walletW = unit * 5.0;
    final walletH = unit * 3.2;
    final walletLeft = cx - walletW / 2 - unit * 0.4;
    final walletTop = cy - walletH / 2 + unit * 0.5;

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(walletLeft + 4, walletTop + 5, walletW, walletH),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFEA580C).withValues(alpha: 0.18),
    );

    // Wallet body
    final walletRect = Rect.fromLTWH(walletLeft, walletTop, walletW, walletH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(walletRect, const Radius.circular(14)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ).createShader(walletRect),
    );

    // Card stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
            walletLeft, walletTop + unit * 0.8, walletW, unit * 0.5),
        Radius.zero,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Wallet chip
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
          walletLeft + unit * 0.6, walletTop + unit * 1.6, unit * 0.8, unit * 0.55),
      const Radius.circular(3),
    );
    canvas.drawRRect(chipRect, Paint()..color = const Color(0xFFFBBF24));
    // Chip lines
    canvas.drawLine(
      Offset(walletLeft + unit * 0.6, walletTop + unit * 1.85),
      Offset(walletLeft + unit * 1.4, walletTop + unit * 1.85),
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 0.8,
    );

    // Card number dots
    final dotY = walletTop + unit * 2.5;
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (int g = 0; g < 4; g++) {
      for (int d = 0; d < 4; d++) {
        canvas.drawCircle(
          Offset(walletLeft + unit * 0.6 + g * unit * 1.1 + d * unit * 0.2,
              dotY),
          unit * 0.06,
          dotPaint,
        );
      }
    }

    // Person avatar circle (top-left floating)
    final avatarCx = cx - unit * 2.0;
    final avatarCy = cy - unit * 2.2;

    // Avatar shadow
    canvas.drawCircle(
      Offset(avatarCx + 2, avatarCy + 3),
      unit * 1.0,
      Paint()..color = const Color(0xFFF97316).withValues(alpha: 0.15),
    );
    // Avatar circle
    canvas.drawCircle(
      Offset(avatarCx, avatarCy),
      unit * 1.0,
      Paint()..color = Colors.white,
    );
    // Head
    canvas.drawCircle(
      Offset(avatarCx, avatarCy - unit * 0.22),
      unit * 0.32,
      Paint()..color = const Color(0xFFF97316),
    );
    // Body arc
    final bodyPath = Path()
      ..addArc(
        Rect.fromCenter(
            center: Offset(avatarCx, avatarCy + unit * 0.65),
            width: unit * 1.0,
            height: unit * 0.8),
        math.pi,
        math.pi,
      );
    canvas.drawPath(
      bodyPath,
      Paint()..color = const Color(0xFFF97316),
    );

    // Floating notification badge
    final badgeX = cx + unit * 2.6;
    final badgeY = cy - unit * 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(badgeX + 2, badgeY + 3),
            width: unit * 2.4,
            height: unit * 1.1),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFEA580C).withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(badgeX, badgeY),
            width: unit * 2.4,
            height: unit * 1.1),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.white,
    );
    // Rupee symbol in badge
    final rupeePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.1
      ..strokeCap = StrokeCap.round;
    // ₹ approximation
    canvas.drawLine(
      Offset(badgeX - unit * 0.25, badgeY - unit * 0.22),
      Offset(badgeX + unit * 0.15, badgeY - unit * 0.22),
      rupeePaint,
    );
    canvas.drawLine(
      Offset(badgeX - unit * 0.25, badgeY - unit * 0.07),
      Offset(badgeX + unit * 0.15, badgeY - unit * 0.07),
      rupeePaint,
    );
    canvas.drawLine(
      Offset(badgeX - unit * 0.15, badgeY - unit * 0.22),
      Offset(badgeX - unit * 0.15, badgeY + unit * 0.25),
      rupeePaint,
    );
    canvas.drawLine(
      Offset(badgeX - unit * 0.15, badgeY + unit * 0.05),
      Offset(badgeX + unit * 0.18, badgeY + unit * 0.25),
      rupeePaint,
    );
    // "Due" text lines
    final dueLinePaint = Paint()
      ..color = const Color(0xFFEA580C).withValues(alpha: 0.5)
      ..strokeWidth = unit * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(badgeX + unit * 0.4, badgeY - unit * 0.1),
      Offset(badgeX + unit * 0.9, badgeY - unit * 0.1),
      dueLinePaint,
    );
    canvas.drawLine(
      Offset(badgeX + unit * 0.4, badgeY + unit * 0.1),
      Offset(badgeX + unit * 0.75, badgeY + unit * 0.1),
      dueLinePaint,
    );

    // Bar chart (bottom right)
    final chartBaseX = cx + unit * 1.5;
    final chartBaseY = cy + unit * 3.0;
    final barColors = [
      const Color(0xFFFED7AA),
      const Color(0xFFF97316),
      const Color(0xFFEA580C),
    ];
    final barHeights = [unit * 1.2, unit * 2.0, unit * 1.5];
    for (int i = 0; i < 3; i++) {
      final barW = unit * 0.55;
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          chartBaseX + i * (barW + unit * 0.25),
          chartBaseY - barHeights[i],
          barW,
          barHeights[i],
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(barRect, Paint()..color = barColors[i]);
    }
    // Chart baseline
    canvas.drawLine(
      Offset(chartBaseX - unit * 0.1, chartBaseY),
      Offset(chartBaseX + unit * 2.7, chartBaseY),
      Paint()
        ..color = const Color(0xFFEA580C).withValues(alpha: 0.3)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Bell icon (bottom left)
    final bellCx = cx - unit * 3.2;
    final bellCy = cy + unit * 2.0;
    canvas.drawCircle(
      Offset(bellCx, bellCy),
      unit * 0.65,
      Paint()..color = Colors.white,
    );
    // Bell shape
    final bellPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bellPath = Path()
      ..moveTo(bellCx - unit * 0.22, bellCy + unit * 0.08)
      ..quadraticBezierTo(
          bellCx - unit * 0.22, bellCy - unit * 0.28, bellCx, bellCy - unit * 0.28)
      ..quadraticBezierTo(
          bellCx + unit * 0.22, bellCy - unit * 0.28, bellCx + unit * 0.22, bellCy + unit * 0.08)
      ..lineTo(bellCx - unit * 0.22, bellCy + unit * 0.08);
    canvas.drawPath(bellPath, bellPaint);
    // Bell bottom
    canvas.drawLine(
      Offset(bellCx - unit * 0.28, bellCy + unit * 0.08),
      Offset(bellCx + unit * 0.28, bellCy + unit * 0.08),
      bellPaint,
    );
    // Bell clapper
    canvas.drawCircle(
      Offset(bellCx, bellCy + unit * 0.18),
      unit * 0.06,
      Paint()..color = const Color(0xFFF97316),
    );

    // Decorative dots
    canvas.drawCircle(
      Offset(cx + unit * 4.0, cy + unit * 0.5),
      unit * 0.15,
      Paint()..color = const Color(0xFFF97316).withValues(alpha: 0.4),
    );
    canvas.drawCircle(
      Offset(cx - unit * 4.2, cy + unit * 3.0),
      unit * 0.2,
      Paint()..color = const Color(0xFFFED7AA).withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
