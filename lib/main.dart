import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:medicall_registration_sunmi/screens/home_page.dart';
import 'package:medicall_registration_sunmi/utils/background_data_fetcher.dart';
import 'package:provider/provider.dart';

import 'controller/api_service.dart';
import 'controller/configuration_page_controller.dart';
import 'controller/main_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  // Start background fetcher
  BackgroundDataFetcher().start();
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
        ),
        ChangeNotifierProvider(
          create: (context) => MainController(),
        ),
        ChangeNotifierProvider(create: (_) => ApiService()),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
