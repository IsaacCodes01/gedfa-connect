import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_banner.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/app/router.dart';

class GedfaApp extends ConsumerWidget {
  const GedfaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // The season, fee and MoMo number come from the FA's league settings
    // (2.13d). They change rarely (the chairman, once a season), so the
    // whole app simply rebuilds with the new values.
    final league = ref.watch(leagueSettingsProvider).value;
    if (league != null) {
      Season.apply(
        season: league.season,
        fee: league.fee,
        momoNumber: league.momoNumber,
      );
    }

    return MaterialApp.router(
      title: 'GEDFA Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => ConnectivityBanner(
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}