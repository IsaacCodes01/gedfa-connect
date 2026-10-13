import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_provider.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _showBackOnline = false;
  Timer? _timer;

  bool? _onlineOf(AsyncValue<bool>? value) {
    return switch (value) {
      AsyncData(:final value) => value,
      _ => null,
    };
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
      final wasOffline = _onlineOf(previous) == false;
      final isOnlineNow = _onlineOf(next) == true;

      if (wasOffline && isOnlineNow) {
        setState(() => _showBackOnline = true);
        _timer?.cancel();
        _timer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      }
    });

    final isOnline = _onlineOf(ref.watch(isOnlineProvider)) ?? true;

    Widget? bar;
    if (!isOnline) {
      bar = const _Bar(
        color: AppColors.ink,
        icon: Icons.wifi_off_rounded,
        text: "You're offline. You can view saved data, "
            "but can't submit until you're back online.",
      );
    } else if (_showBackOnline) {
      bar = const _Bar(
        color: AppColors.ghanaGreen,
        icon: Icons.wifi_rounded,
        text: "You're back online.",
      );
    }

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: bar ?? const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: bar != null,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}