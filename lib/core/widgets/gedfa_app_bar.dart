import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';

/// The blue app bar with the Ghana flag stripe underneath.
///
/// Only frequent actions go in [actions]. Log out and dark mode live on the
/// Settings screen, not here.
class GedfaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GedfaAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  });

  final String title;

  /// Optional smaller second line, e.g. "SSF · Gomoa Fetteh".
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  static const _stripeHeight = 4.0;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _stripeHeight);

  @override
  Widget build(BuildContext context) {
    final titleWidget = subtitle == null
        ? Text(title)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, height: 1.2),
              ),
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFDCEBFB),
                ),
              ),
            ],
          );

    return AppBar(
      leading: leading,
      title: titleWidget,
      actions: actions == null ? null : [...actions!, const SizedBox(width: 8)],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_stripeHeight),
        child: FlagStripe(height: _stripeHeight),
      ),
    );
  }
}
