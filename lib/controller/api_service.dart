import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiService with ChangeNotifier {
  List<dynamic> _visitors = [];

  List<dynamic> get visitors => _visitors;

  static const String _baseUrl = "https://crm.medicall.in/api";

  Future<void> fetchAndStoreVisitors() async {
    const url = "$_baseUrl/fetch-visitors";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      _visitors = jsonDecode(response.body);
      notifyListeners();
    } else {
      throw Exception('Failed to fetch visitors');
    }
  }

  static Future<bool> sendVisitorData(
      Map<String, dynamic> visitorData, String mobileNumber) async {
    final url =
        Uri.parse("$_baseUrl/visitor/insert-or-update?mobile_number=$mobileNumber");
print('Ruby--->>> $visitorData');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(visitorData),
      );
print('5400 >>>> ${response.body}');
      if (response.statusCode == 200) {
        print("✅ Data sent successfully: ${response.body}");
        return true;
      } else {
        print(
            "❌ Failed to send data: ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("❗ Error sending data: $e");
      return false;
    }
  }
}
