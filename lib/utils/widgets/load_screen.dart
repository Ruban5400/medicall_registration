import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../controller/main_controller.dart';


class DataLoaderScreen extends StatefulWidget {
  const DataLoaderScreen({super.key});

  @override
  State<DataLoaderScreen> createState() => _DataLoaderScreenState();
}

class _DataLoaderScreenState extends State<DataLoaderScreen> {
  final storage = GetStorage();

  @override
  void initState() {
    super.initState();
    fetchAndStoreData();
  }

  Future<void> fetchAndStoreData() async {
    try {
      final response = await http.get(
        Uri.parse('https://crm.medicall.in/api/fetch-visitors'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await storage.write('global_visitor_data', data);
        debugPrint("✅ Data stored successfully in GetStorage");

        if (mounted) {
          // Navigator.pushReplacement(
          //   context,
          //   // MaterialPageRoute(builder: (_) => const GetItemDetails()),
          //   MaterialPageRoute(builder: (_) => const WelcomePage()),
          // );
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              "Please wait\nFetching global visitor data...",textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
