import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/officials/data/officials_repository.dart';
import 'package:gedfa_connect/features/officials/domain/match_officials.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/domain/member.dart';

/// Match details › Officials (3.5a, mockup MO1).
///
/// - The FA: the five places, each "Appoint" or a name with ⋯ (Change,
///   Take off), and the referee colours that don't clash.
/// - A club: the names from 24 hours before kick-off (Isaac, 11 Nov 2026);
///   before that, when they will show.
class OfficialsSection extends ConsumerWidget {
  const OfficialsSection({
    super.key,
    required this.fixture,
    this.isFa = false,
    this.isOfficial = false,
  });

  final Fixture fixture;
  final bool isFa;

  /// An appointed referee or commissioner (3.5b, RD3): every name, theirs
  /// marked "(you)", and Can't make it.
  final bool isOfficial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final now = DateTime.now();
    final canSee = isFa || isOfficial || MatchOfficials.clubsMaySee(f, now);
    final myUid = ref.watch(appUserProvider).value?.uid;
    // The rules refuse a club before then: don't even ask
    final officials = canSee
        ? ref.watch(matchOfficialsProvider(f.id)).value
        : null;
    final kickoff = f.kickoffAt;

    final Widget body;
    if (!canSee) {
      body = OfficialLine(
        icon: Icons.schedule_rounded,
        title: 'Referee and assistants',
        detail: kickoff == null
            ? 'Shown 24 hours before kick-off, once the match has a date.'
            : 'Shown from ${_when(kickoff.subtract(MatchOfficials.clubsSeeBefore))} '
                  '(24 hours before kick-off).',
      );
    } else {
      final o = officials ?? MatchOfficials(fixtureId: f.id);
      final canChange = isFa && !f.isCancelled && !f.isPlayed(now);
      body = Column(
        children: [
          for (final place in OfficialPlace.values)
            OfficialLine(
              icon: o[place] == null
                  ? Icons.person_add_alt_outlined
                  : Icons.sports_rounded,
              title: place.label,
              detail: switch (o[place]) {
                null => 'Not appointed',
                final who when isOfficial && who.uid == myUid =>
                  '${who.name} (you)',
                final who => who.name,
              },
              muted: o[place] == null,
              // 3.5b: the FA sees why someone can't come
              warning: switch (o[place]) {
                final who? when o.cantMake.containsKey(who.uid) =>
                  "Can't make it: \"${o.cantMake[who.uid]}\"",
                _ => null,
              },
              trailing: !canChange
                  ? null
                  : o[place] == null
                  ? TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      onPressed: () => _appoint(context, ref, f, o, place),
                      child: const Text('Appoint'),
                    )
                  : PopupMenuButton<bool>(
                      tooltip: 'Change or take off',
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (change) => change
                          ? _appoint(context, ref, f, o, place)
                          : _save(context, ref, f, o, o.withPlace(place, null)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: true, child: Text('Change')),
                        PopupMenuItem(value: false, child: Text('Take off')),
                      ],
                    ),
            ),
        ],
      );
    }

    final colours = refereeColoursFor(f);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DashboardSectionTitle(
          title: 'Officials',
          trailing: !canSee || officials == null
              ? null
              : '${officials.count} of ${OfficialPlace.values.length}',
        ),
        DashboardCard(padding: EdgeInsets.zero, child: body),
        if (isOfficial && myUid != null)
          _CantMakeIt(
            fixture: f,
            officials: officials ?? MatchOfficials(fixtureId: f.id),
            uid: myUid,
          ),
        if ((isFa || isOfficial) && colours.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Referee colour for this match:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                for (final (i, (name, colour)) in colours.indexed) ...[
                  _Swatch(colour),
                  Text(
                    '$name${i == colours.length - 1 ? '' : ' or'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  static String _when(DateTime t) => '${formatShortDate(t)}, ${formatTime(t)}';

  Future<void> _appoint(
    BuildContext context,
    WidgetRef ref,
    Fixture f,
    MatchOfficials o,
    OfficialPlace place,
  ) async {
    final picked = await showOfficialPicker(
      context,
      fixture: f,
      place: place,
      officials: o,
    );
    if (picked == null || !context.mounted) return;
    await _save(
      context,
      ref,
      f,
      o,
      o.withPlace(place, AppointedOfficial(uid: picked.uid, name: picked.name)),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    Fixture f,
    MatchOfficials before,
    MatchOfficials after,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      await ref
          .read(officialsRepositoryProvider)
          .save(f, before, after, by: user);
      if (context.mounted) {
        AppToast.success(context, 'Saved. The officials have been told.');
      }
    } catch (error) {
      if (context.mounted) AppToast.error(context, appErrorMessage(error));
    }
  }
}

/// One row: icon, title, detail, and an optional button.
class OfficialLine extends StatelessWidget {
  const OfficialLine({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.muted = false,
    this.warning,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool muted;

  /// A red line under the name (Can't make it).
  final String? warning;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          Icon(icon, color: muted ? scheme.onSurfaceVariant : scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                    color: muted ? scheme.onSurfaceVariant : null,
                  ),
                ),
                if (warning case final w?)
                  Text(
                    w,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.error,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// RD3 (3.5b): "Can't make it" for the signed-in official, with why; or,
/// once sent, what they told the FA.
class _CantMakeIt extends ConsumerWidget {
  const _CantMakeIt({
    required this.fixture,
    required this.officials,
    required this.uid,
  });

  final Fixture fixture;
  final MatchOfficials officials;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = fixture;
    final place = officials.placeOf(uid);
    final me = place == null ? null : officials[place];
    if (place == null || me == null) return const SizedBox.shrink();
    final sent = officials.cantMake[uid];
    final scheme = Theme.of(context).colorScheme;
    if (sent != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.error.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            "You told the FA you can't make it: \"$sent\". The FA will "
            'appoint someone else; you are told when it does.',
            style: TextStyle(fontSize: 12.5, color: scheme.error),
          ),
        ),
      );
    }
    if (f.isCancelled || f.isPlayed(DateTime.now())) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: FilledButton.tonalIcon(
        onPressed: () async {
          final reason = await _askWhy(context);
          if (reason == null || !context.mounted) return;
          try {
            await ref
                .read(officialsRepositoryProvider)
                .cantMakeIt(f, place: place, me: me, reason: reason);
            if (context.mounted) {
              AppToast.success(context, 'The FA has been told.');
            }
          } catch (error) {
            if (context.mounted) {
              AppToast.error(context, appErrorMessage(error));
            }
          }
        },
        icon: const Icon(Icons.event_busy_rounded),
        label: const Text("Can't make it"),
      ),
    );
  }

  static Future<String?> _askWhy(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final text = controller.text.trim();
          return AlertDialog(
            title: const Text("Can't make it?"),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Why? *',
                helperText: 'The FA reads it and appoints someone else.',
              ),
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
                onPressed: text.length < 3
                    ? null
                    : () => Navigator.of(dialogContext).pop(text),
                child: const Text('Tell the FA'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.colour);

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 16,
    height: 18,
    decoration: BoxDecoration(
      color: colour,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.black26),
    ),
  );
}

/// MO2: pick a person for [place] of [fixture]. Referees for the first
/// four places; FA officials and referees for commissioner. Shows who is
/// busy elsewhere that day (gold when less than 3 hours apart); someone
/// already in this match can't be picked twice.
Future<Member?> showOfficialPicker(
  BuildContext context, {
  required Fixture fixture,
  required OfficialPlace place,
  required MatchOfficials officials,
}) => showModalBottomSheet<Member>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _Picker(fixture: fixture, place: place, officials: officials),
);

class _Picker extends ConsumerStatefulWidget {
  const _Picker({
    required this.fixture,
    required this.place,
    required this.officials,
  });

  final Fixture fixture;
  final OfficialPlace place;
  final MatchOfficials officials;

  @override
  ConsumerState<_Picker> createState() => _PickerState();
}

class _PickerState extends ConsumerState<_Picker> {
  String _search = '';
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final f = widget.fixture;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gold = isDark ? const Color(0xFFF5D25B) : AppColors.pendingText;
    final members = ref.watch(membersProvider).value ?? const <Member>[];
    final all = ref.watch(seasonOfficialsProvider).value ?? const {};
    final fixtures = ref.watch(seasonFixturesProvider).value ?? const [];
    final current = widget.officials[widget.place]?.uid;
    final query = _search.trim().toLowerCase();

    final people = [
      for (final m in members)
        if ((m.role == UserRole.referee ||
                (widget.place.takesFaOfficials &&
                    m.role == UserRole.faAdmin)) &&
            (query.isEmpty || m.name.toLowerCase().contains(query)))
          m,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final picked = _picked ?? current;
    final pickedName = people.where((m) => m.uid == picked).firstOrNull?.name;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.place.label,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              appointmentLine(f),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search a name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: people.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        widget.place.takesFaOfficials
                            ? 'No referees or FA officials found.'
                            : 'No referees found. Invite them in More › '
                                  'People and roles.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final m in people)
                          _PersonRow(
                            member: m,
                            selected: m.uid == picked,
                            // Already in this match, in another place
                            here: switch (widget.officials.placeOf(m.uid)) {
                              final p? when p != widget.place =>
                                '${p.label} of this match',
                              _ => null,
                            },
                            busy: switch (busyElsewhere(
                              m.uid,
                              f,
                              all,
                              fixtures,
                            )) {
                              final b? => (
                                'Also ${b.place.label} · '
                                    '${b.match.venue}, '
                                    '${formatTime(b.match.kickoffAt!)}',
                                b.near ? gold : scheme.onSurfaceVariant,
                              ),
                              null => null,
                            },
                            onTap: () => setState(() => _picked = m.uid),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: picked == null || picked == current
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(people.firstWhere((m) => m.uid == picked)),
              child: Text(
                pickedName == null || picked == current
                    ? 'Appoint'
                    : 'Appoint $pickedName',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.member,
    required this.selected,
    required this.here,
    required this.busy,
    required this.onTap,
  });

  final Member member;
  final bool selected;

  /// "Referee of this match": can't be picked twice.
  final String? here;

  /// "Also Assistant 2 · Nyanyano Park, 3:00 pm", and its colour.
  final (String, Color)? busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocked = here != null;
    final busy = this.busy;
    return Opacity(
      opacity: blocked ? .5 : 1,
      child: Material(
        color: selected ? scheme.primary.withValues(alpha: .1) : null,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: blocked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.person_outline,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        [member.roleLabel, ?here, ?busy?.$1].join(' · '),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: busy != null && here == null
                              ? busy.$2
                              : scheme.onSurfaceVariant,
                          fontWeight: busy != null && here == null
                              ? FontWeight.w600
                              : null,
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
