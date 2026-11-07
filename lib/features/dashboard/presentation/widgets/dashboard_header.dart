import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';

/// The top of the FA dashboard (2.12a): a deep blue gradient with the
/// greeting, today's date, the season, whether registration is open, the
/// bell, and the Ghana stripe underneath. It scrolls away with the page.
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key, required this.wide});

  /// Tablet or laptop: more room and a bigger greeting.
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The sign-in account's name (Google's for Google users), as on
    // My profile; then the one on the user document
    final name =
        AuthRepository.nameOf(ref.watch(currentUserProvider).value) ??
        ref.watch(appUserProvider).value?.displayName;
    final settings = ref.watch(leagueSettingsProvider).value;
    final now = DateTime.now();
    // Under the phone's status bar the gradient goes on, the text doesn't
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? AppColors.darkHeroGradient
                  : AppColors.heroGradient,
              stops: const [0, 0.55, 1],
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                // Two soft circles, only for looks (as in the mockup)
                Positioned(
                  right: -60,
                  top: -70,
                  child: _Ring(
                    size: 220,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                Positioned(
                  right: 40,
                  bottom: -90,
                  child: _Disc(
                    size: 160,
                    color: AppColors.ghanaGold.withValues(alpha: 0.08),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 28 : 18,
                    top + (wide ? 22 : 14),
                    wide ? 20 : 10,
                    wide ? 26 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'GEDFA CONNECT · FA',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          IconButtonTheme(
                            data: IconButtonThemeData(
                              style: IconButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.14,
                                ),
                              ),
                            ),
                            child: const NotificationBell(),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _greeting(now, name),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: wide ? 28 : 23,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatLongDate(now),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Tag(
                            icon: Icons.emoji_events_outlined,
                            label:
                                'Season ${Season.label(settings?.season ?? Season.current)}',
                          ),
                          if (settings != null) ...[
                            _Tag(
                              open: settings.teamRegistrationOpen,
                              label: settings.teamRegistrationOpen
                                  ? 'Teams open'
                                  : 'Teams closed',
                            ),
                            _Tag(
                              open: settings.playerRegistrationOpen,
                              label: settings.playerRegistrationOpen
                                  ? 'Players open'
                                  : 'Players closed',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const FlagStripe(height: 4),
      ],
    );
  }

  /// "Good morning, Isaac" (first name only; no name: "Good morning")
  static String _greeting(DateTime now, String? displayName) {
    final part = now.hour < 12
        ? 'morning'
        : now.hour < 17
        ? 'afternoon'
        : 'evening';
    final first = displayName?.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? 'Good $part' : 'Good $part, $first';
  }
}

/// A see-through pill in the header: an icon, or a green (open) or red
/// (closed) dot, then the text.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.open});

  final String label;
  final IconData? icon;

  /// Registration tags only: true = green dot, false = red dot.
  final bool? open;

  @override
  Widget build(BuildContext context) {
    final dot = open == true ? AppColors.darkGreen : const Color(0xFFFF8A94);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: Colors.white)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dot.withValues(alpha: 0.25),
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 28),
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
