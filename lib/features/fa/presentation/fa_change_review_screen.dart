import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/fa_changes_view.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/change_status_note.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// FA › Teams › Changes › one change (2.10b, board P5): what the team has
/// now, what it asks for and why, the app's name check, then Approve or
/// Not approve (with a reason the team will see).
class FaChangeReviewScreen extends ConsumerWidget {
  const FaChangeReviewScreen({super.key, required this.changeId});

  final String changeId;

  /// "Name change", "New logo", "Add Juvenile"…
  static String titleFor(TeamChange? change) => switch (change) {
        null => 'Change request',
        TeamChange(kind: TeamChangeKind.competition) =>
          'Add ${change.competition?.label ?? change.to}',
        _ => change.kind.title,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final changeAsync = ref.watch(teamChangeProvider(changeId));
    final change = changeAsync.value;
    final team = change == null
        ? null
        : ref.watch(teamByIdProvider(change.teamId)).value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: titleFor(change),
        subtitle: team?.name ?? change?.teamName,
        leading: BackButton(onPressed: () => context.go(Routes.adminChanges)),
      ),
      bottomNavigationBar: change != null && change.isPending
          ? _Actions(change: change, team: team)
          : null,
      body: changeAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: appErrorMessage(error),
          onRetry: () => ref.invalidate(teamChangeProvider(changeId)),
        ),
        data: (change) => change == null
            ? const EmptyView(
                icon: Icons.inbox_outlined,
                title: 'Not found',
                message: 'This change request no longer exists.',
              )
            : _Body(change: change, team: team),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.change, required this.team});

  final TeamChange change;
  final Team? team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = change.createdAt;
    final asker = change.askedByName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Already decided (e.g. by another official): what was decided
              if (!change.isPending) ...[
                ChangeStatusNote(change: change),
                const SizedBox(height: 14),
              ],
              _WhatCard(
                change: change,
                team: team,
                askedBy: [
                  asker == null || asker.isEmpty
                      ? 'Team admin'
                      : '$asker (team admin)',
                  if (createdAt != null) formatDayMonthTime(createdAt),
                ].join(' · '),
              ),
              if (change.kind == TeamChangeKind.name && change.isPending) ...[
                const SizedBox(height: 14),
                _NameCheck(change: change),
              ],
              const SizedBox(height: 14),
              _InfoBox(text: _whatApprovingDoes(change)),
            ],
          ),
        ),
      ],
    );
  }

  static String _whatApprovingDoes(TeamChange change) => switch (change.kind) {
        TeamChangeKind.name => 'Approving renames the club everywhere at '
            'once: squad, fixtures, team sheets and the website. Players '
            'keep their IDs.',
        TeamChangeKind.shortName => 'Approving changes the short name '
            'everywhere at once: fixtures, team sheets and the website.',
        TeamChangeKind.logo => 'Approving puts the new logo everywhere at '
            'once: fixtures, team sheets and the website.',
        TeamChangeKind.competition =>
          change.competition == Competition.division
              ? 'Approving adds Division. The club keeps its kits as its '
                  'Juvenile kits (and for Division until it changes them), '
                  'then adds Division players. The season fee stays the '
                  'same.'
              : 'Approving adds Juvenile (U13, U15 and U17). The club then '
                  'adds Juvenile kits and children for screening. The '
                  'season fee stays the same.',
      };
}

/// Now (crossed out) → Asked for, then Why and who asked.
class _WhatCard extends StatelessWidget {
  const _WhatCard({
    required this.change,
    required this.team,
    required this.askedBy,
  });

  final TeamChange change;
  final Team? team;
  final String askedBy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final label =
        textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final initials = initialsFor(team?.name ?? change.teamName);
    final logoColor = team?.logoColor ?? scheme.primary;

    final Widget now;
    final Widget askedFor;
    switch (change.kind) {
      case TeamChangeKind.logo:
        now = Align(
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: 0.6,
            child: TeamLogo(
              label: initials,
              color: logoColor,
              url: change.from,
              size: 56,
            ),
          ),
        );
        askedFor = Align(
          alignment: Alignment.centerLeft,
          child: TeamLogo(
            label: initials,
            color: logoColor,
            url: change.to,
            size: 96,
          ),
        );
      case TeamChangeKind.competition:
        final added = change.competition;
        now = _Crossed(competitionsText(change.fromCompetitions));
        askedFor = _Big(
          competitionsText({...change.fromCompetitions, ?added}),
        );
      case TeamChangeKind.name:
      case TeamChangeKind.shortName:
        now = _Crossed(change.from ?? '');
        askedFor = _Big(change.to);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Now', style: label),
          const SizedBox(height: 4),
          now,
          const SizedBox(height: 14),
          Text('Asked for', style: label),
          const SizedBox(height: 4),
          askedFor,
          const SizedBox(height: 14),
          Divider(height: 1, color: scheme.outline),
          const SizedBox(height: 14),
          Text('Why', style: label),
          const SizedBox(height: 4),
          Text('"${change.reason}"', style: textTheme.bodyLarge),
          const SizedBox(height: 4),
          Text(
            askedBy,
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Crossed extends StatelessWidget {
  const _Crossed(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
          ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text.rich(
        TextSpan(children: [
          const TextSpan(
            text: 'Checked by the app: ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text),
        ]),
        style: textTheme.bodyMedium?.copyWith(color: ink),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Approve / Not approve ────────────────────────────────────────────────

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.change, required this.team});

  final TeamChange change;
  final Team? team;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _busy = false;

  TeamChange get _change => widget.change;
  String get _teamName => widget.team?.name ?? _change.teamName;
  String? get _faUid => ref.read(authRepositoryProvider).currentUser?.uid;

  String get _approveLabel => switch (_change.kind) {
        TeamChangeKind.name => 'Approve the new name',
        TeamChangeKind.shortName => 'Approve the short name',
        TeamChangeKind.logo => 'Approve the new logo',
        TeamChangeKind.competition =>
          'Approve ${_change.competition?.label ?? 'it'}',
      };

  /// Friendly message when Firestore refuses the change.
  String _messageFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return "Couldn't save. Another official may have decided already, or "
          'the team changed something. Go back and open it again.';
    }
    return appErrorMessage(error);
  }

  void _done(String message) {
    AppToast.success(context, message);
    context.go(Routes.adminChanges);
  }

  Future<void> _approve() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$_approveLabel?'),
        content: Text(switch (_change.kind) {
          TeamChangeKind.name =>
            '$_teamName becomes ${_change.to} everywhere at once.',
          TeamChangeKind.shortName =>
            "$_teamName's short name becomes ${_change.to}.",
          TeamChangeKind.logo => '$_teamName gets the new logo everywhere.',
          TeamChangeKind.competition =>
            '$_teamName will play ${_change.competition?.label} too.',
        }),
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
    final faUid = _faUid;
    if (ok != true || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(teamChangeRepositoryProvider)
          .approve(_change, faUid: faUid);
      if (mounted) _done('Approved. $_teamName has been told.');
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refuse() async {
    final reason = await showReasonSheet(
      context,
      title: 'Not approve this change?',
      message: 'The team will see your reason on its team page and can ask '
          'again.',
      fieldLabel: 'Reason for the team',
      sendLabel: 'Send',
      quickEnding: 'You can ask again.',
      quickReasons: switch (_change.kind) {
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
      },
    );
    final faUid = _faUid;
    if (reason == null || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(teamChangeRepositoryProvider)
          .refuse(_change, reason: reason, faUid: faUid);
      if (mounted) _done('Not approved. $_teamName can see your reason.');
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A name another club holds can't be approved (the rules agree)
    final taken = _change.kind == TeamChangeKind.name &&
        (ref
                .watch(nameCheckProvider(
                  (teamId: _change.teamId, name: _change.to),
                ))
                .value
                ?.taken ??
            false);

    return ReviewActionsBar(
      rejectLabel: 'Not approve',
      approveLabel: _approveLabel,
      busy: _busy,
      onReject: _refuse,
      onApprove: taken ? null : _approve,
      blockedText: taken ? 'Another club holds this name.' : null,
    );
  }
}
