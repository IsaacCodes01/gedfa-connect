import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/team_logo.dart';
import 'package:image_picker/image_picker.dart';

const _maxLogoBytes = 1024 * 1024;

class LogoPicker extends StatelessWidget {
  const LogoPicker({
    super.key,
    required this.label,
    required this.color,
    required this.onPicked,
    required this.onRemoved,
    this.bytes,
    this.url,
    this.enabled = true,
    this.showError = false,
  });

  final String label;
  final Color color;
  final Uint8List? bytes;
  final String? url;
  final bool enabled;

  /// Red hint: the logo is required and still missing (2.13).
  final bool showError;
  final void Function(Uint8List bytes, String contentType) onPicked;
  final VoidCallback onRemoved;

  bool get _hasLogo => bytes != null || url != null;

  Future<void> _choose(BuildContext context) async {
    if (kIsWeb) {
      await _pick(context, ImageSource.gallery);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null && context.mounted) {
      await _pick(context, source);
    }
  }

  Future<void> _pick(BuildContext context, ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null) return;

      final picked = await file.readAsBytes();
      if (!context.mounted) return;

      if (picked.length > _maxLogoBytes) {
        AppToast.error(
          context,
          'That image is too large. Please choose a smaller one.',
        );
        return;
      }
      onPicked(picked, file.mimeType ?? 'image/jpeg');
    } catch (_) {
      if (!context.mounted) return;
      AppToast.error(context, "Couldn't open that image. Try another one.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    const buttonSize = Size(0, 44);

    return Row(
      children: [
        TeamLogo(
          label: label,
          color: color,
          bytes: bytes,
          url: url,
          size: 80,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Team logo *', style: textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                showError
                    ? 'Add your logo to continue.'
                    : 'Required. A square image works best.',
                style: textTheme.bodySmall?.copyWith(
                  color: showError ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                    onPressed: enabled ? () => _choose(context) : null,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_hasLogo ? 'Change' : 'Add logo'),
                  ),
                  if (_hasLogo)
                    TextButton(
                      style: TextButton.styleFrom(minimumSize: buttonSize),
                      onPressed: enabled ? onRemoved : null,
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}