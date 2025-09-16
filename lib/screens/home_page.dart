import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../controller/configuration_page_controller.dart';
import '../utils/widgets/scan_vCard.dart';
import 'configuration_screen.dart';

final List<Map<String, dynamic>> gridItems = [
  {'image': 'assets/lottie/checkIn.json', 'label': 'Check in'},
  {'image': 'assets/lottie/qr.json', 'label': 'Registration'},
];

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController hallController = TextEditingController();
    final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

    Provider.of<ConfigurationPageController>(context, listen: false)
        .configurePageInitialization();
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          child: Consumer<ConfigurationPageController>(
            builder: (BuildContext context, ConfigurationPageController value,
                Widget? child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 100,
                    child: Image.asset('assets/images/Logo.png'),
                  ),
                  // const Text(
                  //   "Registration",
                  //   style: TextStyle(
                  //       color: Colors.indigo,
                  //       fontSize: 25,
                  //       fontWeight: FontWeight.bold,
                  //       fontStyle: FontStyle.italic),
                  // ),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: List.generate(gridItems.length, (index) {
                      return GestureDetector(
                        onTap: () {
                          final label = gridItems[index]['label'];
                          if (label == 'Check in') {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Enter Hall Number"),
                                  content: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextFormField(
                                          controller: hallController,
                                          decoration: const InputDecoration(
                                            labelText: "Hall Number",
                                            hintText: "Enter your hall number",
                                            border: OutlineInputBorder(),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.trim().isEmpty) {
                                              return 'Hall number is required';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () {

                                            if (_formKey.currentState!.validate()) {
                                              Navigator.pop(context); // Close the dialog
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>  VCardScanner(hallController.text),
                                                ),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.arrow_forward,color: Colors.white),
                                          label: const Text("Proceed",style: TextStyle(color: Colors.white),),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo,
                                            padding:
                                            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PrinterConfigurationScreen(),
                              ),
                            );
                          }
                        },
                        child: Card(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                    width: 100,
                                    child: Lottie.asset(
                                        gridItems[index]['image']!)),
                                SizedBox(height: 10),
                                Text(
                                  gridItems[index]['label'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
