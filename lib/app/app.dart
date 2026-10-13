import 'package:flutter/material.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_preview.dart';

class GedfaApp extends StatelessWidget {
  const GedfaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GEDFA Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ThemePreviewScreen(),
    );
  }
}