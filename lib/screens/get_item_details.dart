import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import '../controller/api_service.dart';
import '../controller/configuration_page_controller.dart';
import '../controller/main_controller.dart';
import '../utils/sunmi_helper_class.dart';
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
  bool _isPrinting = false;
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _findVisitorByMobile(String mobileNumber) async {
    final rawStorage = storage.read('global_visitor_data');
    final List<dynamic>? visitorList =
        (rawStorage is Map && rawStorage['data'] is List) ? rawStorage['data'] as List<dynamic> : null;

    if (visitorList != null) {
      final visitors = visitorList;
      final foundVisitor = visitors.firstWhere(
        (v) => v is Map && v['mobile_number'] == mobileNumber,
        orElse: () => null,
      );
      if (foundVisitor != null) {
        if (mounted) {
          setState(() {
            var globalData = Map<String, dynamic>.from(foundVisitor);
            selectedVisitor = {
              'name': '${globalData['salutation'] ?? ''} ${globalData['name'] ?? ''}'.trim(),
              'mobile_number': globalData['mobile_number'],
              'email': globalData['email'],
              'designation': globalData['designation'],
              'company': globalData['organization'],
            };
            printSelectedVisitor = globalData;
          });
        }
      } else {
        try {
          final response = await http
              .get(Uri.parse(
                  'https://crm.medicall.in/api/search-global-visitor?mobile_number=$mobileNumber'))
              .timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final json = jsonDecode(response.body);

            if (json is Map && json['status'] == 'success') {
              final source = json['data_from'];

              if (source == 'crm' && json['data'] is Map) {
                final crmData = json['data'];
                if (mounted) {
                  setState(() {
                    selectedVisitor = {
                      'name': '${crmData['salutation'] ?? ''} ${crmData['name'] ?? ''}'.trim(),
                      'mobile_number': crmData['mobile_number'],
                      'email': crmData['email'],
                      'designation': crmData['designation'],
                      'company': crmData['organization'],
                    };
                    printSelectedVisitor = Map<String, dynamic>.from(json['data']);
                  });
                }
              } else if ((source == 'goman' || source == null) && json['data'] is Map) {
                final gomanData = json['data'];
                if (mounted) {
                  setState(() {
                    selectedVisitor = {
                      'name': '${gomanData['title'] ?? ''} ${gomanData['name'] ?? ''}'.trim(),
                      'mobile_number': gomanData['mobile'],
                      'email': gomanData['email'],
                      'designation': gomanData['designation'],
                      'company': gomanData['company'],
                    };
                    printSelectedVisitor = Map<String, dynamic>.from(json['data']);
                  });
                }
              }
            } else {
              _showNotFoundSnackbar();
            }
          } else {
            _showNotFoundSnackbar();
          }
        } catch (e) {
          debugPrint('🌐 Error while fetching global visitor: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error fetching visitor data')),
            );
          }
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _showNotFoundSnackbar() {
    if (mounted) {
      setState(() {
        _hasSearched = true;
        selectedVisitor = null;
        printSelectedVisitor = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('Visitor not found in system database'),
            ],
          ),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showPrintSuccessNotification(String visitorName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Badge Printed Successfully — $visitorName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigurationPageController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      appBar: AppBar(
        title: const Text(
          "Visitor Search & Registration",
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
      body: Consumer<MainController>(
        builder: (BuildContext context, MainController value, Widget? child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Form(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search Input Card
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
                              Icon(Icons.search_outlined, color: Color(0xFFF1A922)),
                              SizedBox(width: 8),
                              Text(
                                "Enter Mobile / Registration Code",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E1E1E),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CustomTextFieldDesign(
                            label: 'Mobile / Code',
                            controller: value.getItemController,
                            focusNode: _focusNode,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Get Details Button
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF1A922),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: (_isSearching || _isPrinting)
                                        ? null
                                        : () async {
                                            String mobile = value.getItemController.text.trim();
                                            setState(() {
                                              _isSearching = true;
                                              _hasSearched = true;
                                            });
                                            try {
                                              _findVisitorByMobile(mobile);
                                            } finally {
                                              if (mounted) {
                                                setState(() {
                                                  _isSearching = false;
                                                });
                                              }
                                            }
                                          },
                                    child: _isSearching
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
                                              Text("Please wait...",
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.search, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text("Get Details",
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                  ),
                                ),
                              ),

                              if (printSelectedVisitor != null) const SizedBox(width: 12),

                              // Print Button
                              if (printSelectedVisitor != null)
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFC68600),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: (_isPrinting || _isSearching)
                                          ? null
                                          : () async {
                                              if (_isPrinting) return;
                                              setState(() {
                                                _isPrinting = true;
                                                value.getItemController.clear();
                                              });

                                              final vName = selectedVisitor?['name']?.toString() ?? 'Visitor';

                                              try {
                                                Sunmi printer = Sunmi(printSelectedVisitor: printSelectedVisitor);
                                                await printer.printReceipt(config.paperWidth, config.paperHeight);

                                                if (printSelectedVisitor != null) {
                                                  printSelectedVisitor!['is_visited'] = true;
                                                }

                                                final mobile = selectedVisitor?['mobile_number']?.toString() ?? '';
                                                if (mobile.isNotEmpty && printSelectedVisitor != null) {
                                                  final success = await ApiService.sendVisitorData(
                                                    printSelectedVisitor!,
                                                    mobile,
                                                  );

                                                  if (!success) {
                                                    debugPrint("Failed to send data to server");
                                                  }
                                                }

                                                if (mounted) {
                                                  _showPrintSuccessNotification(vName);
                                                  Provider.of<MainController>(context, listen: false)
                                                      .scannBarCode(context);
                                                }
                                              } catch (e) {
                                                debugPrint("Print error: $e");
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isPrinting = false;
                                                  });
                                                }
                                              }
                                            },
                                      child: _isPrinting
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
                                                Text("Please wait...",
                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: const [
                                                Icon(Icons.print_outlined, color: Colors.white),
                                                SizedBox(width: 6),
                                                Text("Print Badge",
                                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error / Empty State Card
                  if (selectedVisitor == null && _hasSearched)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off_rounded, size: 56, color: Color(0xFFC68600)),
                            const SizedBox(height: 12),
                            const Text(
                              "Visitor Not Found",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E)),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "Check the QR code or try scanning again.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Provider.of<MainController>(context, listen: false).scannBarCode(context);
                                },
                                icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                                label: const Text("Scan Again", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1A922),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Premium Visitor Details Card
                  if (selectedVisitor != null)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Visitor Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF1A922),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (printSelectedVisitor?['is_visited'] == true)
                                        ? const Color(0xFFFFF9C4)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (printSelectedVisitor?['is_visited'] == true)
                                        ? "🟡 Already Printed"
                                        : "🟢 Ready",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: (printSelectedVisitor?['is_visited'] == true)
                                          ? const Color(0xFFC68600)
                                          : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: Color(0xFFD9D9D9)),
                            ...selectedVisitor!.entries.map((entry) {
                              final labelKey = entry.key.toString().replaceAll('_', ' ').toUpperCase();
                              final valStr = entry.value?.toString() ?? '';

                              IconData rowIcon = Icons.info_outline;
                              if (labelKey.contains('NAME')) rowIcon = Icons.person_outline;
                              if (labelKey.contains('MOBILE') || labelKey.contains('PHONE')) rowIcon = Icons.phone_outlined;
                              if (labelKey.contains('EMAIL')) rowIcon = Icons.email_outlined;
                              if (labelKey.contains('DESIGNATION')) rowIcon = Icons.work_outline;
                              if (labelKey.contains('COMPANY') || labelKey.contains('ORGANIZATION')) rowIcon = Icons.business_outlined;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(rowIcon, size: 20, color: const Color(0xFFF1A922)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: "$labelKey\n",
                                              style: const TextStyle(
                                                color: Color(0xFF666666),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TextSpan(
                                              text: valStr.isNotEmpty ? valStr : '-',
                                              style: const TextStyle(
                                                color: Color(0xFF1E1E1E),
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          Provider.of<MainController>(context, listen: false)
              .scannBarCode(context);
        },
        backgroundColor: const Color(0xFFF1A922),
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text("Scan QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
