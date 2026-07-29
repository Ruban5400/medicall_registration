import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import '../controller/configuration_page_controller.dart';
import '../utils/widgets/scan_vCard.dart';
import 'configuration_screen.dart';

final List<Map<String, dynamic>> gridItems = [
  {'image': 'assets/lottie/checkIn.json', 'label': 'Check in'},
  {'image': 'assets/lottie/qr.json', 'label': 'Registration'},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController hallController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? selectedHallCode;

  @override
  void initState() {
    super.initState();
    hallController = TextEditingController();
    selectedHallCode = GetStorage().read('selected_hall');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ConfigurationPageController>(context, listen: false)
            .configurePageInitialization();
      }
    });
  }

  List<Map<String, dynamic>> _getHalls() {
    final rawHalls = GetStorage().read('hall_master');
    if (rawHalls is List && rawHalls.isNotEmpty) {
      return rawHalls.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [
      {'hall_code': 'Hall 1', 'hall_name': 'Hall 1'},
      {'hall_code': 'Hall 2', 'hall_name': 'Hall 2'},
      {'hall_code': 'Hall 3', 'hall_name': 'Hall 3'},
      {'hall_code': 'Hall 4', 'hall_name': 'Hall 4'},
    ];
  }

  @override
  void dispose() {
    hallController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Consumer<ConfigurationPageController>(
              builder: (BuildContext context, ConfigurationPageController value,
                  Widget? child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Brand Logo & Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/Logo.png',
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Medicall Visitor Management",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFF1A922),
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Visitor Registration System",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Grid Action Cards
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(gridItems.length, (index) {
                        final label = gridItems[index]['label'] as String;
                        final isCheckIn = label == 'Check in';
                        final iconData = isCheckIn
                            ? Icons.qr_code_scanner
                            : Icons.badge_outlined;
                        final subtitleText = isCheckIn
                            ? "Scan visitor vCard QR"
                            : "Lookup visitor & print badge";

                        return InkWell(
                          onTap: () {
                            if (isCheckIn) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return StatefulBuilder(
                                    builder: (BuildContext context,
                                        StateSetter setDialogState) {
                                      final hallList = _getHalls();
                                      final bool hasMatchingSelected =
                                          selectedHallCode != null &&
                                              hallList.any((h) =>
                                                  h['hall_code'] ==
                                                  selectedHallCode);
                                      final currentSelected =
                                          hasMatchingSelected
                                              ? selectedHallCode
                                              : (hallList.isNotEmpty
                                                  ? hallList.first['hall_code']
                                                      as String
                                                  : null);

                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        title: Row(
                                          children: const [
                                            Icon(Icons.meeting_room_outlined,
                                                color: Color(0xFFF1A922)),
                                            SizedBox(width: 10),
                                            Text(
                                              "Select Exhibition Hall",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1E1E1E),
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              DropdownButtonFormField<String>(
                                                value: currentSelected,
                                                isExpanded: true,
                                                decoration: InputDecoration(
                                                  labelText: "Select Hall",
                                                  prefixIcon: const Icon(
                                                      Icons
                                                          .meeting_room_outlined,
                                                      color: Color(0xFFF1A922)),
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xFFF8F8F8),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide:
                                                        const BorderSide(
                                                            color: Color(
                                                                0xFFF1A922),
                                                            width: 2),
                                                  ),
                                                ),
                                                items: hallList.map((hall) {
                                                  final code = hall['hall_code']
                                                      .toString();
                                                  final name = hall['hall_name']
                                                      .toString();
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: code,
                                                    child: Text(
                                                      name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                              0xFF1E1E1E)),
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setDialogState(() {
                                                      selectedHallCode = value;
                                                    });
                                                    setState(() {
                                                      selectedHallCode = value;
                                                    });
                                                    GetStorage().write(
                                                        'selected_hall', value);
                                                  }
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return 'Please select a hall';
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 20),
                                              SizedBox(
                                                width: double.infinity,
                                                height: 52,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    final hallToUse =
                                                        selectedHallCode ??
                                                            currentSelected;
                                                    if (hallToUse != null &&
                                                        hallToUse.isNotEmpty) {
                                                      if (VCardScanner.isScannerOpen) return;
                                                      GetStorage().write(
                                                          'selected_hall',
                                                          hallToUse);
                                                      Navigator.pop(context);
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              VCardScanner(
                                                                  hallToUse),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(
                                                      Icons.arrow_forward,
                                                      color: Colors.white),
                                                  label: const Text(
                                                    "Proceed to Scan",
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFF1A922),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PrinterConfigurationScreen(),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFBE3A4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      iconData,
                                      size: 32,
                                      color: const Color(0xFFC68600),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF1E1E1E),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitleText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 11,
                                    ),
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
      ),
    );
  }
}
