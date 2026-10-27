import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/layout/responsive.dart';
import 'package:gedfa_connect/core/utils/kit_photo.dart';
import 'package:gedfa_connect/core/widgets/app_toast.dart';
import 'package:gedfa_connect/core/widgets/dashed_border.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_thumb.dart';
import 'package:image_picker/image_picker.dart';

/// Board R4: photos of the real kit, shirt › shorts › socks, with a
/// preview. Save is ready once all three are in.
class KitPhotosScreen extends StatefulWidget {
  const KitPhotosScreen({super.key, required this.title, this.initial});

  /// e.g. "Home kit"
  final String title;
  final KitPhotos? initial;

  static Future<KitPhotos?> open(
    BuildContext context, {
    required String title,
    KitPhotos? initial,
  }) {
    return Navigator.of(context).push<KitPhotos>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => KitPhotosScreen(title: title, initial: initial),
      ),
    );
  }

  @override
  State<KitPhotosScreen> createState() => _KitPhotosScreenState();
}

class _KitPhotosScreenState extends State<KitPhotosScreen> {
  late KitPhotos _photos = widget.initial ?? const KitPhotos();
  KitPart? _working;

  /// The first part without a photo: its slot gets the blue dashed border.
  KitPart? get _next {
    for (final part in KitPart.values) {
      if (_photos[part].isEmpty) return part;
    }
    return null;
  }

  Future<void> _choose(KitPart part) async {
    var source = ImageSource.gallery;
    if (!kIsWeb) {
      final chosen = await showModalBottomSheet<ImageSource>(
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
      if (chosen == null) return;
      source = chosen;
    }

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;

      setState(() => _working = part);
      final bytes = await file.readAsBytes();
      // Let the spinner show before the heavy work starts
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final photo = makeKitPhoto(bytes, part);
      if (!mounted) return;

      if (photo == null) {
        AppToast.error(context, "Couldn't read that image. Try another one.");
        return;
      }
      setState(() => _photos = _photos.withPart(part, KitPhoto(bytes: photo)));
    } catch (_) {
      if (mounted) {
        AppToast.error(context, "Couldn't open that image. Try another one.");
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final missing = _photos.missing;

    return Scaffold(
      appBar: GedfaAppBar(title: '${widget.title} · photos'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Lay each piece flat on a plain background and take a '
                    'photo from the front. We crop and shrink the photos on '
                    'your phone.',
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final (i, part) in KitPart.values.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _Slot(
                      number: i + 1,
                      part: part,
                      photo: _photos[part],
                      isNext: part == _next,
                      working: _working == part,
                      onChoose: _working == null ? () => _choose(part) : null,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text(
                    'PREVIEW',
                    style: textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _Preview(photos: _photos),
              ],
            ),
          ),
        ],
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
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FilledButton(
                  onPressed: missing == 0
                      ? () => Navigator.of(context).pop(_photos)
                      : null,
                  child: Text(
                    missing == 0
                        ? 'Save ${widget.title.toLowerCase()}'
                        : 'Save ${widget.title.toLowerCase()} '
                            '($missing photo${missing == 1 ? '' : 's'} needed)',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "1. Shirt · Square photo · done" with its thumbnail and button.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.number,
    required this.part,
    required this.photo,
    required this.isNext,
    required this.working,
    required this.onChoose,
  });

  final int number;
  final KitPart part;
  final KitPhoto photo;
  final bool isNext;
  final bool working;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final link = isDark ? const Color(0xFF7DBBFA) : scheme.primary;
    final chipInk = isDark ? const Color(0xFFCFE4FB) : const Color(0xFF0B3F7A);
    final done = !photo.isEmpty;

    // Thumbnails keep the part's shape: square, wide or tall
    final (w, h) = switch (part) {
      KitPart.shirt => (64.0, 64.0),
      KitPart.shorts => (64.0, 40.0),
      KitPart.socks => (40.0, 64.0),
    };

    final row = Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Center(
              child: working
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : KitPhotoBox(
                      photo: photo,
                      width: w,
                      height: h,
                      placeholder: Text(
                        '+',
                        style: TextStyle(
                          color: chipInk,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number. ${part.label}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                Text(
                  '${part.shape} · ${done ? 'done' : isNext ? 'next' : 'to do'}',
                  style: textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onChoose,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const StadiumBorder(),
              side: BorderSide(color: scheme.outline),
              foregroundColor: link,
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            child: Text(done ? 'Change' : 'Choose photo'),
          ),
        ],
      ),
    );

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isNext
            ? null
            : Border.all(color: scheme.outline, width: 1.5),
      ),
      child: row,
    );

    // The next slot to fill: a blue dashed border
    return isNext
        ? DashedBorder(
            color: scheme.primary,
            radius: 16,
            strokeWidth: 2,
            child: box,
          )
        : box;
  }
}

/// The three photos stacked, as they'll look on the kit card.
class _Preview extends StatelessWidget {
  const _Preview({required this.photos});

  final KitPhotos photos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget slot(KitPart part, double width, double height) {
      final photo = photos[part];
      if (!photo.isEmpty) {
        return KitPhotoBox(photo: photo, width: width, height: height);
      }
      return DashedBorder(
        color: scheme.outline,
        radius: 10,
        strokeWidth: 2,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Text(
              '${part.label}: add a photo',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Kit preview',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          children: [
            slot(KitPart.shirt, 140, 140),
            const SizedBox(height: 6),
            slot(KitPart.shorts, 120, 72),
            const SizedBox(height: 6),
            slot(KitPart.socks, 84, 140),
          ],
        ),
      ),
    );
  }
}
