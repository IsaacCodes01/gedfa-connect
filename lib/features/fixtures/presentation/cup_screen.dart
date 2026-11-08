import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_changes.dart';
import 'package:gedfa_connect/features/fixtures/domain/cup_format.dart';
import 'package:go_router/go_router.dart';

/// FA: a cup's page before the draw (3.0c1b, mockup C7): what the first
/// draw is, how the cup is played (with Change) and its history. The ⋯
/// menu (C8) has Change, History and Delete (C9). After the draw (3.0c2)
/// this page becomes the bracket.
class CupScreen extends ConsumerStatefulWidget {
  const CupScreen({super.key, required this.cupId});

  final String cupId;

  @override
  ConsumerState<CupScreen> createState() => _CupScreenState();
}

class _CupScreenState extends ConsumerState<CupScreen> {
  /// "History" in the ⋯ menu scrolls here.
  final _historyKey = GlobalKey();
  bool _deleting = false;

  void _change(Cup cup) {
    if (cup.stage != CupStage.notDrawn) {
      AppToast.info(context, 'It is drawn, so it can no longer be changed.');
      return;
    }
    context.push(Routes.adminEditCup(cup.id));
  }

  void _showHistory() {
    final target = _historyKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _delete(Cup cup) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Delete ${cup.name}?'),
        content: Text(
          cup.stage == CupStage.notDrawn
              ? "It isn't drawn yet, so no club has been told about it. Its "
                    "history goes too. This can't be undone."
              : "Its matches and its history go too. The clubs are told. "
                    "This can't be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialog).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(cupRepositoryProvider).delete(cup.id);
      if (!mounted) return;
      AppToast.success(context, '${cup.name} deleted.');
      context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _deleting = false);
        AppToast.error(context, appErrorMessage(error));
      }
    }
  }

  void _showMenu(Cup cup) {
    final drawn = cup.stage != CupStage.notDrawn;
    final error = Theme.of(context).colorScheme.error;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(
                'Change',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'The same form, filled in. Only before the draw',
              ),
              enabled: !drawn,
              onTap: () {
                Navigator.pop(sheet);
                _change(cup);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text(
                'History',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Every change, who and when'),
              onTap: () {
                Navigator.pop(sheet);
                _showHistory();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text(
                cup.isGala ? 'Delete the Gala' : 'Delete the cup',
                style: TextStyle(fontWeight: FontWeight.w600, color: error),
              ),
              subtitle: const Text('Everything goes: matches and history'),
              onTap: () {
                Navigator.pop(sheet);
                _delete(cup);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cupAsync = ref.watch(cupProvider(widget.cupId));
    final cup = cupAsync.value;

    Widget body;
    if (cupAsync.hasError && cup == null) {
      body = ErrorView(
        message: appErrorMessage(cupAsync.error!),
        onRetry: () => ref.invalidate(cupProvider(widget.cupId)),
      );
    } else if (cup == null) {
      body = cupAsync.isLoading || _deleting
          ? const LoadingView()
          : const EmptyView(
              icon: Icons.emoji_events_outlined,
              title: 'Not here',
              message: 'This cup was deleted.',
            );
    } else {
      body = ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _DrawBox(cup: cup),
            DashboardSectionTitle(
              title: "How it's played",
              trailing: 'Change',
              onTap: () => _change(cup),
            ),
            _HowItsPlayed(cup: cup),
            DashboardSectionTitle(
              key: _historyKey,
              title: 'History',
              trailing: 'Newest first',
            ),
            _History(cupId: cup.id),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: cup?.name ?? 'Cup',
        subtitle: cup == null
            ? 'Competitions'
            : [
                cup.kind.label,
                '${cup.entries.length} teams',
                if (cup.stage == CupStage.notDrawn) 'not drawn yet',
              ].join(' · '),
        leading: const BackButton(),
        actions: [
          if (cup != null && !_deleting)
            IconButton(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMenu(cup),
            ),
        ],
      ),
      body: body,
    );
  }
}

/// "Ready for the first draw · First round · 2 matches · 14 byes" with
/// "Go to the draw" (the live draw is 3.0c2).
class _DrawBox extends StatelessWidget {
  const _DrawBox({required this.cup});

  final Cup cup;

  /// What the first draw makes.
  static String _firstDraw(Cup cup) {
    final n = cup.entries.length;
    if (n < 2) return '$n teams';
    if (cup.format == CupFormat.groups) {
      final groups = GroupPlan.forTeams(n);
      if (groups != null) {
        return '${groups.groups} groups · ${groups.sizes.join(', ')} teams';
      }
    }
    final plan = KnockoutPlan(n);
    final first = plan.rounds.first;
    return [
      first.name,
      '${first.ties} ${first.ties == 1 ? 'match' : 'matches'}',
      if (plan.byes > 0) '${plan.byes} byes',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A5E00), Color(0xFF2B2200)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.emoji_events, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            cup.isGala ? 'Ready for the draw' : 'Ready for the first draw',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          Text(
            _firstDraw(cup),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFCD116),
              foregroundColor: const Color(0xFF3A2C00),
            ),
            onPressed: () =>
                AppToast.info(context, 'The live draw comes next.'),
            child: const Text('Go to the draw'),
          ),
        ],
      ),
    );
  }
}

/// Who plays, the format, the level rule and the draw (C7).
class _HowItsPlayed extends StatelessWidget {
  const _HowItsPlayed({required this.cup});

  final Cup cup;

  @override
  Widget build(BuildContext context) {
    final n = cup.entries.length;
    final who = switch (cup.who) {
      CupWho.division => 'Division · $n teams',
      CupWho.juvenile => '${cup.whoLabel} · $n teams',
      CupWho.open =>
        'Open: Division and ${cup.ageGroup?.label ?? 'juvenile'} sides · '
            '$n teams',
    };
    final rounds = cup.isGala
        ? 'One match per tie'
        : cup.legs == 2
        ? 'Home and away; the final one match'
        : 'One match each round';
    final draw = [
      if (cup.format == CupFormat.groups)
        'Groups drawn at random'
      else if (cup.bracketFrom == 0)
        'Whole draw at once'
      else
        'Bracket fixed from the ${bracketFromLabel(cup.bracketFrom)}',
      cup.seeded ? 'seeded with pots' : 'no seeding',
    ].join(' · ');

    return DashboardCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _Line(icon: Icons.groups_outlined, title: 'Who plays', text: who),
          _Line(
            icon: Icons.account_tree_outlined,
            title: formatLabel(cup),
            text: rounds,
          ),
          if (cup.gala case final gala?)
            _Line(
              icon: Icons.stadium_outlined,
              title: 'Where and when',
              text:
                  '${gala.ground} · ${galaDays(gala)} · first kick-off '
                  '${galaKickoff(gala)} · every ${gala.gapMinutes} min',
            ),
          _Line(
            icon: Icons.sports_outlined,
            title: cup.isGala ? 'Level at full time' : 'Level at the end',
            text: cup.level.label,
          ),
          _Line(icon: Icons.shuffle, title: 'The draw', text: draw),
        ],
      ),
    );
  }
}

/// The cup's history, newest first, with who and when (C7).
class _History extends ConsumerWidget {
  const _History({required this.cupId});

  final String cupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(cupHistoryProvider(cupId));
    return historyAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(message: appErrorMessage(error)),
      data: (lines) => DashboardCard(
        padding: lines.isEmpty ? const EdgeInsets.all(14) : EdgeInsets.zero,
        child: lines.isEmpty
            ? const Text('No history yet.')
            : Column(
                children: [
                  for (final line in lines)
                    _Line(
                      icon: line.text.endsWith(' made')
                          ? Icons.add_circle_outline
                          : Icons.edit_note,
                      title: line.text,
                      text: [
                        line.byName,
                        if (line.at case final at?)
                          '${formatShortDate(at)}, ${formatTime(at)}',
                      ].join(' · '),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
