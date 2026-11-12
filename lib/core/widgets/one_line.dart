import 'package:flutter/widgets.dart';

/// A button's words on one line (Isaac, 12 Nov 2026): never stacked on top
/// of each other when buttons share a narrow row. They keep their size when
/// they fit, and shrink a little when the button is too narrow.
///
/// Use it for the label of any button that sits in an `Expanded` /
/// `Flexible` next to other buttons: `child: const OneLine(Text('Approve'))`.
class OneLine extends StatelessWidget {
  const OneLine(this.child, {super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(fit: BoxFit.scaleDown, child: child);
  }
}
