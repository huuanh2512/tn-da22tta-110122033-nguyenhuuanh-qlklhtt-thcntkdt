import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../presentation/cubit/language_cubit.dart';

extension LocalizationExtension on BuildContext {
  String tr({required String vi, required String en}) {
    try {
      final lang = watch<LanguageCubit>().state;
      return lang == 'vi' ? vi : en;
    } catch (_) {
      // Fallback in case cubit is not available in context
      return vi;
    }
  }

  // Helper to read language without watching (for performance-sensitive or non-rebuilding context actions)
  String readTr({required String vi, required String en}) {
    try {
      final lang = read<LanguageCubit>().state;
      return lang == 'vi' ? vi : en;
    } catch (_) {
      return vi;
    }
  }
}
