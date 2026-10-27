import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/phone.dart';
import 'package:gedfa_connect/core/utils/validators.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';

/// One official while the club fills in the form. The text lives in
/// controllers, so it survives moving between steps.
class OfficialDraft {
  OfficialDraft(
    this.role, {
    String name = '',
    String phone = '',
    String title = '',
    String licence = '',
  })  : name = TextEditingController(text: name),
        phone = TextEditingController(text: phone),
        title = TextEditingController(text: title),
        licence = TextEditingController(text: licence);

  factory OfficialDraft.fromOfficial(Official official) => OfficialDraft(
        official.role,
        name: official.name,
        phone: official.phone,
        title: official.title ?? '',
        licence: official.licence ?? '',
      );

  final OfficialRole role;
  final TextEditingController name;
  final TextEditingController phone;

  /// The typed role, for Other only.
  final TextEditingController title;
  final TextEditingController licence;

  /// "Head coach", or the typed role for Other.
  String get roleText {
    final typed = title.text.trim();
    return role == OfficialRole.other && typed.isNotEmpty ? typed : role.label;
  }

  /// Name, a valid Ghana phone and (for Other) the typed role.
  bool get isComplete =>
      name.text.trim().isNotEmpty &&
      Validators.ghanaPhone(phone.text) == null &&
      (role != OfficialRole.other || title.text.trim().length >= 2);

  Official toOfficial() {
    final licenceText = licence.text.trim();
    return Official(
      role: role,
      name: name.text.trim(),
      phone: normalizeGhanaPhone(phone.text) ?? phone.text.trim(),
      title: role == OfficialRole.other ? title.text.trim() : null,
      licence: role == OfficialRole.headCoach && licenceText.isNotEmpty
          ? licenceText
          : null,
    );
  }

  void dispose() {
    name.dispose();
    phone.dispose();
    title.dispose();
    licence.dispose();
  }
}

/// Board R2: the officials as rows, then "Add an official (4 of 7)".
/// Tap a row to change or remove it.
class OfficialsEditor extends StatelessWidget {
  const OfficialsEditor({
    super.key,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    this.showErrors = false,
    this.enabled = true,
  });

  final List<OfficialDraft> drafts;
  final ValueChanged<OfficialDraft> onAdd;
  final ValueChanged<OfficialDraft> onRemove;

  /// A row was edited; the screen redraws.
  final VoidCallback onChanged;
  final bool showErrors;
  final bool enabled;

  Future<void> _edit(BuildContext context, OfficialDraft draft) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(draft: draft),
    );
    if (result == _EditResult.removed) {
      onRemove(draft);
    } else if (result == _EditResult.saved) {
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Every role except Other can be used once
    final taken = {for (final d in drafts) d.role}..remove(OfficialRole.other);
    final roles =
        OfficialRole.addable.where((role) => !taken.contains(role)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final draft in drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OfficialRow(
              draft: draft,
              showError: showErrors && !draft.isComplete,
              onTap: enabled ? () => _edit(context, draft) : null,
            ),
          ),
        if (drafts.length < maxOfficials)
          _AddOfficialPanel(
            // A new panel (empty fields) after each official is added
            key: ValueKey(drafts.length),
            number: drafts.length + 1,
            roles: roles,
            enabled: enabled,
            onAdd: onAdd,
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '$maxOfficials of $maxOfficials officials added. Remove one to '
              'add someone else.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
      ],
    );
  }
}

// ── A row: initials, name, "Role · phone", chip ──────────────────────────

class _OfficialRow extends StatelessWidget {
  const _OfficialRow({
    required this.draft,
    required this.showError,
    required this.onTap,
  });

  final OfficialDraft draft;
  final bool showError;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3EEFA);
    final chipInk = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);
    final redBg = isDark ? const Color(0xFF4A1820) : const Color(0xFFFDE7EA);

    final name = draft.name.text.trim();
    final phone = draft.phone.text.trim();
    final complete = draft.isComplete;

    final (String? chip, Color? bg, Color? ink) = draft.role.isRequired
        ? ('Required', redBg, scheme.error)
        : draft.role == OfficialRole.other
            ? ('Other', chipBg, chipInk)
            : (null, null, null);

    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: showError ? scheme.error : scheme.outline,
          width: showError ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: chipBg,
                child: Text(
                  name.isEmpty ? '?' : initialsFor(name),
                  style: TextStyle(
                    color: chipInk,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? draft.roleText : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      complete
                          ? [
                              draft.role == OfficialRole.other
                                  ? '${draft.roleText} (other)'
                                  : draft.roleText,
                              phone,
                            ].join(' · ')
                          : name.isEmpty
                              ? 'Tap to add their name and phone'
                              : '${draft.roleText} · tap to finish',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: showError
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip.toUpperCase(),
                    style: TextStyle(
                      color: ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared fields: their role (Other), name, phone, licence ──────────────

class _Fields extends StatelessWidget {
  const _Fields({
    required this.role,
    required this.title,
    required this.name,
    required this.phone,
    this.licence,
    required this.enabled,
  });

  final OfficialRole role;
  final TextEditingController title;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController? licence;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final licence = this.licence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (role == OfficialRole.other) ...[
          TextFormField(
            controller: title,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Their role *',
              hintText: 'e.g. Welfare officer, Physiotherapist',
              helperText: 'Not in the list? Type the role here.',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            validator: (value) => (value?.trim().length ?? 0) < 2
                ? 'Type their role'
                : null,
          ),
          gap,
        ],
        TextFormField(
          controller: name,
          enabled: enabled,
          decoration: const InputDecoration(labelText: 'Full name *'),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (value) =>
              Validators.requiredField(value, 'their full name'),
        ),
        gap,
        TextFormField(
          controller: phone,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Phone *',
            hintText: 'e.g. 024 123 4567',
          ),
          keyboardType: TextInputType.phone,
          textInputAction:
              licence == null ? TextInputAction.done : TextInputAction.next,
          validator: Validators.ghanaPhone,
        ),
        if (licence != null) ...[
          gap,
          TextFormField(
            controller: licence,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Coaching licence (optional)',
              hintText: 'e.g. CAF D',
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ],
    );
  }
}

// ── "Add an official (4 of 7)" ───────────────────────────────────────────

class _AddOfficialPanel extends StatefulWidget {
  const _AddOfficialPanel({
    super.key,
    required this.number,
    required this.roles,
    required this.enabled,
    required this.onAdd,
  });

  final int number;
  final List<OfficialRole> roles;
  final bool enabled;
  final ValueChanged<OfficialDraft> onAdd;

  @override
  State<_AddOfficialPanel> createState() => _AddOfficialPanelState();
}

class _AddOfficialPanelState extends State<_AddOfficialPanel> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late OfficialRole _role = widget.roles.first;

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _add() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    widget.onAdd(
      OfficialDraft(
        _role,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        title: _title.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary, width: 2),
      ),
      // Its own form: empty fields here never block "Next"
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add an official (${widget.number} of $maxOfficials)',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(
              'Role',
              style: textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final role in widget.roles)
                  ChoiceChip(
                    label: Text(role.label),
                    selected: _role == role,
                    showCheckmark: false,
                    selectedColor: scheme.primary,
                    labelStyle: TextStyle(
                      color: _role == role ? scheme.onPrimary : null,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    onSelected: widget.enabled
                        ? (_) => setState(() => _role = role)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _Fields(
              role: _role,
              title: _title,
              name: _name,
              phone: _phone,
              enabled: widget.enabled,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.enabled ? _add : null,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add official'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Change or remove one official ────────────────────────────────────────

enum _EditResult { saved, removed }

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.draft});

  final OfficialDraft draft;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _formKey = GlobalKey<FormState>();

  // Copies, so Cancel (swiping the sheet away) keeps the old details
  late final _title = TextEditingController(text: widget.draft.title.text);
  late final _name = TextEditingController(text: widget.draft.name.text);
  late final _phone = TextEditingController(text: widget.draft.phone.text);
  late final _licence =
      TextEditingController(text: widget.draft.licence.text);

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    _phone.dispose();
    _licence.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final draft = widget.draft;
    draft.title.text = _title.text.trim();
    draft.name.text = _name.text.trim();
    draft.phone.text = _phone.text.trim();
    draft.licence.text = _licence.text.trim();
    Navigator.pop(context, _EditResult.saved);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final role = widget.draft.role;

    return Padding(
      // Stays above the keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      role == OfficialRole.other ? 'Other official' : role.label,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 14),
                    _Fields(
                      role: role,
                      title: _title,
                      name: _name,
                      phone: _phone,
                      licence:
                          role == OfficialRole.headCoach ? _licence : null,
                      enabled: true,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(onPressed: _save, child: const Text('Save')),
                    if (!role.isRequired) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(context, _EditResult.removed),
                        style:
                            TextButton.styleFrom(foregroundColor: scheme.error),
                        child: const Text('Remove this official'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
