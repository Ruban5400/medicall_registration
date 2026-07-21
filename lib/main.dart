import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:medicall_registration_sunmi/screens/home_page.dart';
import 'package:medicall_registration_sunmi/utils/background_data_fetcher.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller/api_service.dart';
import 'controller/configuration_page_controller.dart';
import 'controller/main_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }

  try {
    await GetStorage.init();
  } catch (e) {
    debugPrint('GetStorage init error: $e');
  }

  try {
    await Supabase.initialize(
        url: "https://exwtyydfpbftnrkqntxb.supabase.co",
        anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4d3R5eWRmcGJmdG5ya3FudHhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ1MjY3MjIsImV4cCI6MjEwMDEwMjcyMn0.iWyUaRfG7Fz2BLIvc4DeV2ceM3eymdJUyqcQGWj4-14");
  } catch (e) {
    debugPrint('Supabase init warning: $e');
  }

  try {
    BackgroundDataFetcher().start();
  } catch (e) {
    debugPrint('BackgroundDataFetcher start error: $e');
  }

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
      child: MaterialApp(
        title: 'Medicall Registration',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF1A922),
            primary: const Color(0xFFF1A922),
            primaryContainer: const Color(0xFFFBE3A4),
            secondary: const Color(0xFFC68600),
            secondaryContainer: const Color(0xFFFFE8B3),
            surface: const Color(0xFFFFFFFF),
            surfaceContainerHighest: const Color(0xFFF8F8F8),
            error: const Color(0xFFD32F2F),
            onPrimary: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFFFFDF8),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF1A922),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            color: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8F8F8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF1A922), width: 2),
            ),
            hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 1,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              backgroundColor: const Color(0xFFF1A922),
              foregroundColor: Colors.white,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: Color(0xFFF1A922),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
