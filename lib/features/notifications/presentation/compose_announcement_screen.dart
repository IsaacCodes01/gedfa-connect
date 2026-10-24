import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/user_role.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/notifications/presentation/fa_announcements_screen.dart';
import 'package:gedfa_connect/features/people/data/people_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:go_router/go_router.dart';

/// FA: write and publish an announcement (one-way, to the bell of the
/// chosen people; pinned ones also show on top of their home screen).
class ComposeAnnouncementScreen extends ConsumerStatefulWidget {
  const ComposeAnnouncementScreen({super.key});

  @override
  ConsumerState<ComposeAnnouncementScreen> createState() =>
      _ComposeAnnouncementScreenState();
}

class _ComposeAnnouncementScreenState
    extends ConsumerState<ComposeAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  Audience _to = Audience.teams;
  bool _important = false;
  bool _pinned = false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final me = ref.read(authRepositoryProvider).currentUser;
    if (me == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish this announcement?'),
        content: Text(
          'It goes to ${_to.label.toLowerCase()} straight away. The text '
          "can't be changed afterwards; you can unpin or delete it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(notificationsRepositoryProvider).publish(
            title: _title.text,
            body: _body.text,
            to: _to,
            important: _important,
            pinned: _pinned,
            by: me,
          );
      if (!mounted) return;
      AppToast.success(context, 'Announcement published.');
      context.pop();
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
    final teams = ref.watch(allTeamsProvider).value ?? const [];
    final referees = (ref.watch(membersProvider).value ?? const [])
        .where((m) => m.role == UserRole.referee)
        .length;
    final reach = _to == Audience.everyone
        ? '${teams.length} teams, $referees referees and the FA'
        : _to == Audience.referees
            ? '$referees referees'
            : '${audienceSize(_to, teams, referees)} team managers';

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 18),
          child: Text(
            text,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        );

    return Scaffold(
      appBar: GedfaAppBar(
        title: 'New announcement',
        leading: CloseButton(onPressed: () => context.pop()),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            // heightFactor: 1 = only as tall as the button
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _publish,
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.campaign_outlined),
                  label: const Text('Publish'),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            ResponsiveCenter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  label('Send to'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in Audience.values)
                        ChoiceChip(
                          label: Text(a.label),
                          selected: _to == a,
                          onSelected: (_) => setState(() => _to = a),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reaches: $reach.',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  label('Title'),
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [LengthLimitingTextInputFormatter(80)],
                    decoration: const InputDecoration(
                      hintText: 'e.g. Registration closes 15 Nov',
                      helperText: 'Short and clear. Up to 80 characters.',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 3
                        ? 'Write a title (at least 3 characters)'
                        : null,
                  ),
                  label('Message'),
                  TextFormField(
                    controller: _body,
                    minLines: 6,
                    maxLines: 14,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Dear team managers, …',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 10
                        ? 'Write at least 10 characters'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                    title: const Text('Important'),
                    subtitle:
                        const Text('Red label and a red border in the bell'),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _pinned,
                    onChanged: (v) => setState(() => _pinned = v),
                    title: const Text('Pin to their home screen'),
                    subtitle: const Text(
                      'Shows on top of Squad until you unpin it',
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
