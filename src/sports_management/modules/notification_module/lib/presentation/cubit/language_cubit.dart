import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LanguageCubit extends Cubit<String> {
  LanguageCubit({String initialLanguage = 'vi'}) : super(initialLanguage);

  Future<void> setLanguage(String langCode) async {
    emit(langCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);
    } catch (e) {
      debugPrint('Error saving language setting: $e');
    }
  }
}
