import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:go_router/go_router.dart';

/// FA: invite someone as a referee or (chairman only) an FA official.
class InvitePersonScreen extends ConsumerStatefulWidget {
  const InvitePersonScreen({super.key});

  @override
  ConsumerState<InvitePersonScreen> createState() =>
      _InvitePersonScreenState();
}

class _InvitePersonScreenState extends ConsumerState<InvitePersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  UserRole _role = UserRole.referee;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      final id = await ref.read(peopleRepositoryProvider).invite(
            name: _name.text,
            email: _email.text,
            role: _role,
            by: me,
          );
      if (!mounted) return;
      // Replace this form with the "Invitation ready" screen
      context.go(Routes.adminInviteReady(id));
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChairman = ref.watch(appUserProvider).value?.isChairman ?? false;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const GedfaAppBar(title: 'Invite someone'),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            // heightFactor: 1 = only as tall as the button.
            // A plain Center (ResponsiveCenter) grows to the full screen
            // height here and hides the form.
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FilledButton(
                  onPressed: _busy ? null : _create,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Text('Create invitation'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Enter their full name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      helperText: 'They must sign up with exactly this email.',
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    header: true,
                    child: Text(
                      'Role',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _RoleOption(
                    title: 'Referee',
                    text: 'Sees assigned matches and sends match reports. '
                        'Cannot approve anything.',
                    selected: _role == UserRole.referee,
                    onTap: () => setState(() => _role = UserRole.referee),
                  ),
                  const SizedBox(height: 8),
                  _RoleOption(
                    title: 'FA official',
                    text: isChairman
                        ? 'Approves and rejects teams and players, and can '
                            'invite referees.'
                        : 'Only the chairman can invite FA officials.',
                    selected: _role == UserRole.faAdmin,
                    enabled: isChairman,
                    onTap: () => setState(() => _role = UserRole.faAdmin),
                  ),
                  const SizedBox(height: 16),
                  InfoBox(
                    icon: Icons.info_outline_rounded,
                    color: scheme.primary,
                    child: const Text(
                      'No email is sent automatically. On the next screen you '
                      'share the invitation on WhatsApp or by text. It expires '
                      'after 14 days.',
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

/// A role card with a round radio mark.
class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String text;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: selected
              ? scheme.primary.withValues(alpha: 0.06)
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outline,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 22,
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          text,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
