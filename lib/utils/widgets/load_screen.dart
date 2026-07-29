import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../controller/main_controller.dart';
import '../production_logger.dart';


class DataLoaderScreen extends StatefulWidget {
  const DataLoaderScreen({super.key});

  @override
  State<DataLoaderScreen> createState() => _DataLoaderScreenState();
}

class _DataLoaderScreenState extends State<DataLoaderScreen> {
  final storage = GetStorage();
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchAndStoreData();
  }

  Future<void> fetchAndStoreData() async {
    try {
      final response = await http
          .get(Uri.parse('https://crm.medicall.in/api/fetch-visitors'))
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        ProductionLogger.sync('Global visitor data fetched: ${data != null}');
        if (data != null) {
          await storage.write('global_visitor_data', data);
          ProductionLogger.sync("✅ Data stored successfully in GetStorage");
        }

        if (mounted) {
          Provider.of<MainController>(context, listen: false)
              .scannBarCode(context);
        }
      } else {
        showError("Failed to fetch data. Status code: ${response.statusCode}");
      }
    } catch (e) {
      showError("Error fetching data: $e");
    }
  }

  void showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      color: Color(0xFFF1A922),
                      strokeWidth: 3.5,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Preparing Visitor Database",
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Please wait...",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
