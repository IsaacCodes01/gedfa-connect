import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const brandBlue = Color(0xFF1E88E5);
  static const deepBlue = Color(0xFF1259A8);
  static const ghanaRed = Color(0xFFCE1126);
  static const ghanaGold = Color(0xFFFCD116);
  static const ghanaGreen = Color(0xFF006B3F);

  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF4A5A70);
  static const background = Color(0xFFF4F7FB);
  static const border = Color(0xFFC3CFDC);

  static const approvedBg = Color(0xFFE3F2EA);
  static const approvedText = Color(0xFF00502F);
  static const pendingBg = Color(0xFFFFF6CC);
  static const pendingText = Color(0xFF5C4700);
  static const rejectedBg = Color(0xFFFDE7EA);
  static const rejectedText = Color(0xFFA10E1F);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      primary: AppColors.deepBlue,
      error: AppColors.ghanaRed,
      surface: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    final textTheme = GoogleFonts.barlowTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: AppColors.ink,
      ),
      titleLarge: GoogleFonts.barlowCondensed(
        fontWeight: FontWeight.w700,
        fontSize: 24,
        color: AppColors.ink,
      ),
    );

    OutlineInputBorder outline(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: outline(AppColors.border, 1.5),
        focusedBorder: outline(AppColors.deepBlue, 2),
        errorBorder: outline(AppColors.ghanaRed, 2),
        focusedErrorBorder: outline(AppColors.ghanaRed, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.barlow(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}