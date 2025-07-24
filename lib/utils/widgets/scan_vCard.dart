import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import 'package:intl/intl.dart';

class VCardScanner extends StatefulWidget {
  final String hallNo;

  const VCardScanner(this.hallNo, {super.key});

  @override
  _VCardScannerState createState() => _VCardScannerState();
}

class _VCardScannerState extends State<VCardScanner> {
  final box = GetStorage();
  bool isScanning = false;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();

  @override
  void initState() {
    super.initState();
    box.writeIfNull('leads', []);
  }

  Future<void> handleScan(String rawValue) async {
    if (isScanning) return;
    isScanning = true;

    final contact = parseCustomVCard(rawValue);

    if (contact.isNotEmpty) {
      final now = DateTime.now();
      // final now = DateTime.now().add(const Duration(days: 3));

      final formattedDate = DateFormat('yyyy-MM-dd').format(now);

      contact['hall_no'] = widget.hallNo;
      contact['date'] = formattedDate;

      final List<dynamic> currentLeads = box.read('leads') ?? [];
      currentLeads.add(contact);
      await box.write('leads', currentLeads);

      setState(() {}); // Refresh UI
      showSnackBar('✅ Data saved');

      Future.delayed(const Duration(seconds: 2), () {
        isScanning = false;
      });
    } else {
      showSnackBar('❌ Invalid or incomplete vCard');
      isScanning = false;
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> scannedLeads = box.read('leads') ?? [];
    // final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    //
    // final todayCount = scannedLeads
    //     .where((e) => e['date'] == today)
    //     .length;

    Map<String, List<dynamic>> scannedLeadsByDate = {};

    for (var lead in scannedLeads) {
      final date = lead['date'] ?? 'Unknown';
      scannedLeadsByDate.putIfAbsent(date, () => []).add(lead);
    }

    final sortedDates = scannedLeadsByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan vCard',
          style: TextStyle(
            color: Colors.indigo,
            fontSize: 25,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.indigo),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.indigo.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hall No: ${widget.hallNo}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                Text("📅 Scanned Counts by Date:",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ...sortedDates.map((date) {
                  final count = scannedLeadsByDate[date]!.length;
                  final formattedDate = DateFormat('dd-MM-yyyy')
                      .format(DateTime.parse(date));
                  return Text("• $formattedDate: $count",
                      style: TextStyle(fontSize: 15,fontWeight: FontWeight.bold));
                }),
                SizedBox(height: 10),
                Text("📊 Total Scanned: ${scannedLeads.length}",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: MobileScanner(
              controller: MobileScannerController(
                facing: CameraFacing.back,
                detectionSpeed: DetectionSpeed.noDuplicates,
                detectionTimeoutMs: 500,
              ),
              onDetect: (barcodeCapture) {
                final barcode = barcodeCapture.barcodes.first;
                final raw = barcode.rawValue;
                _flutterBeepPlusPlugin.playSysSound(
                    AndroidSoundID.TONE_CDMA_ABBR_ALERT);
                if (barcode.format == BarcodeFormat.qrCode &&
                    raw != null &&
                    raw.startsWith("BEGIN:VCARD")) {
                  handleScan(raw);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> parseCustomVCard(String vCard) {
    final lines = vCard.split('\n');
    final data = <String, String>{};

    for (final line in lines) {
      if (line.startsWith('N:')) {
        data['name'] = line.replaceFirst('N:', '').trim();
      } else if (line.startsWith('FN:')) {
        data['full_name'] = line.replaceFirst('FN:', '').trim();
      } else if (line.startsWith('EMAIL:')) {
        data['email'] = line.replaceFirst('EMAIL:', '').trim();
      } else if (line.startsWith('ORG:')) {
        data['organization'] = line.replaceFirst('ORG:', '').trim();
      } else if (line.startsWith('TITLE:')) {
        data['designation'] = line.replaceFirst('TITLE:', '').trim();
      } else if (line.startsWith('TEL;TYPE=CELL:')) {
        data['mobile_number'] = line.replaceFirst('TEL;TYPE=CELL:', '').trim();
      } else if (line.startsWith('ADR:')) {
        data['address'] = line.replaceFirst('ADR:', '').trim();
      } else if (line.startsWith('REG_ID:')) {
        data['reg_id'] = line.replaceFirst('REG_ID:', '').trim();
      }
    }

    return data;
  }
}


// code with count and without date
// import 'package:flutter/material.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:get_storage/get_storage.dart';
// import 'package:flutter_beep_plus/flutter_beep_plus.dart';
//
// class VCardScanner extends StatefulWidget {
//   final String hallNumber;
//
//   const VCardScanner(this.hallNumber, {super.key});
//
//   @override
//   _VCardScannerState createState() => _VCardScannerState();
// }
//
// class _VCardScannerState extends State<VCardScanner> {
//   final box = GetStorage();
//   bool isScanning = false;
//   final _flutterBeepPlusPlugin = FlutterBeepPlus();
//
//   @override
//   void initState() {
//     super.initState();
//     box.writeIfNull('leads', []);
//   }
//
//   Future<void> handleScan(String rawValue) async {
//     if (isScanning) return;
//     isScanning = true;
//
//     final contact = parseCustomVCard(rawValue);
//     contact['hall_number'] = widget.hallNumber;
//     contact['date'] = DateTime.now() as String;
//
//     if (contact.isNotEmpty) {
//       final List<dynamic> currentLeads = box.read('leads') ?? [];
//       currentLeads.add(contact);
//       await box.write('leads', currentLeads);
//
//       setState(() {}); // Refresh count
//       showSnackBar('✅ Data saved');
//
//       Future.delayed(const Duration(seconds: 2), () {
//         isScanning = false;
//       });
//     } else {
//       showSnackBar('❌ Invalid or incomplete vCard');
//       isScanning = false;
//     }
//   }
//
//   void showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final List<dynamic> scannedLeads = box.read('leads') ?? [];
//
//     // Page number logic
//     int leadsPerPage = 10;
//     int pageNumber = (scannedLeads.length / leadsPerPage).ceil();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Scan vCard',
//           style: const TextStyle(
//             color: Colors.indigo,
//             fontSize: 25,
//             fontWeight: FontWeight.bold,
//             fontStyle: FontStyle.italic,
//           ),
//         ),
//         backgroundColor: Colors.white,
//         elevation: 1,
//         iconTheme: const IconThemeData(color: Colors.indigo),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(vertical: 12.0),
//             child: Column(
//               children: [
//                 Text(
//                   'Hall: ${widget.hallNumber}',
//                   style: const TextStyle(
//                     fontSize: 18,
//                     color: Colors.indigo,
//                     fontWeight: FontWeight.w500,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Scanned: ${scannedLeads.length}  |  Page: $pageNumber',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.indigo,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             child: MobileScanner(
//               controller: MobileScannerController(
//                 facing: CameraFacing.back,
//                 detectionSpeed: DetectionSpeed.noDuplicates,
//                 detectionTimeoutMs: 500,
//               ),
//               onDetect: (barcodeCapture) {
//                 final barcode = barcodeCapture.barcodes.first;
//                 final raw = barcode.rawValue;
//
//                 _flutterBeepPlusPlugin.playSysSound(
//                     AndroidSoundID.TONE_CDMA_ABBR_ALERT);
//
//                 if (barcode.format == BarcodeFormat.qrCode &&
//                     raw != null &&
//                     raw.startsWith("BEGIN:VCARD")) {
//                   handleScan(raw);
//                 }
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Map<String, String> parseCustomVCard(String vCard) {
//     final lines = vCard.split('\n');
//     final data = <String, String>{};
//
//     for (final line in lines) {
//       if (line.startsWith('N:')) {
//         data['name'] = line.replaceFirst('N:', '').trim();
//       } else if (line.startsWith('FN:')) {
//         data['full_name'] = line.replaceFirst('FN:', '').trim();
//       } else if (line.startsWith('EMAIL:')) {
//         data['email'] = line.replaceFirst('EMAIL:', '').trim();
//       } else if (line.startsWith('ORG:')) {
//         data['organization'] = line.replaceFirst('ORG:', '').trim();
//       } else if (line.startsWith('TITLE:')) {
//         data['designation'] = line.replaceFirst('TITLE:', '').trim();
//       } else if (line.startsWith('TEL;TYPE=CELL:')) {
//         data['mobile_number'] = line.replaceFirst('TEL;TYPE=CELL:', '').trim();
//       } else if (line.startsWith('ADR:')) {
//         data['address'] = line.replaceFirst('ADR:', '').trim();
//       } else if (line.startsWith('REG_ID:')) {
//         data['reg_id'] = line.replaceFirst('REG_ID:', '').trim();
//       }
//     }
//
//     return data;
//   }
// }

