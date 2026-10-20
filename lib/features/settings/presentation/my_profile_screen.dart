import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/settings/presentation/more_screen.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// Your own details: full name, email, password and the account itself.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final user = ref.watch(currentUserProvider).value;
    final appUser = ref.watch(appUserProvider).value;
    final team = ref.watch(myTeamProvider).value;
    final hasPassword = ref.watch(authRepositoryProvider).hasPassword;

    final name = user?.displayName ?? appUser?.displayName ?? '';
    final roleLine = [
      if (appUser?.role != null) appUser!.role!.label,
      if (team != null) team.name,
    ].join(' · ');

    return Scaffold(
      appBar: const GedfaAppBar(title: 'My profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Center(child: PersonAvatar(name: name, size: 76)),
                const SizedBox(height: 10),
                Text(
                  name.isEmpty ? 'Add your name' : name,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (roleLine.isNotEmpty)
                  Text(
                    roleLine,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 24),

                const SectionTitle('Personal'),
                _NameCard(name: name),
                const SizedBox(height: 22),

                const SectionTitle('Sign-in'),
                TileGroup(
                  children: [
                    _EmailRow(
                      email: user?.email ?? '',
                      confirmed: user?.emailVerified ?? false,
                      canChange: hasPassword,
                    ),
                    _PasswordRow(canChange: hasPassword),
                  ],
                ),
                if (!hasPassword) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'You sign in with Google, so Google manages your email '
                      'and password.',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                const SectionTitle('Account'),
                _DeleteAccountCard(
                  isTeamAdmin: appUser?.role == UserRole.teamAdmin,
                  teamName: team?.name,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full name ────────────────────────────────────────────────────────────

/// Shows the name with an Edit button; Edit turns it into a text field.
class _NameCard extends ConsumerStatefulWidget {
  const _NameCard({required this.name});

  final String name;

  @override
  ConsumerState<_NameCard> createState() => _NameCardState();
}

class _NameCardState extends ConsumerState<_NameCard> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _editing = false;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller.text = widget.name;
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (newName == widget.name) {
      setState(() => _editing = false);
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateName(newName);
      if (!mounted) return;
      setState(() => _editing = false);
      AppToast.success(context, 'Name saved.');
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

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: _editing
              ? Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _controller,
                        enabled: !_busy,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          helperText:
                              'First name and surname, as on official documents',
                        ),
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        onFieldSubmitted: (_) => _save(),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Enter your full name';
                          if (!text.contains(' ')) {
                            return 'Enter first name and surname';
                          }
                          if (text.length < 3) return 'The name is too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _editing = false),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _busy ? null : _save,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(96, 44),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full name',
                            style: textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          Text(
                            widget.name.isEmpty ? 'Not added' : widget.name,
                            style: textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _startEditing,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(72, 40),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ── Email ────────────────────────────────────────────────────────────────

class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.email,
    required this.confirmed,
    required this.canChange,
  });

  final String email;
  final bool confirmed;
  final bool canChange;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  confirmed ? 'Confirmed' : 'Not confirmed yet',
                  style: textTheme.bodySmall?.copyWith(
                    color: confirmed
                        ? (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF7BE3B0)
                            : const Color(0xFF00502F))
                        : scheme.error,
                  ),
                ),
              ],
            ),
          ),
          if (canChange)
            OutlinedButton(
              onPressed: () => context.go(Routes.teamChangeEmail),
              style: OutlinedButton.styleFrom(minimumSize: const Size(84, 40)),
              child: const Text('Change'),
            ),
        ],
      ),
    );
  }
}

// ── Password ─────────────────────────────────────────────────────────────

/// "Change" emails a reset link to the account's address.
class _PasswordRow extends ConsumerStatefulWidget {
  const _PasswordRow({required this.canChange});

  final bool canChange;

  @override
  ConsumerState<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends ConsumerState<_PasswordRow> {
  bool _busy = false;
  bool _sent = false;

  Future<void> _sendLink() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetToMe();
      if (mounted) setState(() => _sent = true);
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
    final email = ref.watch(currentUserProvider).value?.email ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Password',
                      style: textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    Text(
                      '••••••••',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.canChange)
                OutlinedButton(
                  onPressed: _busy || _sent ? null : _sendLink,
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(84, 40)),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Change'),
                ),
            ],
          ),
          if (_sent) ...[
            const SizedBox(height: 10),
            InfoBox(
              icon: Icons.mark_email_read_outlined,
              color: const Color(0xFF006B3F),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'We sent a link to '),
                    TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(
                      text: '. Open it to choose a new password. '
                          'Your old password works until then. '
                          "Check spam if you don't see it.",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Delete account ───────────────────────────────────────────────────────

class _DeleteAccountCard extends StatefulWidget {
  const _DeleteAccountCard({required this.isTeamAdmin, this.teamName});

  final bool isTeamAdmin;
  final String? teamName;

  @override
  State<_DeleteAccountCard> createState() => _DeleteAccountCardState();
}

class _DeleteAccountCardState extends State<_DeleteAccountCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final message = widget.isTeamAdmin
        ? "You manage ${widget.teamName ?? 'a team'}, so you can't delete "
            'your account here. Ask the FA to hand the team to another '
            'official first.'
        : 'To delete your account, contact the GEDFA office.';

    return TileGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _open = !_open),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete my account'),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
              if (_open)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InfoBox(
                    icon: Icons.info_outline_rounded,
                    color: const Color(0xFF8A6A00),
                    child: Text(message),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
