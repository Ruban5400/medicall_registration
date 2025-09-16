import 'package:flutter/material.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

class QRScannerPage extends StatefulWidget {
  final Function(String) onScanComplete;

  const QRScannerPage({Key? key, required this.onScanComplete})
      : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController scannerController;
  late final AnimationController _animationController;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();

  bool isScanned = false;

  @override
  void initState() {
    super.initState();
    scannerController =
        MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    scannerController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: (BarcodeCapture capture) async {
              if (isScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null) {
                  isScanned = true;
                  scannerController.stop();
                  _flutterBeepPlusPlugin.playSysSound(AndroidSoundID.TONE_CDMA_ABBR_ALERT);
                  Navigator.pop(context);
                  Future.microtask(() => widget.onScanComplete(code));
                  break;
                }
              }
            },
          ),

          // Scan overlay box
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Animated scan line
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (_, __) {
                  return Align(
                    alignment:
                        Alignment(0, (_animationController.value * 2) - 1),
                    child: Container(
                      height: 2,
                      width: 250,
                      color: Colors.redAccent,
                    ),
                  );
                },
              ),
            ),
          ),

          // Flashlight button
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.flashlight_on,
                    color: Colors.white, size: 30),
                onPressed: () {
                  scannerController.toggleTorch();
                },
              ),
            ),
          ),

          // Scanning status text
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                isScanned ? 'QR Code Detected!' : 'Scanning...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
