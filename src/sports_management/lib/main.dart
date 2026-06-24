import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_management/injection/root_injection.dart';
import 'package:sports_management/app.dart';
import 'package:sports_management/core/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await FcmService.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  await RootInjection.setup();

  // Load persisted theme mode and language
  ThemeMode initialThemeMode = ThemeMode.system;
  String initialLanguageCode = 'vi';
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeStr = prefs.getString('theme_mode');
    if (savedThemeStr != null) {
      initialThemeMode = ThemeMode.values.firstWhere(
        (e) => e.name == savedThemeStr,
        orElse: () => ThemeMode.system,
      );
    }
    initialLanguageCode = prefs.getString('app_language') ?? 'vi';
  } catch (e) {
    debugPrint('Error loading saved configuration: $e');
  }

  runApp(
    App(
      initialThemeMode: initialThemeMode,
      initialLanguageCode: initialLanguageCode,
    ),
  );
}
