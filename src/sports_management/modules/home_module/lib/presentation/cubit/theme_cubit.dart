import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app-wide theme mode (light/dark/system).
/// Provided at the root of the app via BlocProvider in app.dart.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({ThemeMode initialMode = ThemeMode.light}) : super(initialMode);

  void toggleTheme() {
    final nextMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    emit(nextMode);
    _saveTheme(nextMode);
  }

  void setTheme(ThemeMode mode) {
    emit(mode);
    _saveTheme(mode);
  }

  Future<void> _saveTheme(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode.name);
    } catch (e) {
      debugPrint('Error saving theme settings: $e');
    }
  }
}
