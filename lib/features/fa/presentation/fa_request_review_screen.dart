import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/open_link.dart';
import 'package:gedfa_connect/core/utils/phone_call.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/core/widgets/status_badge.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/file_upload_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:go_router/go_router.dart';

/// FA: everything a club sent, to check before approving or rejecting.
/// While the request is pending, Reject and Approve sit at the bottom.
class FaRequestReviewScreen extends ConsumerWidget {
  const FaRequestReviewScreen({super.key, required this.uid});

  /// The requester's uid = the request's document ID.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(teamRequestByUidProvider(uid));
    final request = requestAsync.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Review request',
        leading: BackButton(onPressed: () => context.go(Routes.admin)),
      ),
      bottomNavigationBar:
          request != null && request.status == ApprovalStatus.pending
              ? _ReviewActions(request: request)
              : null,
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

              const SectionTitle('Club status'),
              _ClubStatus(request: request),
              const SizedBox(height: 22),

              const SectionTitle('Club details'),
              TileGroup(
                children: [
                  DetailRow('Home ground', request.homeGround),
                  DetailRow(
                    'Directions',
                    directions == null || directions.isEmpty
                        ? null
                        : directions,
                  ),
                  DetailRow('Year founded', request.yearFounded?.toString()),
                  DetailRow(
                    'Club email',
                    email == null || email.isEmpty ? null : email,
                  ),
                  DetailRow('Short name', request.shortName),
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
        CheckLine(
          ok: holdsName.value,
          okText: 'Team name is free and reserved for this club',
          badText: 'Name reservation is missing. Check before approving.',
          waitingText: 'Checking the team name…',
        ),
        // The rules only accept requests from confirmed emails.
        const CheckLine(
          ok: true,
          okText: 'Sent from a confirmed email address',
        ),
        if (request.clubStatus == ClubStatus.newClub)
          CheckLine(
            ok: request.letterUrl != null,
            okText: 'New club: letter to the chairman attached',
            badText: 'New club, but the letter is missing',
          ),
        CheckLine(
          ok: hasRequiredOfficials,
          okText: 'Team manager and head coach given',
          badText: 'Team manager or head coach is missing',
        ),
      ],
    );
  }
}

// ── Club status (2.13): in the district or new, letter, licence ─────────

class _ClubStatus extends StatelessWidget {
  const _ClubStatus({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final isNew = request.clubStatus == ClubStatus.newClub;
    final letter = request.letterUrl;
    final licence = request.licenceUrl;

    return TileGroup(
      children: [
        DetailRow('Type', request.clubStatus.shortLabel),
        if (isNew) DetailRow('Last season', request.lastLeague),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              if (isNew) ...[
                FileUploadRow(
                  title: 'Letter to the chairman',
                  subtitle: letter == null ? 'Not sent' : 'PDF',
                  buttonLabel: 'Open',
                  hasFile: letter != null,
                  showError: letter == null,
                  // openLink straight from the tap (iPhone Safari needs it)
                  onPressed: letter == null ? null : () => openLink(letter),
                ),
                const SizedBox(height: 10),
              ],
              FileUploadRow(
                title: 'Club licence',
                subtitle: licence == null
                    ? 'Not given (optional)'
                    : request.licenceIsPdf
                        ? 'PDF'
                        : 'Photo',
                buttonLabel: 'Open',
                isPdf: licence == null || request.licenceIsPdf,
                hasFile: licence != null,
                onPressed: licence == null ? null : () => openLink(licence),
              ),
            ],
          ),
        ),
      ],
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

  /// Copies the number, for when calling isn't possible (e.g. on a laptop).
  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: official.phone));
    if (context.mounted) AppToast.success(context, 'Number copied.');
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
                  official.roleText,
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
          if (official.phone.isNotEmpty) ...[
            IconButton(
              tooltip: 'Copy number',
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
            IconButton.filledTonal(
              tooltip: 'Call ${official.name}',
              // callPhone runs straight from the tap (no await before it),
              // which iPhone Safari needs to allow the call.
              onPressed: () => callPhone(official.phone),
              icon: const Icon(Icons.call_outlined),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Approve / Reject (2.2) ───────────────────────────────────────────────

/// The bar at the bottom: Reject (outlined red) and Approve team (green).
class _ReviewActions extends ConsumerStatefulWidget {
  const _ReviewActions({required this.request});

  final TeamRequest request;

  @override
  ConsumerState<_ReviewActions> createState() => _ReviewActionsState();
}

class _ReviewActionsState extends ConsumerState<_ReviewActions> {
  bool _busy = false;

  String? get _faUid => ref.read(authRepositoryProvider).currentUser?.uid;

  /// Friendly message when Firestore refuses the change.
  String _messageFor(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return "Couldn't save. A team with this name may already exist, or "
          'the club changed the request. Go back and open it again.';
    }
    return appErrorMessage(error);
  }

  Future<void> _approve() async {
    final request = widget.request;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(request: request),
    );
    final faUid = _faUid;
    if (ok != true || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(teamRequestRepositoryProvider)
          .approve(request, faUid: faUid);
      if (!mounted) return;
      AppToast.success(context, '${request.teamName} approved.');
      context.go(Routes.admin);
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final request = widget.request;
    final reason = await showReasonSheet(
      context,
      title: 'Reject ${request.teamName}?',
      message: 'The club will see this reason on its request and may correct '
          'and resubmit.',
      fieldLabel: 'Reason for the club',
      quickReasons: const [
        'Logo is not clear',
        'The letter to the chairman is missing or unclear',
        'Team name is already used in the district',
        "Officials' phone numbers are missing",
        'Home ground is not approved by the FA',
      ],
    );
    final faUid = _faUid;
    if (reason == null || faUid == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(teamRequestRepositoryProvider)
          .reject(request.uid, reason: reason, faUid: faUid);
      if (!mounted) return;
      AppToast.success(
        context,
        'Request rejected. The club can see your reason.',
      );
      context.go(Routes.admin);
    } catch (error) {
      if (mounted) AppToast.error(context, _messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReviewActionsBar(
      approveLabel: 'Approve team',
      busy: _busy,
      onReject: _reject,
      onApprove: _approve,
    );
  }
}

/// "Approve Gomoa United FC?" with exactly what will happen.
class _ApproveDialog extends StatelessWidget {
  const _ApproveDialog({required this.request});

  final TeamRequest request;

  @override
  Widget build(BuildContext context) {
    final competitions =
        request.categories.map((c) => c.label).join(' and ');

    return AlertDialog(
      title: Text('Approve ${request.teamName}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This will:'),
          const SizedBox(height: 8),
          DialogBullet('Create the team ${request.teamName} ($competitions)'),
          DialogBullet("Make the club's account the team admin"),
          DialogBullet('Let them start adding players straight away'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            // The app theme makes filled buttons full-width; not in a dialog.
            minimumSize: const Size(96, 44),
            backgroundColor: approveGreen(context),
            foregroundColor: Colors.white,
          ),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
