import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/configuration_page_controller.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Printer Configuration",
          style: TextStyle(
              color: Colors.indigo,
              fontSize: 25,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Card(
              child: Container(
                padding: EdgeInsets.only(top: 15, left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Select Printer Type",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    RadioListTile<String>(
                      value: "Sunmi",
                      groupValue: selectedPrinter,
                      title: const Text("Sunmi Printer"),
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
                      title: const Text("Bluetooth Printer"),
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
              decoration: const InputDecoration(
                  labelText: "Paper Height (mm)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: widthController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Paper Width (mm)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (selectedPrinter != null &&
                    heightController.text.isNotEmpty &&
                    widthController.text.isNotEmpty) {
                  Provider.of<ConfigurationPageController>(context, listen: false)
                      .setConfiguration(
                    selectedPrinter!,
                    double.tryParse(heightController.text) ?? 0,
                    double.tryParse(widthController.text) ?? 0,
                  );

                  // Navigate to loader+fetch screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const DataLoaderScreen()),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all the fields")),
                  );
                }
              },
              child: const Text("Continue"),
            )

          ],
        ),
      ),
    );
  }
}
