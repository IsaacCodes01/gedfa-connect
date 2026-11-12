import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gedfa_connect/app/app.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/firebase/emulators.dart';
import 'package:gedfa_connect/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A page opened on top (push) shows its own address on the web, so a
  // refresh keeps it (3.0f2)
  GoRouter.optionURLReflectsImperativeAPIs = true;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await connectToEmulatorsIfNeeded();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const GedfaApp(),
    ),
  );
  // The web splash (deep blue + logo, in web/index.html) stays until the app
  // has drawn its first frame; on phones this happens by itself (R-a).
  FlutterNativeSplash.remove();
}