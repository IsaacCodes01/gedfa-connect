import 'dart:typed_data';

import 'package:flutter/material.dart';

class TeamLogo extends StatelessWidget {
  const TeamLogo({
    super.key,
    required this.label,
    required this.color,
    this.bytes,
    this.url,
    this.size = 72,
  });

  final String label;
  final Color color;
  final Uint8List? bytes;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    final fallback = Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
        ),
      ),
    );

    final Widget image;
    if (bytes != null) {
      image = Image.memory(bytes!, fit: BoxFit.cover);
    } else if (url != null) {
      image = Image.network(
        url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      image = fallback;
    }

    return Semantics(
      image: true,
      label: '$label logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.2)),
        ),
        child: ClipOval(child: image),
      ),
    );
  }
}