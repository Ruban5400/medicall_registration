import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService with ChangeNotifier {
  List<dynamic> _visitors = [];

  List<dynamic> get visitors => _visitors;

  static const String _baseUrl = "https://crm.medicall.in/api";

  Future<void> fetchAndStoreVisitors() async {
    const url = "$_baseUrl/fetch-visitors";
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('5400-=-=-=->>.  $decoded');
        if (decoded is List) {
          _visitors = decoded;
          notifyListeners();
        }
      } else {
        throw Exception('Failed to fetch visitors: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching visitors: $e');
      rethrow;
    }
  }

  static Future<bool> sendVisitorData(
      Map<String, dynamic> visitorData, String mobileNumber) async {
    final url =
        Uri.parse("$_baseUrl/visitor/insert-or-update?mobile_number=$mobileNumber");
    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(visitorData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint("✅ Data sent successfully: ${response.body}");
        return true;
      } else {
        debugPrint(
            "❌ Failed to send data: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❗ Error sending data: $e");
      return false;
    }
  }
}
