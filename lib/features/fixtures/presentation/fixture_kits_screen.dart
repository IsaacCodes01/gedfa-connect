import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';

typedef _Slots = ({KitSlot home, KitSlot away, KitSlot homeGk, KitSlot awayGk});

/// Kits for a match (mockup K1). The app picked them by GEDFA's rule (the
/// home team keeps its home kit); the FA ([canEdit]) can choose others.
/// Teams see what each side and goalkeeper wears.
class FixtureKitsScreen extends ConsumerWidget {
  const FixtureKitsScreen({
    super.key,
    required this.fixtureId,
    this.canEdit = false,
  });

  final String fixtureId;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixtureAsync = ref.watch(fixtureProvider(fixtureId));
    return fixtureAsync.when(
      loading: () => const Scaffold(body: LoadingView(message: 'Loading the kits…')),
      error: (error, _) =>
          Scaffold(body: ErrorView(message: appErrorMessage(error))),
      data: (f) => f == null
          ? const Scaffold(
              body: EmptyView(
                icon: Icons.event_busy_outlined,
                title: 'Match not found',
                message: 'It may have been removed.',
              ),
            )
          : canEdit
              ? _EditKits(fixture: f)
              : _ViewKits(fixture: f),
    );
  }
}

/// The team's view: the four kits as saved on the match.
class _ViewKits extends StatelessWidget {
  const _ViewKits({required this.fixture});

  final Fixture fixture;

  @override
  Widget build(BuildContext context) {
    final f = fixture;
    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Kits for this match',
        subtitle: '${f.home.name} v ${f.away.name}',
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            DashboardSectionTitle(title: '${f.home.name} (home)', top: 2),
            _Pair(a: f.kits.home, b: f.kits.homeGk),
            DashboardSectionTitle(title: '${f.away.name} (away)'),
            _Pair(a: f.kits.away, b: f.kits.awayGk),
          ],
        ),
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({required this.a, required this.b});

  final KitChoice a;
  final KitChoice b;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(child: _KitTile(kit: a.kit, label: a.slot.label)),
          Expanded(child: _KitTile(kit: b.kit, label: b.slot.label)),
        ],
      ),
    );
  }
}

/// The FA's view: every kit each team has, the chosen one framed in green,
/// clashing ones faded with the reason.
class _EditKits extends ConsumerStatefulWidget {
  const _EditKits({required this.fixture});

  final Fixture fixture;

  @override
  ConsumerState<_EditKits> createState() => _EditKitsState();
}

class _EditKitsState extends ConsumerState<_EditKits> {
  _Slots? _picked;
  bool _busy = false;

  _Slots get _saved => (
        home: widget.fixture.kits.home.slot,
        away: widget.fixture.kits.away.slot,
        homeGk: widget.fixture.kits.homeGk.slot,
        awayGk: widget.fixture.kits.awayGk.slot,
      );

  Future<void> _save(MatchTeam home, MatchTeam away, _Slots slots) async {
    final f = widget.fixture;
    final me = ref.read(authRepositoryProvider).currentUser;
    final kickoff = f.kickoffAt;
    if (me == null || kickoff == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(fixtureRepositoryProvider).change(
            f,
            FixtureDraft(
              category: f.category,
              ageGroup: f.ageGroup,
              round: f.round,
              home: home,
              away: away,
              kickoffAt: kickoff,
              venue: f.venue,
              kits: slots,
            ),
            reason: '',
            by: me,
          );
      if (!mounted) return;
      AppToast.success(context, 'Kits saved. Both teams were told.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final homeAsync = ref.watch(matchTeamProvider((f.home.id, f.category)));
    final awayAsync = ref.watch(matchTeamProvider((f.away.id, f.category)));
    final home = homeAsync.value;
    final away = awayAsync.value;
    final error = homeAsync.error ?? awayAsync.error;

    Widget body;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (home == null || away == null) {
      body = const LoadingView(message: 'Loading the kits…');
    } else {
      final s = _picked ?? _saved;
      KitLook? look(MatchTeam t, KitSlot slot) => t.teamKits.look(slot);
      final homeLook = look(home, s.home);
      final awayLook = look(away, s.away);

      String? outfieldClash(KitLook? l, KitLook? against) =>
          l != null && against != null && l.shirtClashes(against)
              ? 'Clashes'
              : null;
      // A goalkeeper must look different from both outfield kits (Law 4).
      // The two goalkeepers may match; the referee is not known yet.
      String? gkClash(KitLook? l) =>
          l != null &&
                  [homeLook, awayLook]
                      .any((o) => o != null && l.shirtClashes(o))
              ? 'Like an outfield kit'
              : null;

      const outfield = [KitSlot.home, KitSlot.away, KitSlot.third];
      const keepers = [KitSlot.goalkeeper, KitSlot.goalkeeper2];

      body = ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            DashboardSectionTitle(
              title: '${home.side.name} (home)',
              trailing: 'Keeps its home kit',
              top: 2,
            ),
            _Options(
              team: home,
              slots: outfield,
              selected: s.home,
              clash: (slot) => outfieldClash(look(home, slot), awayLook),
              onPick: (slot) => setState(() => _picked = (
                    home: slot,
                    away: s.away,
                    homeGk: s.homeGk,
                    awayGk: s.awayGk,
                  )),
            ),
            DashboardSectionTitle(
              title: '${away.side.name} (away)',
              trailing: 'Picked by the app',
            ),
            _Options(
              team: away,
              slots: outfield,
              selected: s.away,
              clash: (slot) => outfieldClash(look(away, slot), homeLook),
              onPick: (slot) => setState(() => _picked = (
                    home: s.home,
                    away: slot,
                    homeGk: s.homeGk,
                    awayGk: s.awayGk,
                  )),
            ),
            DashboardSectionTitle(title: '${home.side.name} goalkeeper'),
            _Options(
              team: home,
              slots: keepers,
              selected: s.homeGk,
              clash: (slot) => gkClash(look(home, slot)),
              onPick: (slot) => setState(() => _picked = (
                    home: s.home,
                    away: s.away,
                    homeGk: slot,
                    awayGk: s.awayGk,
                  )),
            ),
            DashboardSectionTitle(title: '${away.side.name} goalkeeper'),
            _Options(
              team: away,
              slots: keepers,
              selected: s.awayGk,
              clash: (slot) => gkClash(look(away, slot)),
              onPick: (slot) => setState(() => _picked = (
                    home: s.home,
                    away: s.away,
                    homeGk: s.homeGk,
                    awayGk: slot,
                  )),
            ),
            const SizedBox(height: 16),
            if (f.kickoffAt == null)
              Text(
                'Set the new date first, then change the kits.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else if (!f.isCancelled)
              FilledButton(
                onPressed: _busy || _picked == null || _picked == _saved
                    ? null
                    : () => _save(home, away, s),
                child: const Text('Save and tell both teams'),
              ),
            const SizedBox(height: 8),
            Text(
              'Both teams see their kit on the match and on the team sheet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Kits for this match',
        subtitle: '${f.home.name} v ${f.away.name}',
      ),
      body: body,
    );
  }
}

/// A team's kits side by side; tap one to choose it.
class _Options extends StatelessWidget {
  const _Options({
    required this.team,
    required this.slots,
    required this.selected,
    required this.clash,
    required this.onPick,
  });

  final MatchTeam team;
  final List<KitSlot> slots;
  final KitSlot selected;
  final String? Function(KitSlot slot) clash;
  final ValueChanged<KitSlot> onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = [for (final s in slots) if (team.kits[s] != null) s];
    return DashboardCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          for (final slot in available)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Semantics(
                  button: true,
                  selected: slot == selected,
                  label: '${slot.label}${clash(slot) == null ? '' : ', ${clash(slot)}'}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onPick(slot),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: slot == selected
                            ? AccentTone.green.background(isDark)
                            : null,
                        border: Border.all(
                          width: 2,
                          color: slot == selected
                              ? AccentTone.green.foreground(isDark)
                              : Colors.transparent,
                        ),
                      ),
                      child: Opacity(
                        opacity: clash(slot) != null && slot != selected
                            ? 0.55
                            : 1,
                        child: _KitTile(
                          kit: team.kits[slot]!,
                          label: slot.label,
                          note: clash(slot),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KitTile extends StatelessWidget {
  const _KitTile({required this.kit, required this.label, this.note});

  final Kit kit;
  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        KitThumb(kit: kit, height: 74, semanticLabel: label),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
        if (note != null)
          Text(
            note!,
            style: TextStyle(fontSize: 11, color: scheme.error),
          ),
      ],
    );
  }
}
