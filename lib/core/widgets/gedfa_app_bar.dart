import 'package:flutter/material.dart';
import 'package:gedfa_connect/core/widgets/flag_stripe.dart';
import 'package:gedfa_connect/core/widgets/theme_toggle_button.dart';

class GedfaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GedfaAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  static const _stripeHeight = 4.0;

  @override
  Size get preferredSize =>
      const Size.fromHeight(kToolbarHeight + _stripeHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        ...actions,
        const ThemeToggleButton(),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(_stripeHeight),
        child: FlagStripe(height: _stripeHeight),
      ),
    );
  }
}