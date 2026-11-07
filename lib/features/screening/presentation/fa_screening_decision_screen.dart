import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/duplicates.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/screening/domain/screening_day.dart';
import 'package:go_router/go_router.dart';

/// The ghana green of the "Pass … and next" button (board J4)
const _passGreen = Color(0xFF006B3F);

/// The three kinds of decision (2.14d): pass (in [_passIn]), needs
/// correcting (back to the team), not eligible (final).
enum _Decision { pass, fix, out }

/// The quick reasons for "Needs correcting" (board J4)
const _fixReasons = [
  'Photo is not clear',
  'Name has a typo',
  'Date of birth does not match',
  'No birth certificate',
  'Parent details are wrong',
];

/// FA, on the screening day (2.14c, board J4): one waiting child at a
/// time. The FA compares the photo and birth certificate with the child,
/// then picks:
///
/// - Passed in their group, or in an older one (moved up, no second
///   screening). The child gets a GJ26-… player ID.
/// - Needs correcting (2.14d): back to the team with a reason; the child
///   waits for screening again once fixed.
/// - Not eligible for Juvenile, with a reason for the team. Final.
///
/// After each decision the next child opens. "Skip" puts a child at the
/// end of the line (e.g. still on the way).
class FaScreeningDecisionScreen extends ConsumerStatefulWidget {
  const FaScreeningDecisionScreen({
    super.key,
    required this.dayId,
    this.childId,
  });

  final String dayId;

  /// "Screen player" from a child's page: this child comes first.
  final String? childId;

  @override
  ConsumerState<FaScreeningDecisionScreen> createState() =>
      _FaScreeningDecisionScreenState();
}

class _FaScreeningDecisionScreenState
    extends ConsumerState<FaScreeningDecisionScreen> {
  /// Children skipped in this visit, in the order they were skipped
  final _skipped = <String>[];

  /// How many children were decided in this visit ("3 of 41")
  int _done = 0;

  /// The child on screen, and the choice for them
  String? _childId;
  _Decision _decision = _Decision.pass;
  AgeGroup? _passIn;

  /// "Needs correcting": the quick reason picked, if any
  String? _quick;

  bool get _notEligible => _decision == _Decision.out;
  bool get _toFix => _decision == _Decision.fix;
  final _reason = TextEditingController();
  bool _showErrors = false;
  bool _busy = false;

  /// Before the start time this screen waits; it checks again every
  /// 30 seconds (the address could be opened directly).
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    _reason.dispose();
    super.dispose();
  }

  void _back() => context.goKeepingHome(Routes.adminScreening);

  /// Waiting children for this day: by team, age group and number, with
  /// skipped children at the end.
  List<Player> _queue(ScreeningDay day, List<Player> children) {
    final waiting = children
        .where((p) =>
            p.isWaitingForScreening && day.groups.contains(p.ageGroup))
        .toList()
      ..sort((a, b) {
        final byTeam = a.teamName.compareTo(b.teamName);
        if (byTeam != 0) return byTeam;
        final byGroup =
            (a.ageGroup?.index ?? 0).compareTo(b.ageGroup?.index ?? 0);
        if (byGroup != 0) return byGroup;
        return a.jerseyNo.compareTo(b.jerseyNo);
      });
    int skipRank(Player p) {
      final i = _skipped.indexOf(p.id);
      return i < 0 ? -1 : i;
    }

    // Stable: not skipped first (in the order above), then skipped
    final notSkipped = [for (final p in waiting) if (skipRank(p) < 0) p];
    final skipped = [for (final p in waiting) if (skipRank(p) >= 0) p]
      ..sort((a, b) => skipRank(a).compareTo(skipRank(b)));
    // "Screen player" (board J6): that child first, unless skipped
    final first = notSkipped.where((p) => p.id == widget.childId).toList();
    return [
      ...first,
      for (final p in notSkipped)
        if (p.id != widget.childId) p,
      ...skipped,
    ];
  }

  /// A new child on screen: start from "Passed in their own group".
  void _showChild(Player child) {
    if (_childId == child.id) return;
    _childId = child.id;
    _passIn = child.ageGroup;
    _decision = _Decision.pass;
    _quick = null;
    _reason.clear();
    _showErrors = false;
  }

  void _skip(Player child) => setState(() {
        _skipped
          ..remove(child.id)
          ..add(child.id);
      });

  Future<void> _decide(Player child) async {
    FocusScope.of(context).unfocus();
    final faUid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (faUid == null) return;
    final typed = _reason.text.trim();
    // Needs correcting: the quick reason, and/or what the FA typed
    final reason = _toFix
        ? [?_quick, if (typed.isNotEmpty) typed].join('. ')
        : typed;
    if ((_notEligible || _toFix) && reason.length < 5) {
      setState(() => _showErrors = true);
      AppToast.warning(
        context,
        _toFix
            ? 'Pick what the team should correct, or write it.'
            : 'Write a reason for the team.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repository = ref.read(playerRepositoryProvider);
      if (_notEligible) {
        await repository.markNotEligible(
          child,
          reason: reason,
          dayId: widget.dayId,
          faUid: faUid,
        );
        if (!mounted) return;
        AppToast.info(context, '${child.fullName}: not eligible.');
      } else if (_toFix) {
        await repository.sendBackJuvenile(
          child,
          reason: reason,
          dayId: widget.dayId,
          faUid: faUid,
        );
        if (!mounted) return;
        AppToast.info(context, '${child.fullName} sent back to the team.');
      } else {
        final group = _passIn ?? child.ageGroup ?? AgeGroup.u13;
        final code = await repository.passJuvenile(
          child,
          group: group,
          dayId: widget.dayId,
          faUid: faUid,
        );
        if (!mounted) return;
        AppToast.success(
          context,
          '${child.fullName} passed in ${group.label}: $code',
        );
      }
      // The child is no longer waiting, so the next one shows by itself
      setState(() {
        _done++;
        _skipped.remove(child.id);
      });
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayAsync = ref.watch(screeningDayProvider(widget.dayId));
    final childrenAsync = ref.watch(juvenilePlayersProvider);
    final day = dayAsync.value;

    Widget body;
    Widget? bottom;
    String? subtitle;
    final error = dayAsync.error ?? childrenAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!dayAsync.hasValue || !childrenAsync.hasValue) {
      body = const LoadingView();
    } else if (day == null) {
      body = const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'Screening day not found',
        message: 'It may have been cancelled.',
      );
    } else if (!day.hasStarted(DateTime.now())) {
      subtitle = '${day.dateText} · ${day.groupsText}';
      body = EmptyView(
        icon: Icons.lock_clock_outlined,
        title: 'Screening opens at ${day.timeText}',
        message: 'Come back on ${day.dateText} at ${day.timeText}, '
            '${day.venue}. This page opens by itself at that time.',
      );
    } else {
      final queue = _queue(day, childrenAsync.requireValue);
      final total = _done + queue.length;
      subtitle = queue.isEmpty
          ? '${day.dateText} · ${day.groupsText}'
          : '${day.dateText} · ${queue.first.ageGroup?.label ?? ''} · '
              '${_done + 1} of $total';
      if (queue.isEmpty) {
        body = _AllDone(done: _done, day: day, onBack: _back);
      } else {
        final child = queue.first;
        _showChild(child);
        body = _childBody(child, childrenAsync.requireValue);
        bottom = _DecisionBar(
          busy: _busy,
          canSkip: queue.length > 1,
          decision: _decision,
          passLabel: _passIn?.label ?? '',
          onSkip: () => _skip(child),
          onDecide: () => _decide(child),
        );
      }
    }

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Screening',
          subtitle: subtitle,
          leading: BackButton(onPressed: _busy ? null : _back),
        ),
        bottomNavigationBar: bottom,
        body: body,
      ),
    );
  }

  Widget _childBody(Player child, List<Player> allChildren) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final registered = child.ageGroup ?? AgeGroup.u13;
    final own = AgeGroup.ownGroup(child.dob);
    final age = AgeGroup.seasonAge(child.dob);
    final year = Season.startYear(Season.current);
    final guardian = child.guardian;
    // "GJ26-": the year of the decision, like the rules
    final idPrefix =
        'GJ${(DateTime.now().toUtc().year % 100).toString().padLeft(2, '0')}-';

    // Passing: the registered group or an older one, never younger
    final options = [
      for (final group in AgeGroup.values)
        if (group.index >= registered.index) group,
    ];

    return ListView(
      // Each child starts at the top
      key: ValueKey(child.id),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PassportPhoto(
                    name: child.fullName,
                    url: child.photoUrl,
                    width: 120,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.fullName,
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${child.teamName} · #${child.jerseyNo}',
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Born ${formatDate(child.dob)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: ' · $age in $year'),
                            ],
                          ),
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Registered in '),
                              TextSpan(
                                text: registered.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: own == registered
                                    ? ' (own group)'
                                    : ' (${own?.label ?? '?'} age)',
                              ),
                            ],
                          ),
                          style: textTheme.bodyMedium,
                        ),
                        if (guardian != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${guardian.relation.label}: ${guardian.name}',
                            style: textTheme.bodyMedium,
                          ),
                          Text(
                            guardian.phone,
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Board J4: the Division's duplicate check, among juvenile
              // players (2.14d)
              _DuplicatesBox(
                matches: possibleDuplicates(child, allChildren),
              ),
              const SizedBox(height: 14),
              const _InfoNote(
                'Compare the photo and the birth certificate with the child '
                'in front of you.',
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'DECISION',
                  style: textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              for (final group in options) ...[
                _OptionCard(
                  title: group == registered
                      ? 'Passed for ${group.label}'
                      : 'Passed for ${group.label} (moved up)',
                  text: group == registered
                      ? 'The child looks the right age and the papers match. '
                          'Gets a player ID ($idPrefix…).'
                      : 'Looks too old for ${registered.label} but fits '
                          '${group.label}. Moves to ${group.label} with a '
                          'player ID, no second screening.',
                  color: _passGreen,
                  selected: _decision == _Decision.pass && _passIn == group,
                  enabled: !_busy,
                  onTap: () => setState(() {
                    _decision = _Decision.pass;
                    _passIn = group;
                  }),
                ),
                const SizedBox(height: 8),
              ],
              _OptionCard(
                title: 'Needs correcting',
                text: 'Something on the registration is wrong (photo, name, '
                    'date). Goes back to the team to fix; then the child '
                    'waits for screening again.',
                color: _amberOf(context),
                selected: _toFix,
                enabled: !_busy,
                onTap: () => setState(() => _decision = _Decision.fix),
              ),
              const SizedBox(height: 8),
              _OptionCard(
                title: 'Not eligible for Juvenile',
                text: 'Fits no group (or the papers are false). Blocks this '
                    'player from U13, U15 and U17, with a reason. Final. The '
                    'team can register them in the Division if old enough.',
                color: scheme.error,
                selected: _notEligible,
                enabled: !_busy,
                onTap: () => setState(() => _decision = _Decision.out),
              ),
              if (_toFix) ...[
                const SizedBox(height: 14),
                Text(
                  'What should the team correct? *',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final quick in _fixReasons)
                      ChoiceChip(
                        label: Text(quick),
                        selected: _quick == quick,
                        onSelected: _busy
                            ? null
                            : (on) => setState(() => _quick = on ? quick : null),
                      ),
                  ],
                ),
              ],
              if (_notEligible || _toFix) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _reason,
                  enabled: !_busy,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _toFix
                        ? 'Or write it yourself'
                        : 'Reason for the team *',
                    hintText: _toFix
                        ? 'e.g. The surname is spelt Mensah on the certificate'
                        : 'e.g. Looks older than 17; no birth certificate',
                    errorText: !_showErrors
                        ? null
                        : _notEligible && _reason.text.trim().length < 5
                            ? 'Write a reason (at least 5 characters)'
                            : _toFix &&
                                    _quick == null &&
                                    _reason.text.trim().length < 5
                                ? 'Pick a reason above or write one'
                                : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One choice: a round radio, a title in the choice's colour when
/// selected, and a short explanation.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.text,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String text;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: selected
            ? (isDark ? const Color(0xFF16304F) : const Color(0xFFF7FAFD))
            : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? color : scheme.outline,
            width: selected ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? color : scheme.onSurfaceVariant,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? CircleAvatar(radius: 5, backgroundColor: color)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: selected ? color : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        text,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote(this.text);

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

/// "Skip   [Pass in U13 and next]" or "[Not eligible and next]".
class _DecisionBar extends StatelessWidget {
  const _DecisionBar({
    required this.busy,
    required this.canSkip,
    required this.decision,
    required this.passLabel,
    required this.onSkip,
    required this.onDecide,
  });

  final bool busy;
  final bool canSkip;
  final _Decision decision;
  final String passLabel;
  final VoidCallback onSkip;
  final VoidCallback onDecide;

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
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: busy || !canSkip ? null : onSkip,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: busy ? null : onDecide,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        // Green pass, Ghana gold send-back, red not eligible
                        backgroundColor: switch (decision) {
                          _Decision.pass => _passGreen,
                          _Decision.fix => const Color(0xFFFCD116),
                          _Decision.out => scheme.error,
                        },
                        foregroundColor: switch (decision) {
                          _Decision.pass => Colors.white,
                          _Decision.fix => const Color(0xFF3A2C00),
                          _Decision.out => scheme.onError,
                        },
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
                          : Text(
                              switch (decision) {
                                _Decision.pass => 'Pass in $passLabel and next',
                                _Decision.fix => 'Send back and next',
                                _Decision.out => 'Not eligible and next',
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// No child left to screen for this day.
class _AllDone extends StatelessWidget {
  const _AllDone({required this.done, required this.day, required this.onBack});

  final int done;
  final ScreeningDay day;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyView(
              icon: Icons.task_alt_rounded,
              title: 'Nobody left to screen',
              message: done == 0
                  ? 'No ${day.groupsText} children are waiting for screening.'
                  : done == 1
                      ? '1 child screened. Teams see the result in their bell.'
                      : '$done children screened. Teams see the results in '
                          'their bell.',
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back to screening days'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The amber of "Needs correcting" (readable on light and dark).
Color _amberOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF5D25B)
        : const Color(0xFF8A6A00);

/// Board J4: "⚠ Possible duplicate", the same check as the Division
/// review (a similar name with the same date of birth, or the same name
/// within two years), among juvenile players of every club. Nothing shows
/// when there are none.
class _DuplicatesBox extends StatelessWidget {
  const _DuplicatesBox({required this.matches});

  final List<PossibleDuplicate> matches;

  @override
  Widget build(BuildContext context) {
    if (matches.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF3D3410) : const Color(0xFFFFF6CC);
    final ink = isDark ? const Color(0xFFF5D25B) : const Color(0xFF5C4700);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ink, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: ink, size: 20),
                const SizedBox(width: 8),
                Text(
                  matches.length == 1
                      ? 'Possible duplicate'
                      : '${matches.length} possible duplicates',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: ink),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Check before passing. Exact copies (same name and date of '
              'birth) are already blocked when a team saves.',
              style: textTheme.bodySmall?.copyWith(color: ink),
            ),
            for (final match in matches) ...[
              const SizedBox(height: 8),
              Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context
                      .push(Routes.adminJuvenileChild(match.player.id)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        PlayerAvatar(
                          name: match.player.fullName,
                          url: match.player.thumbUrl,
                          size: 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match.player.fullName,
                                style: textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                [
                                  match.player.teamName,
                                  ?match.player.ageGroup?.label,
                                  'born ${formatDate(match.player.dob)}',
                                  match.reason,
                                ].join(' · '),
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'Open ›',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
