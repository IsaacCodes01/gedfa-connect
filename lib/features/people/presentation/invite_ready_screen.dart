import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/constants/app_links.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/open_link.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/people/domain/invite.dart';
import 'package:go_router/go_router.dart';

/// "a referee" or "an FA official".
String roleWithArticle(UserRole role) =>
    role == UserRole.faAdmin ? 'an FA official' : 'a referee';

/// The message the FA sends. Plain text, so it works on WhatsApp and SMS.
String inviteMessage(Invite invite) {
  final firstName = invite.name.trim().split(RegExp(r'\s+')).first;
  final expires = invite.expiresAt;
  return 'Hello $firstName, Gomoa East District FA has invited you to '
      'GEDFA Connect as ${roleWithArticle(invite.role)}.\n\n'
      '1. Open $appWebLink\n'
      '2. Create an account with ${invite.email}\n'
      '3. Tap "Accept invitation".'
      '${expires == null ? '' : ' The invitation expires on ${formatDate(expires)}.'}';
}

/// FA: an invitation, ready to share (also opened from the Invited tab).
class InviteReadyScreen extends ConsumerStatefulWidget {
  const InviteReadyScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<InviteReadyScreen> createState() => _InviteReadyScreenState();
}

class _InviteReadyScreenState extends ConsumerState<InviteReadyScreen> {
  bool _busy = false;

  Future<void> _copy(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (mounted) AppToast.success(context, 'Message copied.');
  }

  Future<void> _cancel(Invite invite) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this invitation?'),
        content: Text(
          '${invite.name} will no longer be able to accept it. You can '
          'invite them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel invitation'),
          ),
        ],
      ),
    );
    final me = ref.read(authRepositoryProvider).currentUser;
    if (ok != true || me == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(peopleRepositoryProvider).cancel(invite, by: me);
      if (!mounted) return;
      AppToast.success(context, 'Invitation cancelled.');
      context.go(Routes.adminPeople);
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteAsync = ref.watch(inviteProvider(widget.email));

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'Invitation',
        leading: CloseButton(onPressed: () => context.go(Routes.adminPeople)),
      ),
      body: inviteAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: appErrorMessage(error)),
        data: (invite) => switch (invite) {
          null => const EmptyView(
              icon: Icons.mark_email_unread_outlined,
              title: 'No invitation',
              message: 'It was cancelled or declined.',
            ),
          final Invite i when i.status == 'accepted' => EmptyView(
              icon: Icons.how_to_reg_rounded,
              title: 'Accepted',
              message: '${i.name} accepted and is now '
                  '${roleWithArticle(i.role)}.',
            ),
          final Invite i => _body(i),
        },
      ),
    );
  }

  Widget _body(Invite invite) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isChairman = ref.watch(appUserProvider).value?.isChairman ?? false;
    final canCancel = invite.role == UserRole.referee || isChairman;
    final message = inviteMessage(invite);
    final green = isDark ? const Color(0xFF7BE3B0) : AppColors.ghanaGreen;

    final (icon, color, title) = invite.isExpired
        ? (Icons.schedule_rounded, scheme.error, 'This invitation has expired')
        : (
            Icons.check_rounded,
            green,
            '${invite.name} is invited as ${roleWithArticle(invite.role)}'
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
      children: [
        ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                invite.isExpired
                    ? 'Cancel it, then invite ${invite.name} again to send a '
                        'new one.'
                    : 'Send the message below. The role is added only when '
                        'they sign up with ${invite.email} and accept.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (!invite.isExpired) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.outline),
                  ),
                  child: SelectableText(
                    message,
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  // Directly in the tap (no await first), so Safari allows it
                  onPressed: () => openLink(whatsAppShareLink(message)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E8E5A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Share on WhatsApp'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _copy(message),
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copy message'),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can share it again later from People and roles › '
                  'Invited.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (canCancel) ...[
                const SizedBox(height: 22),
                TextButton(
                  onPressed: _busy ? null : () => _cancel(invite),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  child: const Text('Cancel invitation'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
