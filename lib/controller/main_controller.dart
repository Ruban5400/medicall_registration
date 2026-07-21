import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../controller/api_services.dart';
import '../controller/helper_services.dart';
import '../screens/get_item_details.dart';
import '../utils/string_constants.dart';

import '../models/bar_code_item_models.dart';
import '../utils/widgets/qr_scanner.dart';

class MainController extends ChangeNotifier {
  TextEditingController getItemController = TextEditingController();

  String barcode = "";
  String server = "";

  TextEditingController itemCOde = TextEditingController();

  TextEditingController itemDescription = TextEditingController();

  TextEditingController arabicItemDescription = TextEditingController();

  TextEditingController salesPrice = TextEditingController();

  TextEditingController barCode = TextEditingController();

  TextEditingController unitCode = TextEditingController();
  final GlobalKey globalKey = GlobalKey();

  // ------------------------------------------------------------------
  // Legacy Product Barcode Capture Method
  // Currently not used in Visitor Registration workflow.
  // Retained for future Sunmi product/barcode functionality.
  // ------------------------------------------------------------------
  Future<void> captureBarcodeAndSave(
      MainController value, BuildContext context) async
  {
    try {
      RenderRepaintBoundary boundary =
          globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();

      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save the image to a file
      final directory = (await getApplicationDocumentsDirectory()).path;
      File imgFile = File('$directory/barcode_${value.itemCOde.text}.png');

      await imgFile.writeAsBytes(pngBytes);

      var server = await HelperServices.getServerData(StringConstants.server);
      var dataBase =
          await HelperServices.getServerData(StringConstants.dataBase);
      var username =
          await HelperServices.getServerData(StringConstants.userName);

      username = "root";
      notifyListeners();

      // Upload the file to your API
      var result = await ApiServices.addProductDetails(
          userName: username,
          dataBase: dataBase,
          itemCode: itemCOde.text,
          itemDesc: itemDescription.text,
          arabicDecs: arabicItemDescription.text,
          salesPrice: salesPrice,
          unitCode: unitCode,
          barcode: imgFile,
          server: server);
      if (result) {
        _showSuccessDialog(context);
      }
    } catch (e) {
      stdout.writeln("Error capturing barcode: $e");
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: const Text('Product added successfully!'),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  scannBarCode(
    BuildContext context,
  ) async {
    try {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  QRScannerPage(onScanComplete: (String barcodeScanRes) async {
                    if (barcodeScanRes.isNotEmpty) {
                      getItemController.text = barcodeScanRes.toString();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GetItemDetails()),
                      );
                    }
                  })));
    } on PlatformException {
      // handle platform exception
    }
  }

  // ------------------------------------------------------------------
  // Legacy Product Barcode Details Method
  // Currently not used in Visitor Registration workflow.
  // Retained for future Sunmi product/barcode functionality.
  // ------------------------------------------------------------------
  Future<BarCodeData?> getDetailsMethod() async {
    server = await HelperServices.getServerData(StringConstants.server);
    var dataBase = await HelperServices.getServerData(StringConstants.dataBase);
    var userName = await HelperServices.getServerData(StringConstants.userName);

    var response = await ApiServices.getBarCodeDetails(
        userName, dataBase, server, getItemController.text);
    if (response != null) {
      return response;
    } else {
      return null;
    }
  }

  @override
  void dispose() {
    getItemController.dispose();
    itemCOde.dispose();
    itemDescription.dispose();
    arabicItemDescription.dispose();
    salesPrice.dispose();
    barCode.dispose();
    unitCode.dispose();
    super.dispose();
  }
}
