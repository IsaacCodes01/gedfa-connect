import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/kit_preview.dart';

/// A kit, whichever way it was made: the drawn kit, or the three photos
/// side by side (shirt, shorts, socks), as on board R3.
class KitThumb extends StatelessWidget {
  const KitThumb({
    super.key,
    required this.kit,
    this.height = 74,
    this.semanticLabel,
  });

  final Kit kit;

  /// The height of the shirt photo, or of the drawn kit.
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final photos = kit.photos;
    if (photos == null) {
      return KitPreview(
        kit: kit,
        width: height / 1.3,
        semanticLabel: semanticLabel,
      );
    }

    final h = height;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          KitPhotoBox(photo: photos.shirt, width: h, height: h),
          SizedBox(width: h * 0.1),
          KitPhotoBox(photo: photos.shorts, width: h * 0.86, height: h * 0.54),
          SizedBox(width: h * 0.1),
          KitPhotoBox(photo: photos.socks, width: h * 0.35, height: h * 0.76),
        ],
      ),
    );
  }
}

/// One kit photo in a rounded box: just picked (bytes) or uploaded (url).
class KitPhotoBox extends StatelessWidget {
  const KitPhotoBox({
    super.key,
    required this.photo,
    required this.width,
    required this.height,
    this.placeholder,
  });

  final KitPhoto photo;
  final double width;
  final double height;

  /// Shown while there is no photo (e.g. "+").
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = photo.bytes;
    final url = photo.url;
    final radius = BorderRadius.circular(width < 50 ? 6 : 10);

    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url != null) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      );
    } else {
      image = Center(child: placeholder);
    }

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outline),
      ),
      child: image,
    );
  }
}
