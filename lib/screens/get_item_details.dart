import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/main_controller.dart';
import '../utils/string_constants.dart';
import '../utils/sunmi_helper_class.dart';
import '../utils/widgets/button_widget.dart';

import '../models/bar_code_item_models.dart';
import '../utils/widgets/custom_text_field_design.dart';

class GetItemDetails extends StatefulWidget {
  const GetItemDetails({super.key});

  @override
  State<GetItemDetails> createState() => _GetItemDetailsState();
}

class _GetItemDetailsState extends State<GetItemDetails> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<MainController>(
        builder: (BuildContext context, MainController value, Widget? child) {
          return Form(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CustomTextFieldDesign(
                    label: 'Enter code', controller: value.getItemController),
                SizedBox(
                  height: 10,
                ),
                ButtonWidget(
                    text: "Get Details",
                    onClicked: () async {
                      await value.getDetailsMethod();
                      setState(() {});
                    }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 36.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              child: const Icon(Icons.print),
              onPressed: () async {
                Sunmi printer = Sunmi();
                printer.printReceipt();
              },
            ),
            FloatingActionButton(
              child: const Icon(Icons.qr_code_scanner),
              onPressed: () async {
                Provider.of<MainController>(context, listen: false)
                    .scannBarCode();
              },
            ),
          ],
        ),
      ),
    );
  }
}
