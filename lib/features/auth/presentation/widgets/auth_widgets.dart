import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/pitch_lines_painter.dart';
import 'package:gedfa_connect/core/widgets/theme_toggle_button.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.hero,
    required this.card,
    this.heroHeight = 260,
    this.heroAlignment = Alignment.center,
    this.showBack = false,
    this.footer,
  });

  final Widget hero;
  final Widget card;
  final double heroHeight;
  final Alignment heroAlignment;
  final bool showBack;
  final Widget? footer;

  static const _overlap = 56.0;
  static const _stripeHeight = 5.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            Stack(
              children: [
                // Bottom layer: blue header + flag stripe
                Column(
                  children: [
                    SizedBox(
                      height: top + heroHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: isDark
                                  ? AppColors.heroDark
                                  : AppColors.brandBlue,
                            ),
                          ),
                          const Positioned.fill(
                            child: CustomPaint(painter: PitchLinesPainter()),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            top: top + 56,
                            bottom: _overlap + 12,
                            child: Align(alignment: heroAlignment, child: hero),
                          ),
                          Positioned(
                            top: top + 8,
                            left: 8,
                            right: 12,
                            child: Row(
                              children: [
                                if (showBack)
                                  const BackButton(color: Colors.white)
                                else
                                  const SizedBox(width: 48),
                                const Spacer(),
                                const ThemeToggleButton(onHero: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const FlagStripe(height: _stripeHeight),
                  ],
                ),
                // Top layer: the card, pushed down so it overlaps the header
                Padding(
                  padding: EdgeInsets.only(
                    top: top + heroHeight + _stripeHeight - _overlap,
                  ),
                  child: ResponsiveCenter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.45)
                                  : AppColors.deepBlue.withValues(alpha: 0.16),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: card,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(child: Divider(color: scheme.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Expanded(child: Divider(color: scheme.outline)),
      ],
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final bool isLoading;

  // Colours required by Google's branding rules
  static const _lightFill = Color(0xFFFFFFFF);
  static const _lightBorder = Color(0xFF747775);
  static const _lightText = Color(0xFF1F1F1F);
  static const _darkFill = Color(0xFF131314);
  static const _darkBorder = Color(0xFF8E918F);
  static const _darkText = Color(0xFFE3E3E3);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? _darkFill : _lightFill;
    final border = isDark ? _darkBorder : _lightBorder;
    final text = isDark ? _darkText : _lightText;

    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: text,
        disabledBackgroundColor: fill,
        disabledForegroundColor: text.withValues(alpha: 0.5),
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: GoogleFonts.roboto(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: text),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/google_g.png',
                  width: 20,
                  height: 20,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                const Text('Continue with Google'),
              ],
            ),
    );
  }
}