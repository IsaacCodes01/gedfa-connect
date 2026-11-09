import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/state_views.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/fa/presentation/widgets/correction_widgets.dart';
import 'package:gedfa_connect/features/settings/presentation/widgets/settings_widgets.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/correction_request.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:go_router/go_router.dart';

/// FA › an approved team › ⋮ › Ask the team to correct (2.11b, mockup
/// B2). The FA ticks what needs fixing and writes a message; the team
/// sees it in a yellow banner on its Squad tab. "Ask again" opens this
/// with the last ticks; [item] ticks one ("Wrong? Ask the team…").
class FaAskCorrectionScreen extends ConsumerWidget {
  const FaAskCorrectionScreen({super.key, required this.teamId, this.item});

  final String teamId;
  final CorrectionItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(allTeamsProvider);
    final requestAsync = ref.watch(correctionRequestProvider(teamId));
    final team = teamsAsync.value?.where((t) => t.id == teamId).firstOrNull;

    // Data first; the form copies the last ticks once
    if (team == null || requestAsync.isLoading) {
      final error = teamsAsync.error ?? requestAsync.error;
      return Scaffold(
        appBar: GedfaAppBar(
          title: 'Ask to correct',
          leading: const AppBackButton(fallback: Routes.admin, close: true),
        ),
        body: error != null
            ? ErrorView(message: appErrorMessage(error))
            : teamsAsync.isLoading || requestAsync.isLoading
                ? const LoadingView()
                : const EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'Team not found',
                    message: 'It may have been removed.',
                  ),
      );
    }
    return _Form(team: team, last: requestAsync.value, item: item);
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.team, required this.last, this.item});

  final Team team;

  /// The team's last request (null the first time)
  final CorrectionRequest? last;
  final CorrectionItem? item;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  late final Set<CorrectionItem> _items = {
    // Ask again: the same ticks as last time
    if (widget.last case final last? when last.isOpen) ...last.items,
    ?widget.item,
  };
  bool _busy = false;

  /// The team is still on the last one: the FA waits for it
  bool get _waiting => widget.last?.status == CorrectionStatus.asked;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goBack(Routes.admin);
    }
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (_items.isEmpty) {
      AppToast.warning(context, 'Tick what needs fixing.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(correctionRequestRepositoryProvider).ask(
            teamId: widget.team.id,
            teamName: widget.team.name,
            items: _items,
            message: _message.text,
            round: (widget.last?.round ?? 0) + 1,
            faUid: user.uid,
            faName: user.displayName,
          );
      if (!mounted) return;
      AppToast.success(context, 'Sent to ${widget.team.name}.');
      _back();
    } catch (error) {
      if (mounted) AppToast.error(context, appErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.team.name;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: GedfaAppBar(
          title: 'Ask $name to correct',
          leading: CloseButton(onPressed: _busy ? null : _back),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ResponsiveCenter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_waiting) ...[
                      Text(
                        '$name is still correcting what you asked on the '
                        'last request. You can ask again once they send it '
                        'back.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ] else ...[
                      const SectionTitle('What needs fixing?'),
                      TileGroup(
                        children: [
                          for (final item in CorrectionItem.values)
                            CheckboxListTile(
                              value: _items.contains(item),
                              enabled: !_busy,
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              title: Text(item.label),
                              onChanged: (on) => setState(() {
                                if (on ?? false) {
                                  _items.add(item);
                                } else {
                                  _items.remove(item);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _message,
                        enabled: !_busy,
                        minLines: 3,
                        maxLines: 6,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500),
                        ],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Message to the team *',
                          helperText: '10–500 characters. Say exactly what '
                              'is wrong, e.g. which player.',
                          helperMaxLines: 2,
                          alignLabelWithHint: true,
                        ),
                        // Same limits as the security rules
                        validator: (value) => (value?.trim().length ?? 0) < 10
                            ? 'Write at least 10 characters'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      SheetButtons(
                        cancelLabel: 'Cancel',
                        saveLabel: 'Send to $name',
                        busy: _busy,
                        onCancel: _back,
                        onSave: _send,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
