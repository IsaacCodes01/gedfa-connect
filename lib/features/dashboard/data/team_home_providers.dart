import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/features/dashboard/domain/team_home.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// The Division | Juvenile switch (TDa; the Fixtures tab uses it too in
/// TDc). The phone remembers the last choice, like the theme.
class MatchViewNotifier extends Notifier<MatchView> {
  static const _competitionKey = 'matchView.competition';
  static const _ageGroupKey = 'matchView.ageGroup';

  @override
  MatchView build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(_competitionKey);
    return MatchView(
      competition: Competition.values.where((c) => c.name == saved).firstOrNull,
      ageGroup: AgeGroup.fromString(prefs.getString(_ageGroupKey)),
    );
  }

  /// Picks Division or Juvenile. Juvenile starts on "All" age groups.
  void setCompetition(Competition competition) {
    if (competition == state.competition) return;
    _save(MatchView(competition: competition));
  }

  /// Juvenile: one age group, or null for all of them.
  void setAgeGroup(AgeGroup? group) =>
      _save(MatchView(competition: Competition.juvenile, ageGroup: group));

  void _save(MatchView view) {
    state = view;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_competitionKey, view.competition!.name);
    final group = view.ageGroup;
    if (group == null) {
      prefs.remove(_ageGroupKey);
    } else {
      prefs.setString(_ageGroupKey, group.label);
    }
  }
}

final matchViewProvider = NotifierProvider<MatchViewNotifier, MatchView>(
  MatchViewNotifier.new,
);
