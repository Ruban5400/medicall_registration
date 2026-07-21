import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controller/configuration_page_controller.dart';
import '../controller/main_controller.dart';
import '../utils/widgets/load_screen.dart';

class PrinterConfigurationScreen extends StatefulWidget {
  const PrinterConfigurationScreen({super.key});

  @override
  State<PrinterConfigurationScreen> createState() =>
      _PrinterConfigurationScreenState();
}

class _PrinterConfigurationScreenState
    extends State<PrinterConfigurationScreen> {
  String? selectedPrinter;
  final TextEditingController heightController = TextEditingController();
  final TextEditingController widthController = TextEditingController();
  int appCount = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAppCount();
  }

  @override
  void dispose() {
    heightController.dispose();
    widthController.dispose();
    super.dispose();
  }

  Future<void> _loadAppCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        appCount = prefs.getInt('appCount') ?? 0;
      });
    }
  }

  Future<void> _incrementAppCount() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    appCount++;
    await prefs.setInt('appCount', appCount);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      appBar: AppBar(
        title: const Text(
          "Printer Configuration",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF1A922),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.print_outlined, color: Color(0xFFF1A922)),
                        SizedBox(width: 10),
                        Text(
                          "Select Printer Type",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFD9D9D9)),
                    RadioListTile<String>(
                      value: "Sunmi",
                      groupValue: selectedPrinter,
                      activeColor: const Color(0xFFF1A922),
                      title: const Text(
                        "Sunmi POS Thermal Printer",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onChanged: (val) {
                        setState(() {
                          selectedPrinter = val;
                          heightController.text = '68';
                          widthController.text = '58';
                        });
                      },
                    ),
                    RadioListTile<String>(
                      value: "Bluetooth",
                      groupValue: selectedPrinter,
                      activeColor: const Color(0xFFF1A922),
                      title: const Text(
                        "Bluetooth External Printer",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onChanged: (val) => setState(() => selectedPrinter = val),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Paper Height (mm)",
                hintText: "Enter height in mm e.g. 68",
                prefixIcon: const Icon(Icons.height, color: Color(0xFFF1A922)),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF1A922), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: widthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Paper Width (mm)",
                hintText: "Enter width in mm e.g. 58",
                prefixIcon: const Icon(Icons.swap_horiz, color: Color(0xFFF1A922)),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFF1A922), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF1A922),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (selectedPrinter != null &&
                            heightController.text.isNotEmpty &&
                            widthController.text.isNotEmpty) {
                          setState(() => _isSaving = true);
                          try {
                            Provider.of<ConfigurationPageController>(context, listen: false)
                                .setConfiguration(
                              selectedPrinter!,
                              double.tryParse(heightController.text) ?? 0,
                              double.tryParse(widthController.text) ?? 0,
                            );
                            await _incrementAppCount();

                            if (!mounted) return;

                            final storage = GetStorage();
                            final cachedData = storage.read('global_visitor_data');
                            final bool hasCache = cachedData != null &&
                                (cachedData is Map && cachedData['data'] != null) || appCount > 1;

                            if (!hasCache) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const DataLoaderScreen()),
                              );
                            } else {
                              Provider.of<MainController>(context, listen: false)
                                  .scannBarCode(context);
                            }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text("Please select a printer and enter valid paper dimensions"),
                                backgroundColor: const Color(0xFFD32F2F),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        }
                      },
                child: _isSaving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text("Please wait...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 8),
                          Text("Save & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
