import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  bool _isScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isScanned) return;
    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _isScanned = true;
        // Vibrate
        final canVibrate = await Vibrate.canVibrate;
        if (canVibrate) {
          Vibrate.feedback(FeedbackType.success);
        }

        if (mounted) {
          context.pop(barcode.rawValue);
        }
        break; // Only take first one
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 32, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Scan Product',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),

          // Dark Overlay with Cutout
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 2),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    _buildCorner(Alignment.topLeft),
                    _buildCorner(Alignment.topRight),
                    _buildCorner(Alignment.bottomLeft),
                    _buildCorner(Alignment.bottomRight),
                  ],
                ),
              ),
            ),
          ),

          const Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Text(
              'Align barcode within frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            border: Border(
              top: (alignment == Alignment.topLeft ||
                      alignment == Alignment.topRight)
                  ? const BorderSide(color: Color(0xFF10B981), width: 6)
                  : BorderSide.none,
              bottom: (alignment == Alignment.bottomLeft ||
                      alignment == Alignment.bottomRight)
                  ? const BorderSide(color: Color(0xFF10B981), width: 6)
                  : BorderSide.none,
              left: (alignment == Alignment.topLeft ||
                      alignment == Alignment.bottomLeft)
                  ? const BorderSide(color: Color(0xFF10B981), width: 6)
                  : BorderSide.none,
              right: (alignment == Alignment.topRight ||
                      alignment == Alignment.bottomRight)
                  ? const BorderSide(color: Color(0xFF10B981), width: 6)
                  : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft: alignment == Alignment.topLeft
                  ? const Radius.circular(24)
                  : Radius.zero,
              topRight: alignment == Alignment.topRight
                  ? const Radius.circular(24)
                  : Radius.zero,
              bottomLeft: alignment == Alignment.bottomLeft
                  ? const Radius.circular(24)
                  : Radius.zero,
              bottomRight: alignment == Alignment.bottomRight
                  ? const Radius.circular(24)
                  : Radius.zero,
            )),
      ),
    );
  }
}
