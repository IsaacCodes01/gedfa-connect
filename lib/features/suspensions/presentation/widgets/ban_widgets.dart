import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/suspensions/data/player_suspension_repository.dart';
import 'package:gedfa_connect/features/suspensions/domain/player_suspension.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// The suspension red: background and ink, light and dark.
(Color, Color) banColours(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? (const Color(0xFF4A1820), const Color(0xFFFF9DA6))
    : (AppColors.rejectedBg, AppColors.rejectedText);

/// SP3: the red box at the top of a suspended player's page. "Suspended ·
/// 2 matches left", why and when, the matches missed, the return.
class BanBanner extends StatelessWidget {
  const BanBanner({super.key, required this.status});

  final BanStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = banColours(context);
    final s = status.suspension;
    final at = s.at;
    final note = s.note;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block_rounded, color: ink, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: DefaultTextStyle.merge(
              style: textTheme.bodySmall?.copyWith(fontSize: 13, height: 1.45),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suspended · ${status.leftText}',
                    style: TextStyle(color: ink, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${s.reasonLabel} · ${s.competition.label} · by the FA'
                    '${at == null ? '' : ' on ${formatShortDate(at)}'}',
                  ),
                  if (note != null) Text('"$note"'),
                  Text(status.missesText(s.teamId)),
                  // 3.1e3 (SB2): blocked everywhere until it is served
                  const Text(
                    "Can't play in any competition until then.",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    status.returnsText(s.teamId),
                    style: const TextStyle(fontWeight: FontWeight.w700),
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

/// The FA's button at the bottom of a player's page: "Suspend" for an
/// approved player, "Lift suspension" while one is in force.
class FaBanBar extends ConsumerWidget {
  const FaBanBar({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ban = ref.watch(faBansProvider)[player.id];
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
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
            child: ban == null
                ? FilledButton.icon(
                    onPressed: () =>
                        context.open(Routes.adminSuspendPlayer(player.id)),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Suspend'),
                  )
                : OutlinedButton.icon(
                    onPressed: () => liftBan(context, ref, ban.suspension),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Lift suspension'),
                  ),
          ),
        ),
      ),
    );
  }
}

/// SP2: "Lift suspension" with why, then one batch, then a toast.
Future<void> liftBan(
  BuildContext context,
  WidgetRef ref,
  PlayerSuspension s,
) async {
  final input =
      await showModalBottomSheet<({BanLiftReason reason, String? note})>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _LiftBanSheet(name: s.playerName),
      );
  if (input == null || !context.mounted) return;
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return;
  try {
    await ref
        .read(playerSuspensionRepositoryProvider)
        .lift(
          s,
          reason: input.reason,
          note: input.note,
          byUid: user.uid,
          byName: user.displayName,
        );
    if (context.mounted) {
      AppToast.success(
        context,
        'Suspension lifted. ${s.teamName} has been told.',
      );
    }
  } catch (error) {
    if (context.mounted) AppToast.error(context, appErrorMessage(error));
  }
}

class _LiftBanSheet extends StatefulWidget {
  const _LiftBanSheet({required this.name});

  final String name;

  @override
  State<_LiftBanSheet> createState() => _LiftBanSheetState();
}

class _LiftBanSheetState extends State<_LiftBanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  BanLiftReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _lift() {
    final reason = _reason;
    if (reason == null || !_formKey.currentState!.validate()) return;
    final note = _note.text.trim();
    Navigator.of(
      context,
    ).pop((reason: reason, note: note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isOther = _reason == BanLiftReason.other;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Lift ${widget.name}'s suspension?",
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The player can be picked again straight away, and the club '
                'is told.',
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              const SectionTitle('Why'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in BanLiftReason.values)
                    ChoiceChip(
                      label: Text(reason.label),
                      selected: _reason == reason,
                      onSelected: (_) => setState(() => _reason = reason),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                inputFormatters: [LengthLimitingTextInputFormatter(200)],
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: isOther ? 'Note *' : 'Note (optional)',
                  helperText: 'The club sees it.',
                  alignLabelWithHint: true,
                ),
                // "Other" needs a note (the rules too)
                validator: (value) => isOther && (value?.trim().length ?? 0) < 3
                    ? 'Say why (at least 3 characters)'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _reason == null ? null : _lift,
                      style: FilledButton.styleFrom(
                        backgroundColor: approveGreen(context),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const OneLine(Text('Lift suspension')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
