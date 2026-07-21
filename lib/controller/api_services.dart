// ------------------------------------------------------------------
// Legacy Product Barcode Module
// Currently not used in Visitor Registration workflow.
// Retained for future Sunmi product/barcode functionality.
// ------------------------------------------------------------------

import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/bar_code_item_models.dart';

class ApiServices {
  static addProductDetails({
    required userName,
    required server,
    required dataBase,
    required itemCode,
    required itemDesc,
    required arabicDecs,
    required salesPrice,
    required unitCode,
    required barcode,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$server/add_product'));
      request.fields.addAll({
        'userName': userName,
        'dataBase': dataBase,
        'itemCode': itemCode,
        'itemDesc': itemDesc,
        'arabicDecs': arabicDecs,
        'salesPrice': salesPrice,
        'unitCode': unitCode,
      });
      request.files.add(await http.MultipartFile.fromPath('barCode', barcode));

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        stdout.writeln(await response.stream.bytesToString());
      }
      else {
        stdout.writeln(response.reasonPhrase);
      }

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      stdout.writeln(e);
    }
  }

  static Future<BarCodeData?> getBarCodeDetails(String userName, String dataBase, String server, String itemCode) async {
    var headers = {
      'userName': userName,
      'dataBase': dataBase
    };

    var url = Uri.parse('$server/get_barcode/${itemCode.trim()}');

    var request = http.Request('GET',url);

    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      // Parse the streamed response body
     var responseBody = await response.stream.bytesToString();

      // Parse the JSON response and map to BarCodeData model
      return BarCodeData.fromRawJson(responseBody);
    } else {
      print('Error: ${response.reasonPhrase}');
      return null;
    }
  }
}
