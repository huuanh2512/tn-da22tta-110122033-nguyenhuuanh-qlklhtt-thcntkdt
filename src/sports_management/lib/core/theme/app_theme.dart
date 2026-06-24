import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

final class AppTheme {
  const AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: const ColorScheme.light(
          primary: AppColors.ink,
          onPrimary: AppColors.inverseInk,
          secondary: AppColors.finOrange,
          onSecondary: AppColors.inverseInk,
          surface: AppColors.surface1,
          onSurface: AppColors.ink,
          error: AppColors.semanticError,
          onError: AppColors.inverseInk,
          outline: AppColors.hairline,
          surfaceContainerHighest: AppColors.surface2,
        ),
        textTheme: TextTheme(
          displayLarge: AppTypography.displayXl,
          displayMedium: AppTypography.displayLg,
          displaySmall: AppTypography.displayMd,
          headlineLarge: AppTypography.headline,
          headlineMedium: AppTypography.cardTitle,
          titleLarge: AppTypography.subhead,
          bodyLarge: AppTypography.bodyLg,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.bodySm,
          labelLarge: AppTypography.button,
          labelSmall: AppTypography.caption.copyWith(color: AppColors.inkMuted),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.canvas,
          foregroundColor: AppColors.ink,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.cardTitle.copyWith(color: AppColors.ink),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface1,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: const BorderSide(color: AppColors.hairline, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.inverseInk,
            textStyle: AppTypography.button,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface1,
            foregroundColor: AppColors.ink,
            textStyle: AppTypography.button,
            side: const BorderSide(color: AppColors.hairline, width: 1),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.ink,
            textStyle: AppTypography.button,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface1,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.semanticError),
          ),
          hintStyle: AppTypography.body.copyWith(color: AppColors.inkTertiary),
          labelStyle: AppTypography.bodySm.copyWith(color: AppColors.inkMuted),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.hairlineSoft,
          thickness: 1,
          space: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surface1,
          selectedItemColor: AppColors.ink,
          unselectedItemColor: AppColors.inkMuted,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface2,
          labelStyle: AppTypography.bodySm,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.ink,
          contentTextStyle: AppTypography.bodySm.copyWith(
            color: AppColors.inverseInk,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          behavior: SnackBarBehavior.floating,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.inkMuted,
          textColor: AppColors.ink,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          titleTextStyle: AppTypography.cardTitle.copyWith(color: AppColors.ink),
          contentTextStyle: AppTypography.body.copyWith(color: AppColors.inkMuted),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTypography.bodySm.copyWith(color: AppColors.ink),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(AppColors.surface1),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Color(0xFF121212),
          secondary: AppColors.finOrange,
          onSecondary: Colors.white,
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
          error: AppColors.semanticError,
          onError: Colors.white,
          outline: Color(0xFF2C2C2C),
          surfaceContainerHighest: Color(0xFF2C2C2C),
        ),
        textTheme: TextTheme(
          displayLarge: AppTypography.displayXl,
          displayMedium: AppTypography.displayLg,
          displaySmall: AppTypography.displayMd,
          headlineLarge: AppTypography.headline,
          headlineMedium: AppTypography.cardTitle,
          titleLarge: AppTypography.subhead,
          bodyLarge: AppTypography.bodyLg,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.bodySm,
          labelLarge: AppTypography.button,
          labelSmall: AppTypography.caption.copyWith(color: Colors.grey.shade400),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF121212),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          // Must explicitly set white to override typography default
          titleTextStyle: AppTypography.cardTitle.copyWith(color: Colors.white),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.lgAll,
            side: const BorderSide(color: Color(0xFF2C2C2C), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.finOrange,
            foregroundColor: Colors.white,
            textStyle: AppTypography.button,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E1E),
            foregroundColor: Colors.white,
            textStyle: AppTypography.button,
            side: const BorderSide(color: Color(0xFF2C2C2C), width: 1),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            textStyle: AppTypography.button,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.buttonVertical,
              horizontal: AppSpacing.buttonHorizontal,
            ),
            minimumSize: const Size(0, 40),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: Color(0xFF2C2C2C)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.finOrange, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdAll,
            borderSide: const BorderSide(color: AppColors.semanticError),
          ),
          hintStyle: AppTypography.body.copyWith(color: const Color(0xFF9E9E9E)),
          labelStyle: AppTypography.bodySm.copyWith(color: const Color(0xFFBDBDBD)),
          // Ensure input text is visible on dark background
          prefixIconColor: const Color(0xFF9E9E9E),
          suffixIconColor: const Color(0xFF9E9E9E),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2C2C2C),
          thickness: 1,
          space: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: AppColors.finOrange,
          unselectedItemColor: Colors.grey,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF2C2C2C),
          labelStyle: AppTypography.bodySm.copyWith(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFFF5F5F5),
          contentTextStyle: AppTypography.bodySm.copyWith(
            color: Colors.black87,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          behavior: SnackBarBehavior.floating,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFF9E9E9E),
          textColor: Colors.white,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
          titleTextStyle: AppTypography.cardTitle.copyWith(color: Colors.white),
          contentTextStyle: AppTypography.body.copyWith(color: Colors.white70),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: AppTypography.bodySm.copyWith(color: Colors.white),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xFF2C2C2C)),
          ),
        ),
      );
}