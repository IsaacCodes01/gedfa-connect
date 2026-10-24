import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/count_tabs.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/domain/invite.dart';
import 'package:gedfa_connect/features/people/domain/member.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart'
    show PersonAvatar;
import 'package:go_router/go_router.dart';

enum _Tab { fa, referees, invited }

/// FA, More › People and roles: FA admins, referees and open invitations.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  _Tab _tab = _Tab.fa;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final invitesAsync = ref.watch(pendingInvitesProvider);

    Widget body;
    final error = membersAsync.error ?? invitesAsync.error;
    if (error != null) {
      body = ErrorView(message: appErrorMessage(error));
    } else if (!membersAsync.hasValue || !invitesAsync.hasValue) {
      body = const LoadingView();
    } else {
      body = _body(membersAsync.requireValue, invitesAsync.requireValue);
    }

    return Scaffold(
      appBar: const GedfaAppBar(
        title: 'People and roles',
        subtitle: 'Gomoa East District FA',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.adminInvite),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite someone'),
      ),
      body: body,
    );
  }

  Widget _body(List<Member> members, List<Invite> invites) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final myUid = ref.watch(authStateProvider).value?.uid;

    final fa = members.where((m) => m.role == UserRole.faAdmin).toList();
    final referees = members.where((m) => m.role == UserRole.referee).toList();

    final hint = switch (_tab) {
      _Tab.fa => 'FA admins approve teams and players. Only the chairman can '
          'invite or remove FA officials.',
      _Tab.referees => 'Referees will see their assigned matches and send '
          'match reports (Phase 4).',
      _Tab.invited => 'Invitations wait until the person signs up with that '
          'email and accepts. Tap one to share it again or cancel it.',
    };

    final rows = switch (_tab) {
      _Tab.fa => [
          for (final m in fa)
            _PersonRow(
              name: m.name.isEmpty ? m.email : m.name,
              isYou: m.uid == myUid,
              subtitle: m.email,
              chip: _RoleChip.forMember(m),
              onTap: () => context.go(Routes.adminMember(m.uid)),
            ),
        ],
      _Tab.referees => [
          for (final m in referees)
            _PersonRow(
              name: m.name,
              isYou: m.uid == myUid,
              subtitle: m.email,
              chip: _RoleChip.forMember(m),
              onTap: () => context.go(Routes.adminMember(m.uid)),
            ),
        ],
      _Tab.invited => [
          for (final i in invites)
            _PersonRow(
              name: i.name,
              isYou: false,
              subtitle: '${roleLabelFor(i.role)} · ${_inviteState(i)}',
              chip: i.isExpired ? _RoleChip.expired() : _RoleChip.waiting(),
              onTap: () => context.go(Routes.adminInviteReady(i.email)),
            ),
        ],
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
      children: [
        ResponsiveCenter(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CountTabs<_Tab>(
                tabs: [
                  CountTab(value: _Tab.fa, label: 'FA admins', count: fa.length),
                  CountTab(
                    value: _Tab.referees,
                    label: 'Referees',
                    count: referees.length,
                  ),
                  CountTab(
                    value: _Tab.invited,
                    label: 'Invited',
                    count: invites.length,
                    highlight: true,
                  ),
                ],
                selected: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  hint,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyView(
                    icon: Icons.people_outline_rounded,
                    title: switch (_tab) {
                      _Tab.fa => 'No FA admins',
                      _Tab.referees => 'No referees yet',
                      _Tab.invited => 'No open invitations',
                    },
                    message: 'Tap "Invite someone" to add people.',
                  ),
                )
              else
                for (final row in rows) ...[row, const SizedBox(height: 8)],
            ],
          ),
        ),
      ],
    );
  }

  static String _inviteState(Invite invite) {
    if (invite.isExpired) return 'expired';
    final days = invite.daysLeft;
    return days == 1 ? 'expires in 1 day' : 'expires in $days days';
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.name,
    required this.isYou,
    required this.subtitle,
    required this.chip,
    required this.onTap,
  });

  final String name;
  final bool isYou;
  final String subtitle;
  final _RoleChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              PersonAvatar(name: name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: name,
                        children: [
                          if (isYou)
                            TextSpan(
                              text: ' (you)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              chip,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured label: Chairman (gold), FA official (blue),
/// Referee (green), Waiting (yellow), Expired (red).
class _RoleChip extends StatelessWidget {
  const _RoleChip(this.label, this.kind);

  factory _RoleChip.forMember(Member m) => _RoleChip(
        m.roleLabel,
        m.isChairman
            ? _ChipKind.gold
            : (m.role == UserRole.referee ? _ChipKind.green : _ChipKind.blue),
      );
  factory _RoleChip.waiting() => const _RoleChip('Waiting', _ChipKind.yellow);
  factory _RoleChip.expired() => const _RoleChip('Expired', _ChipKind.red);

  final String label;
  final _ChipKind kind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (bg, ink) = switch (kind) {
      _ChipKind.gold => (AppColors.ghanaGold, const Color(0xFF3A2C00)),
      _ChipKind.blue => isDark
          ? (const Color(0xFF1E3A5F), const Color(0xFFCFE4FB))
          : (const Color(0xFFE3EEFA), const Color(0xFF0B3F7A)),
      _ChipKind.green => isDark
          ? (const Color(0xFF123D2B), const Color(0xFF7BE3B0))
          : (AppColors.approvedBg, AppColors.approvedText),
      _ChipKind.yellow => isDark
          ? (const Color(0xFF3D3410), const Color(0xFFF5D25B))
          : (AppColors.pendingBg, AppColors.pendingText),
      _ChipKind.red => isDark
          ? (const Color(0xFF4A1820), const Color(0xFFFF9DA6))
          : (AppColors.rejectedBg, AppColors.rejectedText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: ink,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

enum _ChipKind { gold, blue, green, yellow, red }
