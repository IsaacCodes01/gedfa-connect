import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/core/constants/season.dart';
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
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/suspension_widgets.dart';
import 'package:gedfa_connect/features/teams/data/suspension_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/suspension.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/correction_widgets.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/review_widgets.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/presentation/widgets/fa_payment_card.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/core/utils/team_name_key.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_correction_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_profile_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/features/teams/domain/team_correction.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/previous_name_pill.dart';
import 'package:gedfa_connect/features/teams/domain/club_status.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/competition_picker.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/file_upload_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/colour_pair_row.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';
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
        // An approved team: Ask the team to correct… (2.11b, B1)
        actions: request != null && request.status == ApprovalStatus.approved
            ? [_TeamMenu(teamId: teamNameKey(request.teamName))]
            : null,
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
    // An approved team: the team as it is now, with corrections (2.11a)
    if (request.status == ApprovalStatus.approved) {
      return _ApprovedBody(request: request);
    }
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

              SectionTitle('${Season.label(Season.current)} season fee'),
              FaPaymentCard(
                requestUid: request.uid,
                teamName: request.teamName,
                requestPending: request.status == ApprovalStatus.pending,
              ),
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

// ── An approved team (2.11a, mockup A1) ──────────────────────────────────

/// The team as it is NOW (its own edits since 2.10a included), not what
/// it registered with. The FA corrects misspellings and obvious mistakes
/// here: the club name (✎ Correct name) and the club details (Edit).
/// Below: the season fee and the registration (club status, letter,
/// licence).
class _ApprovedBody extends ConsumerStatefulWidget {
  const _ApprovedBody({required this.request});

  final TeamRequest request;

  @override
  ConsumerState<_ApprovedBody> createState() => _ApprovedBodyState();
}

class _ApprovedBodyState extends ConsumerState<_ApprovedBody> {
  bool _busy = false;

  /// The team ID is the key of the name it registered with (2.2)
  String get _teamId => teamNameKey(widget.request.teamName);

  Future<void> _correctName(TeamDetails team) async {
    final result = await showNameCorrectionSheet(
      context,
      teamId: _teamId,
      name: team.teamName,
    );
    if (result == null || !mounted) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(teamCorrectionRepositoryProvider).correct(
            teamId: _teamId,
            teamName: team.teamName,
            section: CorrectionSection.name,
            changes: {'name': result.name},
            lines: [correctionLine('Club name', team.teamName, result.name)],
            reason: result.reason,
            faUid: user.uid,
            faName: user.displayName,
          );
      if (mounted) {
        AppToast.success(context, 'Corrected. ${result.name} has been told.');
      }
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    // The registration until the team has loaded
    final team = ref.watch(teamDetailsProvider(_teamId)).value ?? request;
    final corrections =
        ref.watch(teamCorrectionsProvider(_teamId)).value ?? const [];
    final fixed = {for (final c in corrections) ...c.fields};
    final directions = team.homeGroundDirections;
    final email = team.email;
    final liveTeam = ref.watch(teamByIdProvider(_teamId)).value;
    final suspension = liveTeam?.suspension;
    final isChairman = ref.watch(appUserProvider).value?.isChairman ?? false;

    DetailRow row(String label, String? value, String field) => DetailRow(
          label,
          value == null || value.isEmpty ? null : value,
          badge: fixed.contains(field) ? const FaFixedPill() : null,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ResponsiveCenter(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                request: request,
                onCorrectName: _busy ? null : () => _correctName(team),
              ),
              // Suspended (2.11c, C3); Lift for the chairman
              if (liveTeam != null && suspension != null && liveTeam.isSuspended)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SuspendedBanner(
                    title: switch (suspension.since) {
                      final since? => 'Suspended since ${formatDayMonth(since)}',
                      null => 'Suspended',
                    },
                    suspension: suspension,
                    onLift: isChairman
                        ? () =>
                            liftSuspension(context, ref, liveTeam, suspension)
                        : null,
                  ),
                ),
              const SizedBox(height: 22),

              _EditTitle(
                'Club details',
                onEdit: _busy
                    ? null
                    : () => context.push(Routes.adminCorrectDetails(_teamId)),
              ),
              TileGroup(
                children: [
                  row('Town', team.town, 'town'),
                  row('Home ground', team.homeGround, 'homeGround'),
                  row('Directions', directions, 'homeGroundDirections'),
                  row('Year founded', team.yearFounded?.toString(),
                      'yearFounded'),
                  row('Club email', email, 'email'),
                ],
              ),
              const SizedBox(height: 22),

              const SectionTitle('Officials'),
              TileGroup(
                children: [
                  for (final official in team.officials)
                    _OfficialRow(official: official),
                  _AskHint(teamId: _teamId, item: CorrectionItem.officials),
                ],
              ),
              const SizedBox(height: 22),

              const SectionTitle('Colours and kits'),
              _Kits(request: team),
              _AskHint(teamId: _teamId, item: CorrectionItem.kits),

              CorrectionsLog(teamId: _teamId),
              SuspensionHistory(teamId: _teamId),
              const SizedBox(height: 22),

              SectionTitle('${Season.label(Season.current)} season fee'),
              FaPaymentCard(
                requestUid: request.uid,
                teamName: team.teamName,
                requestPending: false,
              ),
              const SizedBox(height: 22),

              const SectionTitle('Registration'),
              _ClubStatus(request: request),
            ],
          ),
        ),
      ],
    );
  }
}

/// The ⋮ menu of an approved team (2.11b, B1). While the team is still
/// correcting the last request, the FA waits for it.
class _TeamMenu extends ConsumerWidget {
  const _TeamMenu({required this.teamId});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(correctionRequestProvider(teamId)).value;
    final waiting = request?.status == CorrectionStatus.asked;
    final team = ref.watch(teamByIdProvider(teamId)).value;
    // Suspend and lift: the chairman only (2.11c)
    final isChairman = ref.watch(appUserProvider).value?.isChairman ?? false;
    final suspension = team?.suspension;

    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) {
        if (team == null) return;
        switch (value) {
          case 'ask':
            context.push(Routes.adminAskCorrection(teamId));
          case 'suspend':
            suspendTeam(context, ref, team);
          case 'lift' when suspension != null:
            liftSuspension(context, ref, team, suspension);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'ask',
          enabled: !waiting,
          child: Text(
            waiting
                ? 'Waiting for the team to correct'
                : 'Ask the team to correct…',
          ),
        ),
        if (isChairman && team != null)
          team.isSuspended
              ? const PopupMenuItem(
                  value: 'lift',
                  child: Text('Lift suspension…'),
                )
              : PopupMenuItem(
                  value: 'suspend',
                  child: Text(
                    'Suspend team…',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
      ],
    );
  }
}

/// The chairman suspends [team] (C1): the box, then one batch.
Future<void> suspendTeam(BuildContext context, WidgetRef ref, Team team) async {
  final input = await showSuspendSheet(context, teamName: team.name);
  if (input == null || !context.mounted) return;
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return;
  try {
    await ref.read(suspensionRepositoryProvider).suspend(
          teamId: team.id,
          teamName: team.name,
          reason: input.reason,
          lastDay: input.lastDay,
          chairUid: user.uid,
          chairName: user.displayName,
        );
    if (context.mounted) {
      AppToast.success(
        context,
        '${team.name} is suspended. They have been told.',
      );
    }
  } catch (error) {
    if (context.mounted) AppToast.error(context, appErrorMessage(error));
  }
}

/// The chairman lifts [suspension] (C4), with why.
Future<void> liftSuspension(
  BuildContext context,
  WidgetRef ref,
  Team team,
  Suspension suspension,
) async {
  final input = await showLiftSheet(context, teamName: team.name);
  if (input == null || !context.mounted) return;
  final user = ref.read(authRepositoryProvider).currentUser;
  if (user == null) return;
  try {
    await ref.read(suspensionRepositoryProvider).lift(
          teamId: team.id,
          teamName: team.name,
          suspension: suspension,
          reason: input.reason,
          note: input.note,
          chairUid: user.uid,
          chairName: user.displayName,
        );
    if (context.mounted) {
      AppToast.success(
        context,
        'Suspension lifted. ${team.name} has been told.',
      );
    }
  } catch (error) {
    if (context.mounted) AppToast.error(context, appErrorMessage(error));
  }
}

/// "Wrong? Ask the team to correct it." under officials and kits: the FA
/// doesn't correct those itself (2.11a).
class _AskHint extends StatelessWidget {
  const _AskHint({required this.teamId, required this.item});

  final String teamId;
  final CorrectionItem item;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => context.push(
          Routes.adminAskCorrection(teamId, item: item.name),
        ),
        child: const Text('Wrong? Ask the team to correct it.'),
      ),
    );
  }
}

/// "CLUB DETAILS                ✎ Edit"
class _EditTitle extends StatelessWidget {
  const _EditTitle(this.text, {required this.onEdit});

  final String text;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(text)),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextButton.icon(
            onPressed: onEdit,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ),
      ],
    );
  }
}

// ── Header: logo, name, competitions, status, when sent ─────────────────

/// The club at the top. An approved team shows its name, logo, short name
/// and competitions as they are NOW, with "Previously …" if renamed
/// (2.10c), and "✎ Correct name" for the FA (2.11a).
class _Header extends ConsumerWidget {
  const _Header({required this.request, this.onCorrectName});

  final TeamRequest request;

  /// Approved teams only; null greys it out while saving
  final VoidCallback? onCorrectName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sent = request.createdAt;
    final changed = request.updatedAt;
    final reason = request.rejectionReason;

    final current = request.status == ApprovalStatus.approved
        ? ref.watch(currentTeamProvider((
            teamId: teamNameKey(request.teamName),
            registeredName: request.teamName,
          )))
        : null;
    final team = current?.team;
    final name = team?.name ?? request.teamName;
    final previousName = current?.previousName;

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            children: [
              TeamLogo(
                label: initialsFor(name),
                color: team?.logoColor ?? request.logoColor,
                url: team?.logoUrl ?? request.logoUrl,
                size: 76,
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (previousName != null) ...[
                const SizedBox(height: 4),
                PreviousNamePill(name: previousName, maxWidth: 280),
                const SizedBox(height: 4),
              ],
              Text(
                '${team?.shortName ?? request.shortName} · '
                '${team?.town ?? request.town}',
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              CompetitionChips(
                competitions: team?.categories ?? request.categories,
                center: true,
              ),
              const SizedBox(height: 10),
              StatusBadge(status: request.status),
              if (request.status == ApprovalStatus.approved)
                TextButton.icon(
                  onPressed: onCorrectName,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Correct name'),
                ),
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

    // A club in both competitions has separate juvenile kits (2.13b)
    final sets = <(String?, Map<KitSlot, Kit>)>[
      (
        request.hasSeparateJuvenileKits ? 'Division' : null,
        request.divisionKits,
      ),
      if (request.hasSeparateJuvenileKits) ('Juvenile', request.juvenileKits),
    ];
    final colours = request.colours;

    return TileGroup(
      children: [
        for (final (title, kits) in sets)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '$title kits',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final MapEntry(key: slot, value: kit) in kits.entries)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          KitThumb(
                            kit: kit,
                            height: kit.isPhotos ? 56 : 78,
                            semanticLabel: slot.label,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slot.label.replaceAll(' kit', ''),
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (colours != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              children: [
                ColourPairRow(label: 'Home', pair: colours.home),
                ColourPairRow(label: 'Away', pair: colours.away),
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
        'Kit photos are not clear',
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
    // Approve unlocks once the first payment is confirmed (2.13c).
    // The security rules check the same thing.
    final feeStarted = ref
            .watch(feeSummaryProvider(widget.request.uid))
            .value
            ?.hasStarted ??
        false;

    return ReviewActionsBar(
      approveLabel: 'Approve team',
      busy: _busy,
      onReject: _reject,
      onApprove: feeStarted ? _approve : null,
      blockedText: feeStarted ? null : 'Confirm a payment first.',
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
