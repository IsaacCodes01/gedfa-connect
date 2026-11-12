import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';

/// FA › Teams › Changes, at the top: corrections the FA asked for
/// (2.11b, mockup B4). Sent back first (the FA marks them Done or asks
/// again), then the ones the team is still on ("Waiting for …").
class FaCorrectionsView extends ConsumerWidget {
  const FaCorrectionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests =
        ref.watch(allCorrectionRequestsProvider).value ?? const [];
    final teams = ref.watch(allTeamsProvider).value ?? const <Team>[];

    DateTime at(DateTime? time) => time ?? DateTime(0);
    final sentBack = requests
        .where((r) => r.status == CorrectionStatus.sentBack)
        .toList()
      ..sort((a, b) => at(a.sentBackAt).compareTo(at(b.sentBackAt)));
    final asked = requests
        .where((r) => r.status == CorrectionStatus.asked)
        .toList()
      ..sort((a, b) => at(a.askedAt).compareTo(at(b.askedAt)));
    if (sentBack.isEmpty && asked.isEmpty) return const SizedBox.shrink();

    final n = sentBack.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
          child: Text(
            'CORRECTIONS · $n SENT BACK',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
        ),
        for (final request in [...sentBack, ...asked]) ...[
          _CorrectionCard(
            request: request,
            team: teams.where((t) => t.id == request.teamId).firstOrNull,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CorrectionCard extends ConsumerStatefulWidget {
  const _CorrectionCard({required this.request, required this.team});

  final CorrectionRequest request;
  final Team? team;

  @override
  ConsumerState<_CorrectionCard> createState() => _CorrectionCardState();
}

class _CorrectionCardState extends ConsumerState<_CorrectionCard> {
  bool _busy = false;

  Future<void> _done() async {
    final uid = ref.read(authRepositoryProvider).currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(correctionRequestRepositoryProvider)
          .markDone(widget.request, faUid: uid);
      if (mounted) {
        AppToast.success(
          context,
          'Done. ${widget.request.teamName} has been told.',
        );
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final request = widget.request;
    final team = widget.team;
    final name = team?.name ?? request.teamName;
    final isSentBack = request.status == CorrectionStatus.sentBack;
    final sentBackAt = request.sentBackAt;
    final askedAt = request.askedAt;
    final requestUid = team?.requestUid;

    final status = isSentBack
        ? 'Correction sent back'
            '${sentBackAt == null ? '' : ' · ${formatDayMonth(sentBackAt)}'}'
        : 'Waiting for $name'
            '${askedAt == null ? '' : ' · asked ${formatDayMonth(askedAt)}'}';

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        // The FA's team page, to look at what the team changed
        onTap: requestUid == null
            ? null
            : () => context.pushKeepingHome(Routes.adminRequest(requestUid)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TeamLogo(
                    label: initialsFor(name),
                    color: team?.logoColor ?? scheme.primary,
                    url: team?.logoUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          status,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'You asked: ${request.itemsText}. "${request.message}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (isSentBack) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => context.pushKeepingHome(
                                  Routes.adminAskCorrection(request.teamId),
                                ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: const OneLine(Text('Ask again')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy ? null : _done,
                        style: FilledButton.styleFrom(
                          backgroundColor: approveGreen(context),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const OneLine(Text('Done')),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
