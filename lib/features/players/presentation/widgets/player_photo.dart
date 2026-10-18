import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/initials.dart';
import 'package:gedfa_connect/core/utils/passport_photo.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:image_picker/image_picker.dart';

/// Small round picture for lists: the thumbnail, or the initials.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    this.url,
    this.size = 44,
  });

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initials = Container(
      color: scheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.32,
        ),
      ),
    );

    final link = url;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: link == null || link.isEmpty
            ? initials
            : Image.network(
                link,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => initials,
              ),
      ),
    );
  }
}

/// Big passport photo (3:4). Shows new [bytes] first, then the saved
/// [url], and a silhouette if there is neither.
class PassportPhoto extends StatelessWidget {
  const PassportPhoto({
    super.key,
    required this.name,
    this.url,
    this.bytes,
    this.width = 124,
  });

  final String name;
  final String? url;
  final Uint8List? bytes;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = width * 4 / 3;

    final silhouette = Container(
      color: scheme.primary.withValues(alpha: 0.14),
      alignment: Alignment.bottomCenter,
      child: Icon(
        Icons.person,
        size: width * 0.9,
        color: scheme.primary.withValues(alpha: 0.35),
      ),
    );

    final newBytes = bytes;
    final link = url;
    final Widget picture;
    if (newBytes != null) {
      picture = Image.memory(newBytes, fit: BoxFit.cover);
    } else if (link != null && link.isNotEmpty) {
      picture = Image.network(
        link,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => silhouette,
      );
    } else {
      picture = silhouette;
    }

    return Semantics(
      image: true,
      label: 'Passport photo of $name',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.surface, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x38000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: picture,
        ),
      ),
    );
  }
}

/// The photo box on the Add / Edit player form: shows the photo and lets
/// the user take or choose one. The picked image is turned into a
/// passport photo here, before it is handed to the form.
class PassportPhotoPicker extends StatefulWidget {
  const PassportPhotoPicker({
    super.key,
    required this.name,
    required this.onPicked,
    this.bytes,
    this.url,
    this.enabled = true,
    this.errorText,
  });

  final String name;
  final Uint8List? bytes;
  final String? url;
  final bool enabled;
  final String? errorText;
  final ValueChanged<ProcessedPhoto> onPicked;

  @override
  State<PassportPhotoPicker> createState() => _PassportPhotoPickerState();
}

class _PassportPhotoPickerState extends State<PassportPhotoPicker> {
  bool _working = false;

  bool get _hasPhoto =>
      widget.bytes != null || (widget.url?.isNotEmpty ?? false);

  Future<void> _choose() async {
    // On the web (including iPhone Safari) the browser itself offers
    // "Take photo" or "Photo library", so we go straight to the picker.
    if (kIsWeb) {
      await _pick(ImageSource.gallery);
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
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) await _pick(source);
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        // Shrink big camera photos first (fast), then we finish the job
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null || !mounted) return;

      setState(() => _working = true);
      final bytes = await file.readAsBytes();
      // Let the spinner show before the heavy work starts
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final photo = makePassportPhoto(bytes);
      if (!mounted) return;

      if (photo == null) {
        AppToast.error(context, "Couldn't read that image. Try another one.");
        return;
      }
      widget.onPicked(photo);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, "Couldn't open that image. Try another one.");
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final error = widget.errorText;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: error != null ? scheme.error : scheme.outline,
          width: error != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PassportPhoto(
                  name: widget.name,
                  bytes: widget.bytes,
                  url: widget.url,
                  width: 78,
                ),
                if (_working)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Passport photo',
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'Required. Face in the middle, plain background, '
                  'good light.',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: widget.enabled && !_working ? _choose : null,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(_hasPhoto ? 'Change photo' : 'Add photo'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    error,
                    style:
                        textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
