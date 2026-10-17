import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_editor.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

const _blankKit = Kit(
  primary: Color(0xFFFFFFFF),
  shorts: Color(0xFFFFFFFF),
  socks: Color(0xFFFFFFFF),
);

class KitEditorScreen extends StatefulWidget {
  const KitEditorScreen({super.key, required this.title, this.initial});

  final String title;
  final Kit? initial;

  static Future<Kit?> open(
    BuildContext context, {
    required String title,
    Kit? initial,
  }) {
    return Navigator.of(context).push<Kit>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KitEditorScreen(title: title, initial: initial),
      ),
    );
  }

  @override
  State<KitEditorScreen> createState() => _KitEditorScreenState();
}

class _KitEditorScreenState extends State<KitEditorScreen> {
  late Kit _kit = widget.initial ?? _blankKit;
  String? _error;

  void _save() {
    if (_kit.needsSecondary && _kit.secondary == null) {
      setState(() => _error =
          'Choose a second colour for the ${_kit.pattern.label.toLowerCase()}.');
      return;
    }
    if (_kit.hasTrim && _kit.trim == null) {
      setState(() => _error = 'Choose a colour for the trims.');
      return;
    }
    Navigator.of(context).pop(_kit);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: GedfaAppBar(title: widget.title),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: scheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: KitPreview(
                kit: _kit,
                width: 120,
                semanticLabel: '${widget.title} preview',
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outline),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ResponsiveCenter(
                  child: KitEditor(
                    title: widget.title,
                    kit: _kit,
                    showPreview: false,
                    errorText: _error,
                    onChanged: (kit) => setState(() {
                      _kit = kit;
                      _error = null;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FilledButton(
                onPressed: _save,
                child: Text('Save ${widget.title.toLowerCase()}'),
              ),
            ),
          ),
      ),
    ),
    );
  }
}