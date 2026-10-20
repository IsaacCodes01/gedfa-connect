import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// FA: everything a club sent, to check before approving or rejecting.
/// (Approve and Reject arrive in 2.2.)
class FaRequestReviewScreen extends ConsumerWidget {
  const FaRequestReviewScreen({super.key, required this.uid});

  /// The requester's uid = the request's document ID.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(teamRequestByUidProvider(uid));

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Review request',
        leading: BackButton(onPressed: () => context.go(Routes.admin)),
      ),
      body: requestAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (request) => request == null
            ? const EmptyView(
                icon: Icons.search_off_rounded,
                title: 'Request not found',
                message: 'It may have been withdrawn.',
              )
            : _ReviewBody(request: request),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final directions = request.homeGroundDirections;
    final email = request.email;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(request: request),
              const SizedBox(height: 16),
              _Checks(request: request),
              const SizedBox(height: 22),

              const SectionTitle('Club details'),
              TileGroup(
                children: [
                  _DetailRow('Home ground', request.homeGround),
                  _DetailRow(
                    'Directions',
                    directions == null || directions.isEmpty
                        ? null
                        : directions,
                  ),
                  _DetailRow('Year founded', request.yearFounded?.toString()),
                  _DetailRow(
                    'Club email',
                    email == null || email.isEmpty ? null : email,
                  ),
                  _DetailRow('Short name', request.shortName),
                ],
              ),
              const SizedBox(height: 22),

              const SectionTitle('Kits'),
              _Kits(request: request),
              const SizedBox(height: 22),

              const SectionTitle('Officials'),
              TileGroup(
                children: [
                  for (final official in request.officials)
                    _OfficialRow(official: official),
                ],
              ),
              const SizedBox(height: 22),

              if (request.status == ApprovalStatus.pending)
                InfoBox(
                  icon: Icons.info_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  child: const Text(
                    'Approve and Reject arrive in the next update (2.2).',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header: logo, name, competitions, status, when sent ─────────────────

class _Header extends StatelessWidget {
  const _Header({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sent = request.createdAt;
    final changed = request.updatedAt;
    final reason = request.rejectionReason;

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            children: [
              TeamLogo(
                label: initialsFor(request.teamName),
                color: request.homeKit.primary,
                url: request.logoUrl,
                size: 76,
              ),
              const SizedBox(height: 10),
              Text(
                request.teamName,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${request.shortName} · ${request.town}',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              CompetitionChips(competitions: request.categories, center: true),
              const SizedBox(height: 10),
              StatusBadge(status: request.status),
              if (sent != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Sent ${formatDateTime(sent)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              // Shown when the club edited the request after sending it
              if (sent != null &&
                  changed != null &&
                  changed.difference(sent).inMinutes > 1)
                Text(
                  'Last changed ${formatDateTime(changed)}',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              if (request.status == ApprovalStatus.rejected &&
                  reason != null &&
                  reason.isNotEmpty) ...[
                const SizedBox(height: 10),
                InfoBox(
                  icon: Icons.error_outline_rounded,
                  color: scheme.error,
                  child: Text('Rejected: $reason'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── "Checked by the app" ─────────────────────────────────────────────────

class _Checks extends ConsumerWidget {
  const _Checks({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holdsName = ref.watch(
      requestHoldsNameProvider(
        (uid: request.uid, teamName: request.teamName),
      ),
    );
    final hasRequiredOfficials =
        request.officialFor(OfficialRole.teamManager) != null &&
            request.officialFor(OfficialRole.headCoach) != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckLine(
          ok: holdsName.value,
          okText: 'Team name is free and reserved for this club',
          badText: 'Name reservation is missing. Check before approving.',
          waitingText: 'Checking the team name…',
        ),
        // The rules only accept requests from confirmed emails.
        const _CheckLine(
          ok: true,
          okText: 'Sent from a confirmed email address',
        ),
        _CheckLine(
          ok: hasRequiredOfficials,
          okText: 'Team manager and head coach given',
          badText: 'Team manager or head coach is missing',
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({
    required this.ok,
    required this.okText,
    this.badText = '',
    this.waitingText = '',
  });

  /// true = passed, false = failed, null = still checking
  final bool? ok;
  final String okText;
  final String badText;
  final String waitingText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final green = isDark ? const Color(0xFF7BE3B0) : const Color(0xFF006B3F);

    final (icon, color, text) = switch (ok) {
      true => (Icons.check_circle_rounded, green, okText),
      false => (Icons.warning_amber_rounded, scheme.error, badText),
      null => (Icons.hourglass_empty_rounded, scheme.onSurfaceVariant,
          waitingText),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Club details row ─────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String? value; // null = not given

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = this.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value ?? 'Not given',
              style: value == null
                  ? textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    )
                  : textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kits ─────────────────────────────────────────────────────────────────

class _Kits extends StatelessWidget {
  const _Kits({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final kits = <(String, Kit)>[
      ('Home', request.homeKit),
      ('Away', request.awayKit),
      if (request.thirdKit case final kit?) ('Third', kit),
      ('Goalkeeper', request.goalkeeperKit),
      if (request.goalkeeperKit2 case final kit?) ('GK 2', kit),
    ];

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final (label, kit) in kits)
                SizedBox(
                  width: 76,
                  child: Column(
                    children: [
                      KitPreview(
                        kit: kit,
                        width: 60,
                        semanticLabel: '$label kit',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Officials ────────────────────────────────────────────────────────────

class _OfficialRow extends StatelessWidget {
  const _OfficialRow({required this.official});

  final Official official;

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: official.phone);
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      AppToast.error(context, "Couldn't start a call on this device.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final licence = official.licence;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  official.role.label,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  official.name,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  [
                    official.phone,
                    if (licence != null && licence.isNotEmpty) licence,
                  ].join(' · '),
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (official.phone.isNotEmpty)
            IconButton.filledTonal(
              tooltip: 'Call ${official.name}',
              onPressed: () => _call(context),
              icon: const Icon(Icons.call_outlined),
            ),
        ],
      ),
    );
  }
}
