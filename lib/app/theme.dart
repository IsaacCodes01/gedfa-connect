import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// The app bar (R-c, N1): solid navy, a shade deeper in dark mode. The
  /// Ghana stripe sits under it (`GedfaAppBar`).
  static const navy = heroDark;
  static const darkNavy = Color(0xFF081A30);
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

  // Dashboard (2.12): softer card border, and the header gradient
  static const cardBorder = Color(0xFFDCE5EF);
  static const darkCardBorder = Color(0xFF22385A);
  static const heroGradient = [heroDark, deepBlue, brandBlue];
  static const darkHeroGradient = [
    Color(0xFF081A30),
    heroDark,
    Color(0xFF15467F),
  ];
}

/// The coloured icon chips on the dashboard (2.12): a soft background
/// with a stronger icon colour, one pair for light and one for dark mode.
enum AccentTone {
  blue(Color(0xFFE3EEFB), Color(0xFF1259A8), Color(0xFF17345A),
      Color(0xFF7DBBFA)),
  violet(Color(0xFFECE8FB), Color(0xFF5B3FC4), Color(0xFF2A2450),
      Color(0xFFB6A6FF)),
  green(Color(0xFFE3F2EA), Color(0xFF00703F), Color(0xFF12382B),
      Color(0xFF5BD39A)),
  gold(Color(0xFFFFF4C2), Color(0xFF8A6A00), Color(0xFF3A3110),
      Color(0xFFFCD116)),
  red(Color(0xFFFDE7EA), Color(0xFFB3122A), Color(0xFF3D1820),
      Color(0xFFFF8A94)),
  // Nothing to do now (no match yet; waiting on the FA): the track colour
  grey(Color(0xFFE6EDF5), Color(0xFF4A5A70), Color(0xFF1B2F4B),
      Color(0xFF9FB0C4));

  const AccentTone(this._bg, this._fg, this._darkBg, this._darkFg);

  final Color _bg;
  final Color _fg;
  final Color _darkBg;
  final Color _darkFg;

  Color background(bool isDark) => isDark ? _darkBg : _bg;
  Color foreground(bool isDark) => isDark ? _darkFg : _fg;
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
    final cardBorder = isDark ? AppColors.darkCardBorder : AppColors.cardBorder;
    // Buttons: a little less space at the sides, so their words fit on
    // one line when buttons share a row (with `OneLine`)
    const buttonPadding = EdgeInsets.symmetric(horizontal: 18);
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
      // R-c (N1): solid navy, the Ghana stripe under it in GedfaAppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.darkNavy : AppColors.navy,
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
          padding: buttonPadding,
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
          padding: buttonPadding,
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
      // R-c (R5): white cards, a soft border and shadow, round corners
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isDark ? 0 : 1.5,
        shadowColor: const Color(0x2E0F1B2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cardBorder),
        ),
      ),
      // Dialogs: round, the page's surface, Poppins titles
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      // Bottom sheets (a match's ⋯, pickers): round top corners
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: cardBorder,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      // Filter chips as pills; a picked one has a gold edge
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: navPill,
        checkmarkColor: navActive,
        shape: const StadiumBorder(),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.ghanaGold
                : scheme.outline,
            width: 1.5,
          ),
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: navActive,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      // Snack bars: dark, rounded, floating, a gold action
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkInk : AppColors.ink,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? AppColors.ink : Colors.white,
        ),
        actionTextColor: isDark ? AppColors.deepBlue : AppColors.ghanaGold,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
      // Phones slide; the web (laptops, and phones in a browser) fades,
      // which feels less like a phone on a big screen (R-c)
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _FadePageTransitionsBuilder(),
                TargetPlatform.iOS: _FadePageTransitionsBuilder(),
                TargetPlatform.windows: _FadePageTransitionsBuilder(),
                TargetPlatform.macOS: _FadePageTransitionsBuilder(),
                TargetPlatform.linux: _FadePageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
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

/// A quick fade between pages on the web (R-c).
class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}
