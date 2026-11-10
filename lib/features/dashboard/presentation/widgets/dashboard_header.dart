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
///
/// The team's Home (TDa) uses it too, with its own [label], the club's
/// [crest] beside the greeting, a [subtitle] ("Royal Unique FC · Tue
/// 10 Nov") and its own [tags].
class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({
    super.key,
    required this.wide,
    this.label = 'GEDFA CONNECT · FA',
    this.crest,
    this.subtitle,
    this.tags,
  });

  /// Tablet or laptop: more room and a bigger greeting.
  final bool wide;

  /// The small line at the top.
  final String label;

  /// Optional: the club's crest, left of the greeting.
  final Widget? crest;

  /// Under the greeting. Default: today's date in full.
  final String? subtitle;

  /// Default: the FA's (season, team and player registration).
  final List<HeaderTag>? tags;

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
                              label,
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
                      _Greeting(
                        crest: crest,
                        greeting: _greeting(now, name),
                        subtitle: subtitle ?? formatLongDate(now),
                        wide: wide,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            tags ??
                            [
                              HeaderTag(
                                icon: Icons.emoji_events_outlined,
                                label:
                                    'Season ${Season.label(settings?.season ?? Season.current)}',
                              ),
                              if (settings != null) ...[
                                HeaderTag(
                                  open: settings.teamRegistrationOpen,
                                  label: settings.teamRegistrationOpen
                                      ? 'Teams open'
                                      : 'Teams closed',
                                ),
                                HeaderTag(
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

/// "Good morning, Isaac" and the line under it, with the club's crest on
/// the left when there is one (the team's Home).
class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.crest,
    required this.greeting,
    required this.subtitle,
    required this.wide,
  });

  final Widget? crest;
  final String greeting;
  final String subtitle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: TextStyle(
              color: Colors.white,
              fontSize: crest == null ? (wide ? 28 : 23) : (wide ? 26 : 21),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
    if (crest == null) return text;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: crest,
          ),
          const SizedBox(width: 12),
          Expanded(child: text),
        ],
      ),
    );
  }
}

/// A see-through pill in the header: an icon, or a green (open) or red
/// (closed) dot, or just the text.
class HeaderTag extends StatelessWidget {
  const HeaderTag({super.key, required this.label, this.icon, this.open});

  final String label;
  final IconData? icon;

  /// true = green dot, false = red dot (registration, team status); with
  /// no [icon] and no [open], only the text.
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
          else if (open != null)
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
          if (icon != null || open != null) const SizedBox(width: 6),
          // A long tag on a small phone ends in "…" (TDa)
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
