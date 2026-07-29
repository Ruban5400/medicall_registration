import 'package:flutter/material.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../production_logger.dart';

class QRScannerPage extends StatefulWidget {
  final Function(String) onScanComplete;

  const QRScannerPage({Key? key, required this.onScanComplete})
      : super(key: key);

  static bool _scannerOpen = false;
  static bool get isScannerOpen => _scannerOpen;
  static set isScannerOpen(bool val) => _scannerOpen = val;

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController scannerController;
  late final AnimationController _animationController;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();

  bool isScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    QRScannerPage.isScannerOpen = true;
    scannerController =
        MobileScannerController(detectionSpeed: DetectionSpeed.normal);
    ProductionLogger.scan('Camera started');
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    QRScannerPage.isScannerOpen = false;
    ProductionLogger.scan('Camera stopped');
    scannerController.stop();
    scannerController.dispose();
    ProductionLogger.scan('Camera disposed');
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ProductionLogger.log('CAMERA', 'Lifecycle resumed: starting camera');
      scannerController.start();
    } else if (state == AppLifecycleState.paused) {
      ProductionLogger.log('CAMERA', 'Lifecycle paused: stopping camera');
      scannerController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          ProductionLogger.scan('Camera stopped');
          await scannerController.stop();
          if (mounted) {
            Navigator.pop(context);
          }
        },
        child: Stack(
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
                  if (mounted) {
                    Navigator.pop(context);
                    Future.microtask(() => widget.onScanComplete(code));
                  }
                  break;
                }
              }
            },
          ),

          // Header Overlay
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Scan Visitor Badge QR",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.flash_on, color: Colors.white, size: 26),
                  onPressed: () => scannerController.toggleTorch(),
                ),
              ],
            ),
          ),

          // Scan overlay box
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFF1A922), width: 3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3D000000),
                    blurRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Animated scan line
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (_, __) {
                  return Align(
                    alignment:
                        Alignment(0, (_animationController.value * 2) - 1),
                    child: Container(
                      height: 3,
                      width: 240,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1A922),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFFF1A922), blurRadius: 8),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Scanning status text
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                isScanned ? '✅ QR Code Detected!' : 'Place the QR Code inside the frame\nScanning automatically...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
     ),
    );
  }
}
