import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/fa_changes_view.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/rename_matches.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/b_side_ring.dart';
import 'package:gedfa_connect/features/teams/domain/side_name.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';

/// FA › Teams › Changes › one team (2.10c, mockup C): everything the team
/// asked for, one card each (newest first). Each change is approved or
/// rejected on its own card; a decided one shrinks to one line and stays
/// until every change is decided, then the FA goes back to Changes.
class FaTeamChangesScreen extends ConsumerStatefulWidget {
  const FaTeamChangesScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<FaTeamChangesScreen> createState() =>
      _FaTeamChangesScreenState();
}

class _FaTeamChangesScreenState extends ConsumerState<FaTeamChangesScreen> {
  /// Decided on this screen (shown as one line)
  final _decidedHere = <String>{};

  /// The change being saved (its buttons spin; the others wait)
  String? _busyId;

  /// "Approve all" is running
  bool _busyAll = false;

  bool get _busy => _busyId != null || _busyAll;

  String? get _faUid => ref.read(authRepositoryProvider).currentUser?.uid;

  void _back() => context.goBack(Routes.adminChanges);

  /// Friendly message when Firestore refuses the change.
  String _messageFor(Object error) {
    if (error is RenameStoppedException) return error.message;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return "Couldn't save. Another official may have decided already, or "
          'the team changed something. Go back and open it again.';
    }
    return appErrorMessage(error);
  }

  /// Saves one decision; when it was the last one waiting, back to Changes.
  Future<void> _decide(
    TeamChange change,
    List<TeamChange> waiting,
    Future<void> Function(String faUid) save,
    String teamName,
  ) async {
    final faUid = _faUid;
    if (faUid == null) return;

    setState(() => _busyId = change.id);
    try {
      await save(faUid);
      if (!mounted) return;
      setState(() => _decidedHere.add(change.id));
      if (waiting.every((c) => c.id == change.id)) {
        AppToast.success(context, 'All done. $teamName has been told.');
        _back();
      }
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(
    TeamChange change,
    List<TeamChange> waiting,
    String teamName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${_approveLabel(change)}?'),
        content: Text(
          _whatApprovingDoes(change, teamName) + _matchesLine(change),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: approveGreen(dialogContext),
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _decide(change, waiting, (faUid) async {
      await ref
          .read(teamChangeRepositoryProvider)
          .approve(change, faUid: faUid);
      // JSc2: every match of the team shows the new name
      if (_renamesMatches(change) && mounted) {
        await renameTeamMatches(
          context,
          ref,
          teamId: change.teamId,
          newName: _newNameOf(change, teamName),
        );
      }
    }, teamName);
  }

  /// A new club name, short name or juvenile side name changes the
  /// team's matches (JSc2).
  static bool _renamesMatches(TeamChange change) => const {
    TeamChangeKind.name,
    TeamChangeKind.shortName,
    TeamChangeKind.juvenileName,
  }.contains(change.kind);

  /// "Royal Stars FC" (for the renaming dialog)
  static String _newNameOf(TeamChange change, String teamName) =>
      switch (change.kind) {
        TeamChangeKind.name => change.to,
        TeamChangeKind.juvenileName =>
          change.isBackToB ? '$teamName B' : change.to,
        _ => teamName,
      };

  /// The Approve dialog's second paragraph (mockup R4): how many matches
  /// change, with "Previously …" for a new name.
  String _matchesLine(TeamChange change) {
    final team = ref.read(teamByIdProvider(change.teamId)).value;
    if (team == null || !_renamesMatches(change)) return '';
    final now = DateTime.now();
    final season = ref.read(seasonFixturesProvider).value ?? const [];
    // The matches showing the name that changes: the club's own name
    // (and its "B" side), or the juvenile side's name
    final matches = [
      for (final f in season)
        for (final side in [f.home, f.away])
          if (side.id == team.id &&
              switch (change.kind) {
                TeamChangeKind.juvenileName =>
                  f.category == Competition.juvenile,
                TeamChangeKind.name =>
                  f.category == Competition.division ||
                      team.juvenileName == null,
                _ => true,
              })
            f,
    ];
    if (matches.isEmpty) return '';
    final played = matches.where((f) => f.isPlayed(now)).length;
    final count = matches.length == 1 ? '1 match' : '${matches.length} matches';
    if (change.kind == TeamChangeKind.shortName) {
      return '\n\n$count show the new short name on the crest.';
    }
    final old = change.kind == TeamChangeKind.juvenileName
        ? team.sideName(Competition.juvenile)
        : team.name;
    return '\n\n$count ($played played) show the new name, with '
        '"Previously $old" for everyone.';
  }

  /// Approve all: one change after another, oldest first. Each is its own
  /// batch (the rules allow one kind of change per team update), with its
  /// own bell note. A name another club holds is skipped.
  Future<void> _approveAll(List<TeamChange> waiting, String teamName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Approve all ${waiting.length} changes for $teamName?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final change in waiting)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '•  '),
                    asksText(change),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            const Text('Each one is used everywhere at once. Players keep '
                'their IDs.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: approveGreen(dialogContext),
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve all'),
          ),
        ],
      ),
    );
    final faUid = _faUid;
    if (ok != true || faUid == null || !mounted) return;

    final repository = ref.read(teamChangeRepositoryProvider);
    final oldestFirst = waiting.reversed.toList();
    var approved = 0;
    var skipped = 0;
    setState(() => _busyAll = true);
    try {
      for (final change in oldestFirst) {
        try {
          await repository.approve(change, faUid: faUid);
          approved++;
          if (mounted) setState(() => _decidedHere.add(change.id));
        } on TeamNameTakenException {
          skipped++;
        }
      }
      // JSc2: one renaming for all of them (to the team's names now)
      if (oldestFirst.any(
            (c) => _decidedHere.contains(c.id) && _renamesMatches(c),
          ) &&
          mounted) {
        await renameTeamMatches(
          context,
          ref,
          teamId: widget.teamId,
          newName: ref.read(teamByIdProvider(widget.teamId)).value?.name ??
              teamName,
        );
      }
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
      return;
    } finally {
      if (mounted) setState(() => _busyAll = false);
    }
    if (!mounted) return;

    final done = approved == 1 ? '1 change approved' : '$approved changes approved';
    if (skipped == 0) {
      AppToast.success(context, '$done. $teamName has been told.');
      _back();
    } else {
      // The skipped name stays here, for the FA to reject
      AppToast.warning(
        context,
        '$done. The new name was skipped: another club holds it.',
      );
    }
  }

  /// Reject: a box to type the reason, sent to the team.
  Future<void> _reject(
    TeamChange change,
    List<TeamChange> waiting,
    String teamName,
  ) async {
    final reason = await showReasonSheet(
      context,
      title: 'Reject this change?',
      message: 'Type the reason. $teamName sees it on its team page and can '
          'ask again.',
      fieldLabel: 'Reason for the team',
      sendLabel: 'Send to the team',
      quickEnding: 'You can ask again.',
      quickReasons: switch (change.kind) {
        TeamChangeKind.name => const [
            "Too close to another club's name",
            'Please send a letter from the club executives',
            'Please explain why the name is changing',
          ],
        TeamChangeKind.shortName => const [
            'Another club uses a similar short name',
            'The short name does not match the club name',
          ],
        TeamChangeKind.logo => const [
            'The logo is not clear',
            "The logo is too close to another club's badge",
          ],
        TeamChangeKind.competition => const [
            'Registration for this competition is closed',
            'Please talk to the FA first',
          ],
        TeamChangeKind.juvenileName => const [
            "Too close to another club's name",
            'Please talk to the FA first',
          ],
      },
    );
    if (reason == null || !mounted) return;
    await _decide(
      change,
      waiting,
      (faUid) => ref
          .read(teamChangeRepositoryProvider)
          .refuse(change, reason: reason, faUid: faUid),
      teamName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final changesAsync = ref.watch(allTeamChangesProvider);
    final team = ref.watch(teamByIdProvider(widget.teamId)).value;

    // Newest first, like the list on the Changes card
    final mine = (changesAsync.value ?? const <TeamChange>[])
        .where((c) =>
            c.teamId == widget.teamId &&
            (c.isPending || _decidedHere.contains(c.id)))
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
    final waiting = mine.where((c) => c.isPending).toList();
    final teamName = team?.name ?? mine.firstOrNull?.teamName ?? '';

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Changes',
          subtitle: teamName.isEmpty
              ? null
              : '$teamName · ${waiting.length} waiting',
          leading: BackButton(onPressed: _busy ? null : _back),
        ),
        // Approve all, when two or more are waiting
        bottomNavigationBar: waiting.length < 2
            ? null
            : _ApproveAllBar(
                count: waiting.length,
                busy: _busyAll,
                onPressed:
                    _busy ? null : () => _approveAll(waiting, teamName),
              ),
        body: changesAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: appErrorMessage(error),
            onRetry: () => ref.invalidate(allTeamChangesProvider),
          ),
          data: (_) => mine.isEmpty
              ? const EmptyView(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing waiting',
                  message: 'This team has no changes waiting for the FA.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    ResponsiveCenter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final change in mine) ...[
                            if (change.isPending)
                              _ChangeCard(
                                change: change,
                                team: team,
                                busy: _busyId == change.id,
                                enabled: !_busy,
                                approveLabel: _approveLabel(change),
                                onApprove: () =>
                                    _approve(change, waiting, teamName),
                                onReject: () =>
                                    _reject(change, waiting, teamName),
                              )
                            else
                              _DecidedHereLine(change: change),
                            const SizedBox(height: 12),
                          ],
                          const _InfoBox(
                            text: 'Each change is decided on its own. '
                                'Approving a name renames the club everywhere '
                                'at once; players keep their IDs.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static String _approveLabel(TeamChange change) => switch (change.kind) {
        TeamChangeKind.name => 'Approve the new name',
        TeamChangeKind.shortName => 'Approve the short name',
        TeamChangeKind.logo => 'Approve the logo',
        TeamChangeKind.competition =>
          'Approve ${change.competition?.label ?? 'it'}',
        TeamChangeKind.juvenileName => 'Approve the name',
      };

  /// In the confirm dialog: exactly what approving does.
  static String _whatApprovingDoes(TeamChange change, String teamName) =>
      switch (change.kind) {
        TeamChangeKind.name => '$teamName becomes ${change.to} everywhere at '
            'once: squad, fixtures, team sheets and the website. Players keep '
            'their IDs.',
        TeamChangeKind.shortName => "$teamName's short name becomes "
            '${change.to} everywhere.',
        TeamChangeKind.logo => '$teamName gets the new logo everywhere.',
        TeamChangeKind.competition =>
          change.competition == Competition.division
              ? '$teamName will play Division too. Its kits are kept as its '
                  'Juvenile kits (and used for Division until it changes '
                  'them). The season fee stays the same.'
              : '$teamName will play Juvenile (U13, U15 and U17) too, as '
                  '${change.juvenileName ?? '$teamName B'}. It then adds '
                  'Juvenile kits and children for screening. The season fee '
                  'stays the same.',
        TeamChangeKind.juvenileName => change.isBackToB
            ? "$teamName's juvenile sides (U13, U15 and U17) play as "
                  '$teamName B again.'
            : "$teamName's juvenile sides (U13, U15 and U17) play as "
                  '${change.to} (${change.toShortName}). The name is kept for '
                  'the club.',
      };
}

/// One waiting change (mockup C): what, when, Now → Asked for, Why, the
/// app's name check, then Reject / Approve.
class _ChangeCard extends ConsumerWidget {
  const _ChangeCard({
    required this.change,
    required this.team,
    required this.busy,
    required this.enabled,
    required this.approveLabel,
    required this.onApprove,
    required this.onReject,
  });

  final TeamChange change;
  final Team? team;
  final bool busy;
  final bool enabled;
  final String approveLabel;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String get _title => change.kind == TeamChangeKind.competition
      ? 'Add ${change.competition?.label ?? change.to}'
      : change.kind.title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final label =
        textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final createdAt = change.createdAt;
    final asker = change.askedByName;

    // A name another club holds can't be approved (the rules agree)
    final isName = change.kind == TeamChangeKind.name;
    final taken = isName &&
        (ref
                .watch(nameCheckProvider(
                  (teamId: change.teamId, name: change.to),
                ))
                .value
                ?.taken ??
            false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (createdAt != null)
                Text(formatDayMonthTime(createdAt), style: label),
            ],
          ),
          const SizedBox(height: 10),
          _NowAndAskedFor(change: change, team: team),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: 12),
          Text('Why', style: label),
          const SizedBox(height: 2),
          Text(
            change.reason.isEmpty ? 'No reason given' : '"${change.reason}"',
            style: change.reason.isEmpty
                ? textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)
                : textTheme.bodyLarge,
          ),
          Text(
            asker == null || asker.isEmpty
                ? 'Team admin'
                : '$asker (team admin)',
            style: label,
          ),
          if (isName) ...[
            const SizedBox(height: 12),
            _NameCheck(change: change),
          ],
          if (taken) ...[
            const SizedBox(height: 10),
            Text(
              'Another club holds this name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? onReject : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error, width: 1.5),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: enabled && !taken ? onApprove : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: approveGreen(context),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        approveGreen(context).withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(approveLabel, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Now (crossed out) and Asked for. A logo: the two side by side.
class _NowAndAskedFor extends StatelessWidget {
  const _NowAndAskedFor({required this.change, required this.team});

  final TeamChange change;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final label =
        textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    if (change.kind == TeamChangeKind.logo) {
      final initials = initialsFor(team?.name ?? change.teamName);
      final color = team?.logoColor ?? scheme.primary;
      return Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Now', style: label),
              const SizedBox(height: 4),
              Opacity(
                opacity: 0.6,
                child: TeamLogo(
                  label: initials,
                  color: color,
                  url: change.from,
                  size: 52,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Asked for', style: label),
              const SizedBox(height: 4),
              TeamLogo(label: initials, color: color, url: change.to, size: 76),
            ],
          ),
        ],
      );
    }

    // The juvenile side's name (mockup JS4): crest and name, then the new
    if (change.kind == TeamChangeKind.juvenileName) {
      return _JuvenileNameChange(change: change, team: team);
    }

    final (now, askedFor) = switch (change.kind) {
      TeamChangeKind.competition => (
          competitionsText(change.fromCompetitions),
          competitionsText({...change.fromCompetitions, ?change.competition}),
        ),
      _ => (change.from ?? '', change.to),
    };
    // "Add Juvenile": how its juvenile sides will be called (JSc)
    final juvenileName = change.kind == TeamChangeKind.competition &&
            change.competition == Competition.juvenile
        ? (change.juvenileName == null
            ? '${team?.name ?? change.teamName} B'
            : '${change.juvenileName} · ${change.juvenileShortName}')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Now', style: label),
        Text(
          now,
          style: textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(height: 8),
        Text('Asked for', style: label),
        Text(
          askedFor,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (juvenileName != null) ...[
          const SizedBox(height: 8),
          Text('Juvenile side name', style: label),
          Text(
            juvenileName,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

/// A juvenile side's name (mockup JS4): the crest and name now (a gold
/// ring for "B"), an arrow, then the crest and the name asked for.
class _JuvenileNameChange extends StatelessWidget {
  const _JuvenileNameChange({required this.change, required this.team});

  final TeamChange change;
  final Team? team;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final clubName = team?.name ?? change.teamName;
    final clubShort = team?.shortName ?? '';
    final (toName, toShort) = change.isBackToB
        ? ('$clubName B', '$clubShort B')
        : (change.to, change.toShortName ?? '');

    Widget side(String name, String shortName, {required bool now}) {
      final isB = isBSideShortName(shortName);
      final label = isB
          ? shortName.substring(0, shortName.length - 2)
          : shortName;
      Widget logo(double size) => TeamLogo(
        label: label.isEmpty ? '?' : label,
        color: team?.logoColor ?? scheme.primary,
        url: team?.logoUrl,
        size: size,
      );
      return Column(
        children: [
          isB ? BSideRing(size: 40, builder: logo) : logo(40),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: now
                ? muted
                : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!now && shortName.isNotEmpty)
            Text(shortName, textAlign: TextAlign.center, style: muted),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: side(change.from ?? '', change.fromShortName ?? '', now: true),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Icon(Icons.arrow_forward_rounded, color: scheme.onSurfaceVariant),
        ),
        Expanded(child: side(toName, toShort, now: false)),
      ],
    );
  }
}

/// The green "Approve all (3)" bar at the bottom.
class _ApproveAllBar extends StatelessWidget {
  const _ApproveAllBar({
    required this.count,
    required this.busy,
    required this.onPressed,
  });

  final int count;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // heightFactor: 1, or the bar would fill the screen
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: approveGreen(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      approveGreen(context).withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.done_all_rounded),
                label: Text('Approve all ($count)'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "✓ Name → Golden Unity Stars FC · approved just now" (mockup C2)
class _DecidedHereLine extends StatelessWidget {
  const _DecidedHereLine({required this.change});

  final TeamChange change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final approved = change.status == ApprovalStatus.approved;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(
            approved ? Icons.check_rounded : Icons.close_rounded,
            color: approved ? approveGreen(context) : scheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                asksText(change),
                TextSpan(
                  text: approved
                      ? ' · approved just now'
                      : ' · rejected just now',
                ),
              ]),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Checked by the app": green when the name is free and not close to
/// another team's; gold when it is close; red when another club holds it.
class _NameCheck extends ConsumerWidget {
  const _NameCheck({required this.change});

  final TeamChange change;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final check = ref
        .watch(nameCheckProvider((teamId: change.teamId, name: change.to)))
        .value;
    if (check == null) return const SizedBox.shrink();

    final similarTo = check.similarTo;
    final (Color bg, Color ink, String text) = check.taken
        ? (
            isDark ? const Color(0xFF4A1820) : const Color(0xFFFDE7EA),
            isDark ? const Color(0xFFFF9AA5) : const Color(0xFF8C1022),
            'another club already holds this name. It cannot be approved.',
          )
        : similarTo != null
            ? (
                isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC),
                isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700),
                'this name is very close to $similarTo. Check it is not '
                    'the same club.',
              )
            : (
                isDark ? const Color(0xFF123D2B) : const Color(0xFFE3F2EA),
                isDark ? const Color(0xFF7BE3B0) : const Color(0xFF00502F),
                'no other team uses this name or a very similar one.',
              );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: 'Checked by the app: ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text),
        ]),
        style: textTheme.bodySmall?.copyWith(color: ink),
      ),
    );
  }
}

/// The blue ⓘ box.
class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
