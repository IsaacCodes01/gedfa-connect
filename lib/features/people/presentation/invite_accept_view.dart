import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/domain/invite.dart';
import 'package:gedfa_connect/features/people/domain/member.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';

/// What an invited person sees after signing up (instead of "Register
/// your team"): who invited them, for which role, Accept or Decline.
///
/// After Accept their user document has a role, and the router takes them
/// to the FA area or the referee home by itself.
class InviteAcceptView extends ConsumerStatefulWidget {
  const InviteAcceptView({super.key, required this.invite});

  final Invite invite;

  @override
  ConsumerState<InviteAcceptView> createState() => _InviteAcceptViewState();
}

class _InviteAcceptViewState extends ConsumerState<InviteAcceptView> {
  bool _busy = false;

  Future<void> _accept() async {
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(peopleRepositoryProvider).accept(widget.invite, me: me);
      if (mounted) AppToast.success(context, 'Welcome to GEDFA Connect.');
      // No navigation here: the new role makes the router move us.
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline the invitation?'),
        content: const Text(
          'The FA will see that you declined. They can invite you again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    final me = ref.read(authRepositoryProvider).currentUser;
    if (ok != true || me == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(peopleRepositoryProvider).decline(widget.invite, me: me);
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
    final invite = widget.invite;
    final email = ref.watch(authStateProvider).value?.email ?? invite.email;
    final expires = invite.expiresAt;

    final roleText = invite.role == UserRole.faAdmin
        ? 'As an FA official you will review and approve teams and players, '
            'and can invite referees.'
        : 'As a referee you will see the matches you are assigned to and send '
            'match reports to the FA.';

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Text(
                label,
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const FlagStripe(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
                children: [
                  ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.mark_email_read_outlined,
                            size: 36,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You have been invited',
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Signed in as $email',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        TileGroup(
                          children: [
                            row('Role', roleLabelFor(invite.role)),
                            row('Association', 'Gomoa East District FA'),
                            row('Invited by', invite.invitedByName),
                            if (expires != null)
                              row('Expires', formatDate(expires)),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                roleText,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _accept,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text('Accept invitation'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _busy ? null : _decline,
                          child: const Text('Decline'),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () =>
                              ref.read(authRepositoryProvider).signOut(),
                          child: const Text('Not you? Log out'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
