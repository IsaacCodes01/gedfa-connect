import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';

enum ToastType { success, error, warning, info }

class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  static void success(BuildContext context, String message) =>
      _show(context, message, ToastType.success);

  static void error(BuildContext context, String message) =>
      _show(context, message, ToastType.error);

  static void warning(BuildContext context, String message) =>
      _show(context, message, ToastType.warning);

  static void info(BuildContext context, String message) =>
      _show(context, message, ToastType.info);

  static void _show(BuildContext context, String message, ToastType type) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _ToastCard(
        message: message,
        type: type,
        onDismissed: () {
          if (_current == entry) {
            entry.remove();
            _current = null;
          }
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  final String message;
  final ToastType type;
  final VoidCallback onDismissed;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, -1.5),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    final seconds = widget.type == ToastType.error ? 5 : 3;
    _timer = Timer(Duration(seconds: seconds), _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (icon, accent) = switch (widget.type) {
      ToastType.success => (
          Icons.check_circle_rounded,
          isDark ? AppColors.darkGreen : AppColors.ghanaGreen,
        ),
      ToastType.error => (Icons.error_rounded, scheme.error),
      ToastType.warning => (
          Icons.warning_rounded,
          isDark ? AppColors.ghanaGold : AppColors.pendingText,
        ),
      ToastType.info => (Icons.info_rounded, scheme.primary),
    };

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SlideTransition(
              position: _slide,
              child: Dismissible(
                key: ObjectKey(widget),
                direction: DismissDirection.up,
                onDismissed: (_) {
                  _timer?.cancel();
                  widget.onDismissed();
                },
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: scheme.surface,
                    elevation: 8,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.message,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: _close,
                            icon: const Icon(Icons.close_rounded),
                            color: scheme.onSurfaceVariant,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
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