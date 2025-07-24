import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:medicall_registration_sunmi/screens/result_page.dart';
import 'package:provider/provider.dart';
import '../controller/api_service.dart';
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
  final storage = GetStorage();
  final FocusNode _focusNode = FocusNode();

  Map<String, dynamic>? selectedVisitor;
  Map<String, dynamic>? printSelectedVisitor;

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

  void _findVisitorByMobile(String mobileNumber) async {
    final List<dynamic>? visitorList =
        storage.read('global_visitor_data')['data'];

    if (visitorList != null) {
      final visitors = visitorList;
      final foundVisitor = visitors.firstWhere(
        (v) => v['mobile_number'] == mobileNumber,
        orElse: () => null,
      );
      if (foundVisitor != null) {
        setState(() {
          var globalData = Map<String, dynamic>.from(foundVisitor);
          selectedVisitor = {
            'name': '${globalData['salutation']} ${globalData['name']}',
            'mobile_number': globalData['mobile_number'],
            'email': globalData['email'],
            'designation': globalData['designation'],
            'company': globalData['organization'],
          };
          printSelectedVisitor = globalData;
        });
      } else {
        try {
          final response = await http.get(Uri.parse(
              'https://crm.medicall.in/api/search-global-visitor?mobile_number=$mobileNumber'));

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);

            if (json['status'] == 'success') {
              final source = json['data_from'];

              if (source == 'crm') {
                final crmData = json['data'];
                setState(() {
                  selectedVisitor = {
                    'name': '${crmData['salutation']} ${crmData['name']}',
                    'mobile_number': crmData['mobile_number'],
                    'email': crmData['email'],
                    'designation': crmData['designation'],
                    'company': crmData['organization'],
                  };
                  printSelectedVisitor = json['data'];
                });
              } else if (source == 'goman' || source == null) {
                // 7094473308
                final gomanData = json['data'];
                setState(() {
                  selectedVisitor = {
                    'name': '${gomanData['title']} ${gomanData['name']}',
                    'mobile_number': gomanData['mobile'],
                    'email': gomanData['email'],
                    'designation': gomanData['designation'],
                    'company': gomanData['company'],
                  };
                  printSelectedVisitor = json['data'];
                });
              }
            } else {
              _showNotFoundSnackbar();
            }
          } else {
            _showNotFoundSnackbar();
          }
        } catch (e) {
          debugPrint('🌐 Error while fetching global visitor: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching visitor data')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigurationPageController>(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Consumer<MainController>(
        builder: (BuildContext context, MainController value, Widget? child) {
          return Form(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 100.0),
              child: Column(
                mainAxisAlignment: selectedVisitor == null
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Visitor Data",
                    style: TextStyle(
                        color: Colors.indigo,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  CustomTextFieldDesign(
                    label: 'Enter code',
                    controller: value.getItemController,
                    focusNode: _focusNode,
                  ),
                  Text('${value.getItemController.text}'),
                  SizedBox(
                    height: 10,
                  ),
                  ButtonWidget(
                      text: "Get Details",
                      onClicked: () async {
                        String mobile = value.getItemController.text.trim();
                        _findVisitorByMobile(mobile);
                        setState(() {});
                      }),
                  SizedBox(
                    height: 10,
                  ),
                  if (printSelectedVisitor != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 100),
                      child: Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: selectedVisitor!.entries.map((entry) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            "${entry.key.toString().replaceAll('_', ' ').toUpperCase()}: ",
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextSpan(
                                        text: entry.value?.toString() ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  if (printSelectedVisitor != null)
                    ButtonWidget(
                        text: "Print",
                        onClicked: () async {
                          setState(() {
                            value.getItemController.clear();
                          });
                          Sunmi printer =
                              Sunmi(printSelectedVisitor: printSelectedVisitor);
                          printer.printReceipt(
                              config.paperWidth, config.paperHeight);
                          printSelectedVisitor!['is_visited'] = true;
                          final success = await ApiService.sendVisitorData(
                              printSelectedVisitor!,
                              selectedVisitor!['mobile_number']);
                          if (success) {
                            print("5400 0-=-=-=>>> $success");
                          } else {
                            // Show error or handle failure
                            print("Failed to send data to server");
                          }
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => NextPage()), // replace with your destination widget
                                (Route<dynamic> route) => false,
                          );
                        }),
                ],
              ),
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
                      .scannBarCode(context);
                },
              ),
            )
          : null,
    );
  }

  void _showNotFoundSnackbar() {
    setState(() {
      selectedVisitor = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Visitor not found')),
    );
  }
}
