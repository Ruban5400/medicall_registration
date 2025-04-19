import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/configuration_page_controller.dart';
import '../controller/helper_services.dart';
import '../screens/get_item_details.dart';
import '../utils/widgets/button_widget.dart';

import '../utils/widgets/custom_text_field_design.dart';

final List<Map<String, dynamic>> gridItems = [
  {'image': 'assets/images/spot.png', 'label': 'Spot Registration'},
  {'image': 'assets/images/online.png', 'label': 'Online Registration'},
  {'image': 'assets/images/whatsapp.png', 'label': 'Whatsapp Registration'},
  {'image': 'assets/images/delegate.png', 'label': 'Online Delegates'},
];

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const Text(
                    "Registration",
                    style: TextStyle(
                        color: Colors.indigo,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic),
                  ),
                  // CustomTextFieldDesign(
                  //   enable: value.enableTextField,
                  //   label: 'Server name',
                  //   hint: '192.168.100.75',
                  //   controller: value.serverNameController,
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
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const GetItemDetails(),
                              ));
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
                                Image.asset(
                                  gridItems[index]['image']!,
                                  height: 50,
                                  width: 50,
                                  fit: BoxFit.contain,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  gridItems[index]['label'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     ButtonWidget(
                  //       text: "Configure",
                  //       onClicked: () async {
                  //         Provider.of<ConfigurationPageController>(context,
                  //                 listen: false)
                  //             .saveConfiguration();
                  //         if (!context.mounted) return;
                  //         Navigator.push(
                  //             context,
                  //             MaterialPageRoute(
                  //               builder: (context) => const GetItemDetails(),
                  //             ));
                  //       },
                  //     ),
                  //     SizedBox(
                  //       width: 20,
                  //     ),
                  //     ButtonWidget(
                  //       text: "Reset",
                  //       onClicked: () async {
                  //         await HelperServices.setConfiguration(false);
                  //         if (!context.mounted) return;
                  //         Provider.of<ConfigurationPageController>(context,
                  //                 listen: false)
                  //             .configurePageInitialization();
                  //       },
                  //     ),
                  //   ],
                  // )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
