import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF000000);
  static const elevated = Color(0xFF080808);
  static const textPrimary = Color(0xFFF2F2F5);
  static const textSecondary = Color(0xFFB8B8C0);
  static const textMuted = Color(0xFF74747D);
  static const border = Color(0x24FFFFFF);
  static const panel = Color(0x0CFFFFFF);
  static const panelStrong = Color(0x14FFFFFF);
  static const signalGreen = Color(0xFF7CFF9B);
  static const signalGold = Color(0xFFD8B24C);
  static const signalRed = Color(0xFFFF5B5B);
}

class AppTextStyles {
  static const hero = TextStyle(
    fontSize: 42,
    height: 0.98,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 31,
    height: 1.02,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.textSecondary,
  );

  static const micro = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.3,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.55,
    color: AppColors.textSecondary,
  );
}

ThemeData buildSwingLensTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.textPrimary,
      onPrimary: Colors.black,
      surface: AppColors.elevated,
      onSurface: AppColors.textPrimary,
      secondary: AppColors.textSecondary,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamily: 'Inter',
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      labelStyle: AppTextStyles.label,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.textPrimary),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: AppTextStyles.label,
      selectedColor: AppColors.textPrimary,
      backgroundColor: AppColors.panel,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.textPrimary,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        textStyle: AppTextStyles.label,
      ),
    ),
  );
}
