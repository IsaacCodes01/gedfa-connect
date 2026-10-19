import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // Brand
  static const brandBlue = Color(0xFF1E88E5);
  static const deepBlue = Color(0xFF1259A8);
  static const heroDark = Color(0xFF0F2A4A);
  static const ghanaRed = Color(0xFFCE1126);
  static const ghanaGold = Color(0xFFFCD116);
  static const ghanaGreen = Color(0xFF006B3F);

  // Light mode
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF4A5A70);
  static const background = Color(0xFFEEF3F9);
  static const border = Color(0xFFC9D5E2);

  // Dark mode
  static const darkBackground = Color(0xFF0B1626);
  static const darkSurface = Color(0xFF13233A);
  static const darkField = Color(0xFF0F1D31);
  static const darkInk = Color(0xFFE8EEF6);
  static const darkMuted = Color(0xFF9FB0C4);
  static const darkBorder = Color(0xFF2A3F5C);
  static const darkPrimary = Color(0xFF4FA3F7);
  static const darkGreen = Color(0xFF5BD39A);
  static const darkLink = Color(0xFF7DBBFA);

  // Navigation (bottom bar / rail): pill behind the selected tab
  static const navPill = Color(0xFFDCEAF9);
  static const darkNavPill = Color(0xFF1E3A5F);

  // Status badges
  static const approvedBg = Color(0xFFE3F2EA);
  static const approvedText = Color(0xFF00502F);
  static const pendingBg = Color(0xFFFFF6CC);
  static const pendingText = Color(0xFF5C4700);
  static const rejectedBg = Color(0xFFFDE7EA);
  static const rejectedText = Color(0xFFA10E1F);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandBlue,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? AppColors.darkPrimary : AppColors.deepBlue,
      onPrimary: isDark ? const Color(0xFF06121F) : Colors.white,
      surface: isDark ? AppColors.darkSurface : Colors.white,
      onSurface: isDark ? AppColors.darkInk : AppColors.ink,
      onSurfaceVariant: isDark ? AppColors.darkMuted : AppColors.muted,
      outline: isDark ? AppColors.darkBorder : AppColors.border,
      error: isDark ? const Color(0xFFFF8A94) : const Color(0xFFB3122A),
    );

    final navActive = isDark ? AppColors.darkLink : AppColors.deepBlue;
    final navPill = isDark ? AppColors.darkNavPill : AppColors.navPill;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    OutlineInputBorder outline(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return base.copyWith(
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium
            ?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: textTheme.titleLarge
            ?.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.heroDark : AppColors.brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkField : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: outline(scheme.outline, 1.5),
        disabledBorder: outline(scheme.outline.withValues(alpha: 0.5), 1.5),
        focusedBorder: outline(scheme.primary, 2),
        errorBorder: outline(scheme.error, 2),
        focusedErrorBorder: outline(scheme.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkLink : AppColors.deepBlue,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      // "Add player" and other main actions: filled deep blue, white text
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 72,
        indicatorColor: navPill,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? navActive
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? navActive : scheme.onSurfaceVariant,
            );
          },
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: navPill,
        selectedIconTheme: IconThemeData(color: navActive),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: navActive,
        ),
        unselectedLabelTextStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}