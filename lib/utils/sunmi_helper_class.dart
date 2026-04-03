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
    var company = '';
    var designation = '';
    if (printSelectedVisitor?['company'] == '' ||
        printSelectedVisitor?['company'] == null) {
      company = '';
    } else {
      company = '@ ${printSelectedVisitor?['company']}';
    }
    if (printSelectedVisitor?['designation'] == '' ||
        printSelectedVisitor?['designation'] == null) {
      designation = '';
    } else {
      designation = printSelectedVisitor?['designation'];
    }
    await printReceiptWithUserAndQR(
      name: printSelectedVisitor?['name'] ?? ' ',
      // mobileNumber : printSelectedVisitor?['mobile_number'] ?? ' ',
      // email : printSelectedVisitor?['email'] ?? ' ',
      role: '$designation $company' ?? ' ',
      paperWidthMm: paperWidthMm,
      paperHeightMm: paperHeightMm,
    );
    await closePrinter();
  }

  Future<void> printReceiptWithUserAndQR({
    required String name,
    // required String mobileNumber,
    // required String email,
    required String role,
    required double paperWidthMm,
    required double paperHeightMm,
  }) async {
    await initialize();

    final image = await _generateFullReceiptImage(
      name: name,
      // mobileNumber:mobileNumber,
      // email:email,
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
    // required String mobileNumber,
    // required String email,
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

    final lines = [name, role];
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
      email: printSelectedVisitor?['email'],
      organization: role,
      mobile_number: printSelectedVisitor?['mobile_number'],
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
