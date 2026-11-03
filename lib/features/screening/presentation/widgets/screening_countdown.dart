import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gedfa_connect/features/screening/domain/screening_day.dart';

/// "Opens in 2 h 14 min", counting down every second (2.14d, board J3).
/// At the start time it calls [onStarted] once, so the screen can swap
/// the countdown for the Start screening button.
class ScreeningCountdown extends StatefulWidget {
  const ScreeningCountdown({
    super.key,
    required this.startsAt,
    this.style,
    this.prefix = 'Opens in ',
    this.nowText = 'Open now',
    this.onStarted,
  });

  final DateTime startsAt;
  final TextStyle? style;

  /// "Opens in " for the FA, "Starts in " on the team's card
  final String prefix;

  /// Shown from the start time: "Open now" (FA), "Happening now" (team)
  final String nowText;
  final VoidCallback? onStarted;

  @override
  State<ScreeningCountdown> createState() => _ScreeningCountdownState();
}

class _ScreeningCountdownState extends State<ScreeningCountdown> {
  Timer? _timer;
  bool _told = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    if (!DateTime.now().isBefore(widget.startsAt)) {
      _timer?.cancel();
      if (!_told) {
        _told = true;
        widget.onStarted?.call();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.startsAt.difference(DateTime.now());
    return Text(
      left.isNegative
          ? widget.nowText
          : '${widget.prefix}${ScreeningDay.countdownText(left)}',
      style: widget.style,
    );
  }
}
