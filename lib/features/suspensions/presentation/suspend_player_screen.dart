import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/data/division_juveniles_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/features/suspensions/presentation/widgets/ban_widgets.dart';

/// SP1 (3.1e1): any FA official suspends a player for a number of
/// matches. Reason, how many matches (1 to 10), a note; before saving, the
/// FA sees from the calendar which matches the player misses and the one
/// they are back for. One batch: the suspension, a mark on each missed
/// match, the note in the club's bell.
class SuspendPlayerScreen extends ConsumerWidget {
  const SuspendPlayerScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProvider(playerId));
    final fixturesAsync = ref.watch(seasonFixturesProvider);
    final player = playerAsync.value;
    final error = playerAsync.error ?? fixturesAsync.error;

    final Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!playerAsync.hasValue || !fixturesAsync.hasValue) {
      body = const LoadingView();
    } else if (player == null || !player.isApproved) {
      body = const EmptyView(
        icon: Icons.person_off_outlined,
        title: 'Only approved players',
        message: 'A player can be suspended once the FA has approved them.',
      );
    } else {
      body = _Form(player: player, fixtures: fixturesAsync.requireValue);
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: player == null ? 'Suspend' : 'Suspend ${player.fullName}',
        subtitle: player == null
            ? null
            : [
                player.teamName,
                player.ageGroup?.label ?? player.category.label,
                ?player.playerCode,
              ].join(' · '),
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.goBack(Routes.adminPlayer(playerId)),
        ),
      ),
      body: body,
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.player, required this.fixtures});

  final Player player;
  final List<Fixture> fixtures;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _reasonText = TextEditingController();
  final _note = TextEditingController();
  BanReason? _reason;
  int _matches = 1;
  BanCompetition? _competition;
  bool _busy = false;

  Player get _player => widget.player;

  @override
  void dispose() {
    _reasonText.dispose();
    _note.dispose();
    super.dispose();
  }

  /// A juvenile's own age group; a Division player's Division.
  BanCompetition get _own => switch (_player.ageGroup) {
    final group? when _player.isJuvenile => BanCompetition.juvenile(group),
    _ => const BanCompetition.division(),
  };

  bool get _canSave =>
      !_busy &&
      _reason != null &&
      (_reason != BanReason.other || _reasonText.text.trim().length >= 3);

  Future<void> _save(
    BanCompetition competition,
    List<Fixture> toMiss,
    Fixture? back,
  ) async {
    final reason = _reason;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (reason == null || user == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(playerSuspensionRepositoryProvider)
          .suspend(
            player: _player,
            competition: competition,
            reason: reason,
            reasonText: _reasonText.text,
            note: _note.text,
            matches: _matches,
            toMiss: toMiss,
            back: back,
            byUid: user.uid,
            byName: user.displayName,
          );
      if (!mounted) return;
      AppToast.success(
        context,
        '${_player.fullName} is suspended. ${_player.teamName} has been told.',
      );
      context.goBack(Routes.adminPlayer(_player.id));
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (redBg, redInk) = banColours(context);
    final inForce = ref.watch(faBansProvider)[_player.id];

    // A juvenile named for the Division: the FA says which competition
    // (Isaac, 11 Nov 2026: only where it was given)
    final named =
        _player.isJuvenile &&
        (ref
                .watch(divisionJuvenilesProvider(_player.teamId))
                .value
                ?.contains(_player.id) ??
            false);
    final competition = named ? (_competition ?? _own) : _own;

    final now = DateTime.now();
    final toMiss = BanPlan.matchesToMiss(
      widget.fixtures,
      teamId: _player.teamId,
      competition: competition,
      count: _matches,
      now: now,
    );
    final back = toMiss.length < _matches
        ? null
        : BanPlan.returnMatch(
            widget.fixtures,
            teamId: _player.teamId,
            competition: competition,
            missed: {for (final f in toMiss) f.id},
            after: toMiss.lastOrNull?.kickoffAt ?? now,
          );
    final notInCalendar = _matches - toMiss.length;
    final gold = isDark ? const Color(0xFFF5D25B) : const Color(0xFF8A6A00);

    Widget chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: redBg,
      labelStyle: TextStyle(
        color: selected ? redInk : scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ResponsiveCenter(
                maxWidth: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inForce != null) ...[
                      BanBanner(status: inForce),
                      const SizedBox(height: 8),
                      const _Hint(
                        'Already suspended: lift this suspension first to '
                        'give a new one.',
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (named) ...[
                      const SectionTitle('Competition'),
                      _Card(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final c in [
                              const BanCompetition.division(),
                              _own,
                            ])
                              chip(
                                c.label,
                                competition == c,
                                () => setState(() => _competition = c),
                              ),
                          ],
                        ),
                      ),
                      const _Hint(
                        'Named for the Division: the suspension applies only '
                        'in the competition where it was given.',
                      ),
                      const SizedBox(height: 18),
                    ],
                    const SectionTitle('Reason'),
                    _Card(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in BanReason.values)
                            chip(
                              r.label,
                              _reason == r,
                              () => setState(() => _reason = r),
                            ),
                        ],
                      ),
                    ),
                    if (_reason == BanReason.other) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonText,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'What for? *',
                          helperText:
                              'The club sees it, e.g. "Abusing the '
                              'referee".',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const SectionTitle('Matches'),
                    _Card(
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: 'One match less',
                            onPressed: _matches > 1
                                ? () => setState(() => _matches--)
                                : null,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$_matches',
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  _matches == 1 ? 'match' : 'matches',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'One match more',
                            onPressed: _matches < PlayerSuspension.maxMatches
                                ? () => setState(() => _matches++)
                                : null,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: SectionTitle('From the calendar'),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            competition.label,
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _Card(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final f in toMiss)
                            _CalendarRow(
                              fixture: f,
                              teamId: _player.teamId,
                              returns: false,
                            ),
                          if (notInCalendar > 0)
                            _CalendarRow.notYet(count: notInCalendar),
                          if (back != null)
                            _CalendarRow(
                              fixture: back,
                              teamId: _player.teamId,
                              returns: true,
                            ),
                        ],
                      ),
                    ),
                    const _Hint(
                      'Only matches that are played count. If one is '
                      "postponed, the ban moves to the club's next match.",
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle('Note (optional)'),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      inputFormatters: [LengthLimitingTextInputFormatter(200)],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            "e.g. Sent off v Nyanyano FC, 14 Nov (referee's "
                            'report)',
                        helperText: 'The club sees it.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // The footer: who is told, and the button
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outline)),
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_rounded, size: 17, color: gold),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'The club is told straight away',
                            style: textTheme.bodySmall?.copyWith(color: gold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _canSave && inForce == null
                          ? () => _save(competition, toMiss, back)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.block_rounded),
                      label: Text(
                        _matches == 1
                            ? 'Suspend for 1 match'
                            : 'Suspend for $_matches matches',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white rounded card (the mockup's `.card`).
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.cardBorder,
        ),
      ),
      child: child,
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// One line of "From the calendar": a match missed (red, "Misses"), the
/// return match (green, "Returns"), or matches not in the calendar yet.
class _CalendarRow extends StatelessWidget {
  const _CalendarRow({
    required Fixture this.fixture,
    required String this.teamId,
    required this.returns,
  }) : count = 0;

  const _CalendarRow.notYet({required this.count})
    : fixture = null,
      teamId = null,
      returns = false;

  final Fixture? fixture;
  final String? teamId;
  final bool returns;
  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (redBg, redInk) = banColours(context);
    final greenBg = isDark ? const Color(0xFF123D2B) : AppColors.approvedBg;
    final greenInk = isDark ? const Color(0xFF7BE3B0) : AppColors.approvedText;
    final f = fixture;
    final team = teamId;

    final String title;
    final String sub;
    final (Color, Color, IconData, String?) look;
    if (f == null || team == null) {
      title = count == 1 ? '1 more match' : '$count more matches';
      sub = 'Not in the calendar yet: missed when they are added';
      look = (
        isDark ? AppColors.darkBorder : const Color(0xFFE6EDF5),
        scheme.onSurfaceVariant,
        Icons.event_busy_outlined,
        null,
      );
    } else {
      final when = f.kickoffAt;
      title = [
        if (when != null) formatShortDate(when),
        'Matchday ${f.round}',
      ].join(' · ');
      sub =
          'v ${f.opponentOf(team).name} (${f.isHome(team) ? 'H' : 'A'})'
          '${returns ? ' · back for this one' : ''}';
      look = returns
          ? (greenBg, greenInk, Icons.sports_soccer_rounded, 'Returns')
          : (redBg, redInk, Icons.block_rounded, 'Misses');
    }
    final (bg, ink, icon, tag) = look;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: ink, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
