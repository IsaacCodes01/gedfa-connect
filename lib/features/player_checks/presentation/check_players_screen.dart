import 'package:flutter/material.dart';
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
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/player_checks/data/player_check_repository.dart';
import 'package:gedfa_connect/features/player_checks/domain/player_check.dart';
import 'package:gedfa_connect/features/players/data/player_photos.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/player_photo.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';

/// Check players (3.6b, mockup MC2): the commissioner checks each face
/// on the saved sheets against the registered photo, one player at a
/// time, in shirt order: Matches / Doesn't match (with a note) / Absent.
/// From the lock until 2 h after kick-off. The match's other officials and
/// the FA may look; only the commissioner records.
class CheckPlayersScreen extends ConsumerStatefulWidget {
  const CheckPlayersScreen({
    super.key,
    required this.fixtureId,
    this.isFa = false,
  });

  final String fixtureId;

  /// Opened from the FA's area (an FA official may be the commissioner).
  final bool isFa;

  @override
  ConsumerState<CheckPlayersScreen> createState() => _CheckPlayersScreenState();
}

class _CheckPlayersScreenState extends ConsumerState<CheckPlayersScreen> {
  /// 0 = home, 1 = away.
  int _side = 0;
  final _pages = PageController();
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _fallback => widget.isFa
      ? Routes.adminMatch(widget.fixtureId)
      : Routes.refereeMatch(widget.fixtureId);

  void _showSide(int side) {
    if (side == _side) return;
    setState(() {
      _side = side;
      _page = 0;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  Future<void> _record(
    Fixture fixture,
    CheckLine line,
    CheckResult result,
    List<CheckLine> lines,
    MatchPlayerChecks? checks,
  ) async {
    String? note;
    if (result == CheckResult.mismatch) {
      note = await _askNote(line);
      if (note == null) return; // cancelled
    }
    final me = ref.read(appUserProvider).value;
    if (me == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(playerCheckRepositoryProvider)
          .record(
            fixture: fixture,
            line: line,
            result: result,
            note: note,
            by: me.uid,
            byName: me.displayName ?? 'Commissioner',
          );
      if (!mounted) return;
      // On to the next player not checked yet (this one now is)
      final done = {
        ...?checks?.results,
        line.playerId: PlayerCheck(result: result, teamId: line.teamId),
      };
      final next = CheckLine.nextUnchecked(
        lines,
        MatchPlayerChecks(fixtureId: widget.fixtureId, results: done),
        _page,
      );
      if (next != null && _pages.hasClients) {
        await _pages.animateToPage(
          next,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) AppToast.error(context, appErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Doesn't match": what the commissioner saw (3 to 300 characters).
  Future<String?> _askNote(CheckLine line) => showDialog<String>(
    context: context,
    builder: (_) => _NoteDialog(name: line.name),
  );

  @override
  Widget build(BuildContext context) {
    final fixture = ref.watch(fixtureProvider(widget.fixtureId));
    final f = fixture.value;
    final now = DateTime.now();
    final opens = f == null ? null : CheckWindow.opensAt(f);
    final started = opens != null && !now.isBefore(opens);

    // The sheets open to the officials only from the lock (3.5c)
    final home = f != null && started
        ? ref.watch(teamSheetProvider((f.id, f.home.id)))
        : null;
    final away = f != null && started
        ? ref.watch(teamSheetProvider((f.id, f.away.id)))
        : null;
    final officials = ref.watch(matchOfficialsProvider(widget.fixtureId));
    final checks = started
        ? ref.watch(playerChecksProvider(widget.fixtureId))
        : null;
    final me = ref.watch(appUserProvider).value;

    final error =
        fixture.error ??
        home?.error ??
        away?.error ??
        officials.error ??
        checks?.error;
    final loading =
        fixture.isLoading ||
        (home?.isLoading ?? false) ||
        (away?.isLoading ?? false) ||
        officials.isLoading ||
        (checks?.isLoading ?? false);

    FixtureSide? side;
    var lines = const <CheckLine>[];
    var subtitle = '';
    Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (loading) {
      body = const LoadingView(message: 'Getting the players to check…');
    } else if (f == null) {
      body = const EmptyView(
        icon: Icons.event_busy_outlined,
        title: 'Match not found',
        message: 'This match may have been removed.',
      );
    } else if (!started) {
      body = EmptyView(
        icon: Icons.lock_clock_outlined,
        title: 'Not yet',
        message: opens == null
            ? 'The players check opens 1 hour before kick-off.'
            : 'The players check opens at ${formatTime(opens)} on '
                  '${formatShortDate(opens)}, when the sheets lock.',
      );
    } else {
      final commissioner = officials.value?[OfficialPlace.commissioner];
      final isCommissioner = me != null && commissioner?.uid == me.uid;
      final canRecord = isCommissioner && CheckWindow.isOpen(f, now);
      side = _side == 0 ? f.home : f.away;
      final sheet = (_side == 0 ? home : away)?.value;
      lines = sheet == null ? const [] : CheckLine.forSheet(sheet, f);
      final c = checks?.value;
      subtitle =
          '${side.name} · ${CheckLine.checkedCount(lines, c)} of '
          '${lines.length} checked';
      int count(FixtureSide s) {
        final sh = (s.id == f.home.id ? home : away)?.value;
        return sh == null ? 0 : sh.playerCount;
      }

      body = _CheckBody(
        fixture: f,
        side: _side,
        onSide: _showSide,
        counts: (count(f.home), count(f.away)),
        lines: lines,
        checks: c,
        pages: _pages,
        page: _page.clamp(0, lines.isEmpty ? 0 : lines.length - 1),
        onPage: (i) => setState(() => _page = i),
        note: !isCommissioner
            ? 'Only the commissioner'
                  '${commissioner == null ? '' : ' (${commissioner.name})'} '
                  'records the check. You can look.'
            : canRecord
            ? null
            : 'The check closed 2 hours after kick-off.',
        onRecord: !canRecord || _saving
            ? null
            : (line, result) => _record(f, line, result, lines, c),
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Check players',
        subtitle: subtitle.isEmpty ? null : subtitle,
        leading: AppBackButton(fallback: _fallback),
      ),
      body: body,
    );
  }
}

/// "Doesn't match": what the commissioner saw. Its own widget so the text
/// box lives exactly as long as the dialog (closing animation included).
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.name});

  final String name;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _note.text.trim().length >= MatchPlayerChecks.minNote;
    return AlertDialog(
      title: Text("${widget.name} doesn't match"),
      content: TextField(
        controller: _note,
        autofocus: true,
        maxLength: MatchPlayerChecks.maxNote,
        maxLines: 3,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'What did you see?',
          hintText: 'e.g. face different from the photo',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: ok
              ? () => Navigator.pop(context, _note.text.trim())
              : null,
          child: const Text('Record'),
        ),
      ],
    );
  }
}

/// The team switch, the player cards (swipe for the next) and the three
/// buttons under them (MC2).
class _CheckBody extends StatelessWidget {
  const _CheckBody({
    required this.fixture,
    required this.side,
    required this.onSide,
    required this.counts,
    required this.lines,
    required this.checks,
    required this.pages,
    required this.page,
    required this.onPage,
    required this.note,
    required this.onRecord,
  });

  final Fixture fixture;
  final int side;
  final ValueChanged<int> onSide;
  final (int, int) counts;
  final List<CheckLine> lines;
  final MatchPlayerChecks? checks;
  final PageController pages;
  final int page;
  final ValueChanged<int> onPage;

  /// Why the buttons are off, if they are.
  final String? note;
  final void Function(CheckLine line, CheckResult result)? onRecord;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final current = lines.isEmpty ? null : lines[page];
    final record = onRecord;

    Widget resultButton(CheckResult r, AccentTone tone, IconData icon) =>
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: tone.background(isDark),
            foregroundColor: tone.foreground(isDark),
          ),
          onPressed: record == null || current == null
              ? null
              : () => record(current, r),
          icon: Icon(icon, size: 18),
          label: Text(r.label),
        );

    return ResponsiveCenter(
      maxWidth: 560,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ChoiceChip(
                  label: Text('${fixture.home.name} (${counts.$1})'),
                  selected: side == 0,
                  onSelected: (_) => onSide(0),
                ),
                ChoiceChip(
                  label: Text('${fixture.away.name} (${counts.$2})'),
                  selected: side == 1,
                  onSelected: (_) => onSide(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: lines.isEmpty
                ? const EmptyView(
                    icon: Icons.assignment_outlined,
                    title: 'No team sheet',
                    message: 'This team saved no sheet for the match.',
                  )
                : PageView.builder(
                    controller: pages,
                    itemCount: lines.length,
                    onPageChanged: onPage,
                    itemBuilder: (_, i) => _PlayerCard(
                      line: lines[i],
                      check: checks?[lines[i].playerId],
                    ),
                  ),
          ),
          if (current != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: resultButton(
                            CheckResult.match,
                            AccentTone.green,
                            Icons.check,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: resultButton(
                            CheckResult.mismatch,
                            AccentTone.red,
                            Icons.close,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    resultButton(
                      CheckResult.absent,
                      AccentTone.grey,
                      Icons.person_off_outlined,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note ??
                          "Player ${page + 1} of ${lines.length}. Swipe for "
                              "the next. \"Doesn't match\" asks for a note; "
                              'the result goes to the FA and the match report.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One player (MC2): the registered photo, the shirt number for this
/// match, name, position · ID · usual number, Starting / Bench and the
/// answer so far.
class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({required this.line, required this.check});

  final CheckLine line;
  final PlayerCheck? check;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photo = ref.watch(playerPhotoProvider(line.playerId));
    final c = check;
    final tone = switch (c?.result) {
      CheckResult.match => AccentTone.green,
      CheckResult.mismatch => AccentTone.red,
      CheckResult.absent => AccentTone.grey,
      null => null,
    };

    Widget chip(String text, AccentTone t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.background(isDark),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: t.foreground(isDark),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              switch (photo) {
                AsyncData(value: final p?) => PassportPhoto(
                  name: line.name,
                  url: p.photoUrl,
                  width: 165,
                ),
                AsyncLoading() => const SizedBox(
                  width: 165,
                  height: 220,
                  child: SkeletonBox(height: 220, radius: 12),
                ),
                _ => Column(
                  children: [
                    PassportPhoto(name: line.name, width: 165),
                    const SizedBox(height: 6),
                    chip('No registered photo found', AccentTone.gold),
                  ],
                ),
              },
              const SizedBox(height: 10),
              Text(
                line.number?.toString() ?? '–',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                line.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                line.detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  chip(line.isBench ? 'Bench' : 'Starting', AccentTone.blue),
                  if (c != null && tone != null) chip(c.result.label, tone),
                ],
              ),
              if (c?.note case final n?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '"$n"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
