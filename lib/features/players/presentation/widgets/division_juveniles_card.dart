import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/players/data/division_juveniles_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/division_juveniles.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Squad tab, Division (3.1d1, mockup DJ1): the club's juveniles in the
/// Division, up to 7, with the U13 / U15 / U17 counters, Remove on each
/// row and "Add a juvenile" (the picker, DJ2). Only for a club in both
/// competitions.
class DivisionJuvenilesCard extends ConsumerWidget {
  const DivisionJuvenilesCard({
    super.key,
    required this.team,
    required this.players,
  });

  final Team team;

  /// All the club's players (the juveniles are picked from them).
  final List<Player> players;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list =
        ref.watch(myDivisionJuvenilesProvider).value ??
        const DivisionJuveniles();
    final scheme = Theme.of(context).colorScheme;
    final byId = {for (final p in players) p.id: p};
    final named = [for (final id in list.players.keys) ?byId[id]]
      ..sort((a, b) => a.ageGroup!.index.compareTo(b.ageGroup!.index));
    final canEdit = !team.isSuspended;

    Future<void> remove(Player p) async {
      try {
        await ref
            .read(divisionJuvenilesRepositoryProvider)
            .remove(team: team, playerId: p.id);
        if (context.mounted) {
          AppToast.success(
            context,
            '${p.fullName} is off your juveniles in the Division.',
          );
        }
      } catch (e) {
        if (context.mounted) AppToast.error(context, appErrorMessage(e));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionTitle(
          title: 'Juveniles in the Division',
          trailing: '${list.size} of ${DivisionJuveniles.max}',
        ),
        DashboardCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Up to ${DivisionJuveniles.max} of your approved juvenile '
                'players can also play Division matches. They still play '
                'their juvenile matches.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final g in AgeGroup.values.reversed) ...[
                    if (g != AgeGroup.u17) const SizedBox(width: 8),
                    Expanded(
                      child: _Counter(group: g, list: list),
                    ),
                  ],
                ],
              ),
              for (final p in named)
                _NamedRow(
                  player: p,
                  onRemove: canEdit ? () => remove(p) : null,
                ),
              if (named.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'None named yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: canEdit && list.placesLeft > 0
              ? () => showDivisionJuvenilesPicker(
                  context,
                  team: team,
                  players: players,
                )
              : null,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(
            list.placesLeft == 0
                ? 'All ${DivisionJuveniles.max} places taken'
                : 'Add a juvenile (${list.placesLeft} '
                      '${list.placesLeft == 1 ? 'place' : 'places'} left)',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            "Only approved juveniles can be named. The FA sees your list; "
            "changing it doesn't need the FA.",
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// "1 / 1  U13" (gold when full); U17 shows "no limit".
class _Counter extends StatelessWidget {
  const _Counter({required this.group, required this.list});

  final AgeGroup group;
  final DivisionJuveniles list;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final limit = DivisionJuveniles.limitOf(group);
    final full = list.isFull(group);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        border: Border.all(color: dashboardBorder(context)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: '${list.countOf(group)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: full ? AccentTone.gold.foreground(isDark) : null,
              ),
              children: [
                if (limit != null)
                  TextSpan(
                    text: ' / $limit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            limit == null ? '${group.label} · no limit' : group.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// One named juvenile: photo, number, name, position · ID, the age pill,
/// and Remove.
class _NamedRow extends StatelessWidget {
  const _NamedRow({required this.player, required this.onRemove});

  final Player player;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: JuvenileLine(player: player)),
          if (onRemove != null)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 40),
                foregroundColor: AccentTone.red.foreground(isDark),
              ),
              onPressed: onRemove,
              child: const Text('Remove'),
            ),
        ],
      ),
    );
  }
}

/// Photo, number, name, and "ST · GJ26-0109 [U17]" (DJ1, DJ2).
class JuvenileLine extends StatelessWidget {
  const JuvenileLine({super.key, required this.player, this.extra});

  final Player player;

  /// A chip after the age pill, e.g. "U15 limit reached".
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        PlayerAvatar(name: p.fullName, url: p.thumbUrl, size: 36),
        SizedBox(
          width: 32,
          child: Text(
            '${p.jerseyNo}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.fullName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 5,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${p.position.code} · ${p.playerCode ?? ''}',
                    style: TextStyle(fontSize: 10.5, color: muted),
                  ),
                  if (p.ageGroup case final g?)
                    FixtureTag(g.label, tone: AccentTone.violet),
                  ?extra,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The picker (DJ2): the club's approved juveniles by age group, oldest
/// first; Add names one, a full group greys the rest. Stays open, so the
/// team can name several.
Future<void> showDivisionJuvenilesPicker(
  BuildContext context, {
  required Team team,
  required List<Player> players,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _Picker(team: team, players: players),
  );
}

class _Picker extends ConsumerStatefulWidget {
  const _Picker({required this.team, required this.players});

  final Team team;
  final List<Player> players;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  /// The player being added (a spinner on their row).
  String? _busyId;

  Future<void> _add(Player p, DivisionJuveniles list) async {
    setState(() => _busyId = p.id);
    try {
      await ref
          .read(divisionJuvenilesRepositoryProvider)
          .add(team: widget.team, player: p, current: list);
      if (mounted) {
        AppToast.success(
          context,
          '${p.fullName} can now play Division matches.',
        );
      }
    } on DivisionJuvenileException catch (e) {
      if (mounted) AppToast.warning(context, e.message);
    } catch (e) {
      if (mounted) AppToast.error(context, appErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list =
        ref.watch(myDivisionJuvenilesProvider).value ??
        const DivisionJuveniles();
    final scheme = Theme.of(context).colorScheme;
    final approved = [
      for (final p in widget.players)
        if (p.isJuvenile && p.isApproved && p.ageGroup != null) p,
    ]..sort((a, b) => a.jerseyNo.compareTo(b.jerseyNo));

    Widget trailing(Player p) {
      if (_busyId == p.id) {
        return const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      if (list.contains(p.id)) {
        return const FixtureTag('✓ Named', tone: AccentTone.green);
      }
      if (list.whyNot(p) != null) {
        return Icon(Icons.lock_outline, color: scheme.onSurfaceVariant);
      }
      return ActionChip(
        avatar: const Icon(Icons.add, size: 16),
        label: const Text('Add'),
        onPressed: _busyId == null ? () => _add(p, list) : null,
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Add a juvenile to the Division',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '${list.placesLeft} '
              '${list.placesLeft == 1 ? 'place' : 'places'} left · at most '
              '1 U13 and 3 U15',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            if (approved.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No approved juvenile players yet. They are approved at '
                  'the screening day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            for (final g in AgeGroup.values.reversed)
              if (approved.where((p) => p.ageGroup == g).toList()
                  case final group when group.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        DivisionJuveniles.limitOf(g) == null
                            ? 'no limit'
                            : '${list.countOf(g)} of '
                                  '${DivisionJuveniles.limitOf(g)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                DashboardCard(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  child: Column(
                    children: [
                      for (final p in group)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Opacity(
                            opacity:
                                !list.contains(p.id) && list.whyNot(p) != null
                                ? .55
                                : 1,
                            child: Row(
                              children: [
                                Expanded(
                                  child: JuvenileLine(
                                    player: p,
                                    extra:
                                        !list.contains(p.id) && list.isFull(g)
                                        ? FixtureTag(
                                            '${g.label} limit reached',
                                            tone: AccentTone.gold,
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                trailing(p),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
