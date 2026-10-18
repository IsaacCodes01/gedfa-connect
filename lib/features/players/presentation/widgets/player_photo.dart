import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/utils/initials.dart';

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

/// Big passport photo (3:4) for the Player details screen.
/// Shows a silhouette until a photo is added.
class PassportPhoto extends StatelessWidget {
  const PassportPhoto({
    super.key,
    required this.name,
    this.url,
    this.width = 124,
  });

  final String name;
  final String? url;
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

    final link = url;
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
          child: link == null || link.isEmpty
              ? silhouette
              : Image.network(
                  link,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => silhouette,
                ),
        ),
      ),
    );
  }
}
