import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/domain/member.dart';
import 'package:gedfa_connect/features/people/domain/role_log_entry.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart'
    show PersonAvatar;
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// FA: one FA admin or referee, their role history, and Remove role.
class MemberScreen extends ConsumerStatefulWidget {
  const MemberScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends ConsumerState<MemberScreen> {
  bool _busy = false;

  Future<void> _remove(Member member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Remove ${member.name}'s role?"),
        content: Text(
          member.role == UserRole.faAdmin
              ? 'They will no longer be able to approve teams or players. '
                  'Their account stays, and their past approvals keep their '
                  'name. You can invite them again later.'
              : 'They will no longer see matches or send reports. Their '
                  'account stays. You can invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove role'),
          ),
        ],
      ),
    );
    final me = ref.read(authRepositoryProvider).currentUser;
    if (ok != true || me == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(peopleRepositoryProvider).removeRole(member, by: me);
      if (!mounted) return;
      AppToast.success(context, '${member.name} no longer has a role.');
      context.go(Routes.adminPeople);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(memberProvider(widget.uid));
    final member = memberAsync.value;

    return Scaffold(
      appBar: GedfaAppBar(
        title: member?.roleLabel ?? 'Person',
        leading: BackButton(onPressed: () => context.go(Routes.adminPeople)),
      ),
      body: memberAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (member) => member == null
            ? const EmptyView(
                icon: Icons.person_off_outlined,
                title: 'No role',
                message: 'This person no longer has an FA or referee role.',
              )
            : _body(member),
      ),
    );
  }

  Widget _body(Member member) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(appUserProvider).value;
    final isMe = me?.uid == member.uid;
    final iAmChairman = me?.isChairman ?? false;

    // Same as the security rules: never yourself, never the chairman;
    // referees by any FA admin, FA officials by the chairman only.
    final canRemove = !isMe &&
        !member.isChairman &&
        (member.role == UserRole.referee || iAmChairman);
    final note = member.isChairman
        ? "The chairman's role can't be removed in the app, so the FA always "
            'has at least one admin.'
        : isMe
            ? "You can't remove your own role. Ask the chairman."
            : !canRemove
                ? 'Only the chairman can remove FA officials.'
                : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TileGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                    child: Column(
                      children: [
                        PersonAvatar(name: member.name, size: 64),
                        const SizedBox(height: 10),
                        Text(
                          member.name.isEmpty ? member.email : member.name,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (member.email.isNotEmpty)
                          Text(
                            member.email,
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        const SizedBox(height: 8),
                        Chip(label: Text(member.roleLabel)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const SectionTitle('Role history'),
              _History(email: member.email),
              const SizedBox(height: 22),
              if (canRemove)
                OutlinedButton(
                  onPressed: _busy ? null : () => _remove(member),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error, width: 1.5),
                  ),
                  child: Text('Remove ${member.roleLabel} role'),
                ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    note,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The role-history lines for one email, oldest first.
class _History extends ConsumerWidget {
  const _History({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (email.isEmpty) {
      return Text(
        'Set up by hand in the Firebase console.',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    final entries = ref.watch(roleHistoryProvider(email)).value;
    if (entries == null) return const LinearProgressIndicator();
    if (entries.isEmpty) {
      return Text(
        'No history yet.',
        style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

    return TileGroup(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 10, color: _dot(entry, scheme)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_text(entry), style: textTheme.bodyMedium),
                      if (entry.at != null)
                        Text(
                          formatDateTime(entry.at!),
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

  static String _text(RoleLogEntry e) {
    final role = roleLabelFor(e.role);
    return switch (e.action) {
      'invited' => 'Invited as $role by ${e.byName}',
      'accepted' => 'Accepted the invitation',
      'declined' => 'Declined the invitation',
      'cancelled' => 'Invitation cancelled by ${e.byName}',
      'removed' => '$role role removed by ${e.byName}',
      _ => e.action,
    };
  }

  static Color _dot(RoleLogEntry e, ColorScheme scheme) => switch (e.action) {
        'accepted' => const Color(0xFF1E8E5A),
        'removed' || 'declined' || 'cancelled' => scheme.error,
        _ => scheme.primary,
      };
}
