// ------------------------------------------------------------------
// Legacy Product Barcode Module
// Currently not used in Visitor Registration workflow.
// Retained for future Sunmi product/barcode functionality.
// ------------------------------------------------------------------

import 'package:http/http.dart' as http;
import '../models/bar_code_item_models.dart';
import '../utils/production_logger.dart';

class ApiServices {
  static addProductDetails({
    required userName,
    required dataBase,
    required server,
    required itemCode,
    required itemDesc,
    required arabicDecs,
    required salesPrice,
    required unitCode,
    required barcode,
  }) async {
    var headers = {'Content-Type': 'application/json'};
    var request =
        http.Request('POST', Uri.parse('$server/api/add-product-details'));
    request.body = '''{
  "UserName": "$userName",
  "DataBase": "$dataBase",
  "ItemCode": "$itemCode",
  "ItemDescription": "$itemDesc",
  "ArabicItemDescription": "$arabicDecs",
  "SalesPrice": $salesPrice,
  "BarCode": "$barcode"
}''';
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      return true;
    } else {
      ProductionLogger.error('Failed to add product details: ${response.reasonPhrase}');
      return false;
    }
  }

  static Future<BarCodeData?> getBarCodeDetails(
      userName, dataBase, server, barcode) async {
    var headers = {'Content-Type': 'application/json'};
    var url = Uri.parse(
        '$server/api/get-barcode-details?UserName=$userName&DataBase=$dataBase&BarCode=$barcode');
    var request = http.Request('GET', url);

    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();

    if (response.statusCode == 200) {
      var responseBody = await response.stream.bytesToString();
      return BarCodeData.fromRawJson(responseBody);
    } else {
      ProductionLogger.error('Error fetching barcode details: ${response.reasonPhrase}');
      return null;
    }
  }
}
