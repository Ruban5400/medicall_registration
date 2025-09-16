import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sunmi_printer_plus/core/enums/enums.dart';
import 'package:sunmi_printer_plus/core/sunmi/sunmi_printer.dart';

import './v_card.dart';

class Sunmi {
  final Map<String, dynamic>? printSelectedVisitor;

  Sunmi({required this.printSelectedVisitor});

  Future<void> initialize() async {
    await SunmiPrinter.bindingPrinter();
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
  }

  Future<void> closePrinter() async {
    await SunmiPrinter.bindingPrinter();
  }

  // Main method to call
  Future<void> printReceipt(double paperWidthMm, double paperHeightMm) async {
    await printReceiptWithUserAndQR(
      name: printSelectedVisitor?['name'] ?? ' ',
      mobileNumber : printSelectedVisitor?['mobile_number'] ?? ' ',
      email : printSelectedVisitor?['email'] ?? ' ',
      role: '${printSelectedVisitor?['designation']} @ ${printSelectedVisitor?['company']}' ?? ' ',
      paperWidthMm: paperWidthMm,
      paperHeightMm: paperHeightMm,
    );
    await closePrinter();
  }

  Future<void> printReceiptWithUserAndQR({
    required String name,
    required String mobileNumber,
    required String email,
    required String role,
    required double paperWidthMm,
    required double paperHeightMm,
  }) async {
    await initialize();

    final image = await _generateFullReceiptImage(
      name: name,
      mobileNumber:mobileNumber,
      email:email,
      role: role,
      paperWidthMm: paperWidthMm,
      paperHeightMm: paperHeightMm,
    );

    await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
    await SunmiPrinter.printImage(image);
    await SunmiPrinter.lineWrap(1);
  }

  Future<Uint8List> _generateFullReceiptImage({
    required String name,
    required String mobileNumber,
    required String email,
    required String role,
    required double paperWidthMm,
    required double paperHeightMm,
  }) async {
    const dpi = 203.0;
    final widthPx = ((paperWidthMm / 25.4) * dpi).round();
    final heightPx = ((paperHeightMm / 25.4) * dpi).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    // White background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, widthPx.toDouble(), heightPx.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final textStyle = ui.TextStyle(
      color: const Color(0xFF000000),
      fontSize: 28,
      fontWeight: FontWeight.w600,
    );

    final lines = [name, mobileNumber, email,  role];
    double currentY = 10;

    for (final line in lines) {
      final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
      final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
        ..pushStyle(textStyle)
        ..addText(line);
      final paragraph = paragraphBuilder.build()
        ..layout(ui.ParagraphConstraints(width: widthPx.toDouble()));
      canvas.drawParagraph(paragraph, Offset(0, currentY));
      currentY += paragraph.height;
    }

    // Space between last line of text and QR code
    currentY += 20;
    final vCard = generateVCard(
        name: name,
        email: email,
        organization: role,
        mobile_number: mobileNumber,
        );
    // Draw QR code
    final qrSize = (widthPx * 0.5).round(); // 50% of width
    final leftPadding = ((widthPx - qrSize) / 2).toDouble();
    canvas.drawImage(
      await _renderQrImage(vCard, qrSize),
      Offset(leftPadding, currentY),
      paint,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(widthPx, heightPx);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _renderQrImage(String data, int size) async {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: false,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
    );

    final picRecorder = ui.PictureRecorder();
    final canvas = Canvas(picRecorder);
    final paintSize = Size(size.toDouble(), size.toDouble());

    painter.paint(canvas, paintSize);

    final picture = picRecorder.endRecording();
    return await picture.toImage(size, size);
  }
}

// all center placed
// import 'dart:typed_data';
// import 'package:flutter/services.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:flutter/material.dart';
// import 'package:sunmi_printer_plus/enums.dart';
// import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
// import 'package:sunmi_printer_plus/sunmi_style.dart';
// import 'package:flutter/rendering.dart';
// import 'dart:ui' as ui;
//
// class Sunmi {
//   Future<void> initialize() async {
//     await SunmiPrinter.bindingPrinter();
//     await SunmiPrinter.initPrinter();
//     await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
//   }
//
//   int getMaxCharsPerLine(double paperWidthMm) {
//     const charsPerInch = 12;
//     return (paperWidthMm / 25.4 * charsPerInch).floor();
//   }
//
//   String centerAlignText(String text, int maxCharsPerLine) {
//     int padding = ((maxCharsPerLine - text.length) / 2).floor();
//     return padding > 0 ? ' ' * padding + text : text;
//   }
//
//   Future<void> printReceiptWithUserAndQR({
//     required String name,
//     required String role,
//     required String id,
//     required double paperWidthMm,
//   }) async {
//     await initialize();
//     int maxChars = getMaxCharsPerLine(paperWidthMm);
//
//     await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
//     await SunmiPrinter.printText(centerAlignText(name, maxChars),
//         style: SunmiStyle(fontSize: SunmiFontSize.LG, bold: true));
//     await SunmiPrinter.printText(centerAlignText(role, maxChars),
//         style: SunmiStyle(fontSize: SunmiFontSize.LG));
//     await SunmiPrinter.printText(centerAlignText(id, maxChars),
//         style: SunmiStyle(fontSize: SunmiFontSize.LG));
//
//     await SunmiPrinter.lineWrap(1);
//
//     /// Render QR code as image
//     final qrImage = await _generateQrCodeImage(id, paperWidthMm);
//
//     /// Print as image (centered based on paper width)
//     await SunmiPrinter.setAlignment(SunmiPrintAlign.LEFT);
//     await SunmiPrinter.printImage(qrImage);
//
//     await SunmiPrinter.lineWrap(3);
//   }
//
//   Future<Uint8List> _generateQrCodeImage(String data, double paperWidthMm) async {
//     const printerDpi = 203.0;
//     final paperWidthInch = paperWidthMm / 25.4;
//     final paperWidthPx = (paperWidthInch * printerDpi).round();
//
//     final qrSize = 200;
//     final qrImage = await _renderQrImage(data, qrSize);
//
//     final canvas = ui.PictureRecorder();
//     final paintCanvas = Canvas(canvas);
//
//     final totalHeight = qrSize + 20;
//     final finalWidth = paperWidthPx;
//
//     // Calculate horizontal padding
//     final leftPadding = ((finalWidth - qrSize) / 2).clamp(0, double.infinity).toDouble();
//
//
//     paintCanvas.drawRect(
//         Rect.fromLTWH(0, 0, finalWidth.toDouble(), totalHeight.toDouble()),
//         Paint()..color = const Color(0xFFFFFFFF));
//
//     paintCanvas.drawImage(qrImage, Offset(leftPadding, 10), Paint());
//
//     final picture = canvas.endRecording();
//     final img = await picture.toImage(finalWidth, totalHeight);
//     final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
//     return byteData!.buffer.asUint8List();
//   }
//
//   Future<ui.Image> _renderQrImage(String data, int size) async {
//     final painter = QrPainter(
//       data: data,
//       version: QrVersions.auto,
//       gapless: false,
//     );
//
//     final picRecorder = ui.PictureRecorder();
//     final canvas = Canvas(picRecorder);
//     final paintSize = Size(size.toDouble(), size.toDouble());
//
//     painter.paint(canvas, paintSize);
//
//     final picture = picRecorder.endRecording();
//     return await picture.toImage(size, size);
//   }
//
//   Future<void> printReceipt(double paperWidthMm) async {
//     await printReceiptWithUserAndQR(
//       name: "Ruban",
//       role: "App Developer",
//       id: "BFX5400",
//       paperWidthMm: paperWidthMm,
//     );
//     await closePrinter();
//   }
//
//   Future<void> closePrinter() async {
//     await SunmiPrinter.unbindingPrinter();
//   }
// }
