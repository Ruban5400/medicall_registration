import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/configuration_page_controller.dart';
import '../controller/main_controller.dart';
import '../utils/sunmi_helper_class.dart';
import '../utils/widgets/button_widget.dart';
import '../utils/widgets/custom_text_field_design.dart';

class GetItemDetails extends StatefulWidget {
  const GetItemDetails({super.key});

  @override
  State<GetItemDetails> createState() => _GetItemDetailsState();
}

class _GetItemDetailsState extends State<GetItemDetails> {
  final FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigurationPageController>(context);
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
                  label: 'Enter code',
                  controller: value.getItemController,
                  focusNode: _focusNode,
                ),
                SizedBox(
                  height: 10,
                ),
                ButtonWidget(
                    text: "Get Details",
                    onClicked: () async {
                      await value.getDetailsMethod();
                      setState(() {});
                    }),
                ButtonWidget(
                    text: "Print",
                    onClicked: () async {
                      Sunmi printer = Sunmi();
                      printer.printReceipt(config.paperWidth, config.paperHeight);
                    }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: config.printerType == 'Bluetooth'
          ? Padding(
              padding: const EdgeInsets.only(left: 36.0),
              child: FloatingActionButton(
                child: const Icon(Icons.qr_code_scanner),
                onPressed: () async {
                  Provider.of<MainController>(context, listen: false)
                      .scannBarCode();
                },
              ),
            )
          : null,
    );
  }
}
