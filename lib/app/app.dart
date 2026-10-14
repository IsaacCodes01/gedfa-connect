import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/connectivity/connectivity_banner.dart';
import 'package:gedfa_connect/features/auth/presentation/auth_gate.dart';

class GedfaApp extends ConsumerWidget {
  const GedfaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'GEDFA Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) => ConnectivityBanner(
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthGate(),
    );
  }
}