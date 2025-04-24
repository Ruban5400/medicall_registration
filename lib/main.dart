import 'package:flutter/material.dart';
import 'package:medicall_registration_sunmi/screens/configuration_screen.dart';
import 'package:provider/provider.dart';

import 'controller/configuration_page_controller.dart';
import 'controller/main_controller.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => ConfigurationPageController(),
        ),ChangeNotifierProvider(
          create: (context) => MainController(),
        ),
      ],
      child: const MaterialApp(
        home: PrinterConfigurationScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
