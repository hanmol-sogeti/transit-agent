/// ReseAgenten – App-widget med temat och lokalisering
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'providers/app_providers.dart';

class ReseAgentenApp extends ConsumerWidget {
  const ReseAgentenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingDoneProvider);

    return MaterialApp(
      title: 'ReseAgenten',
      debugShowCheckedModeBanner: false,

      // ── Svenska lokalisering ────────────────────────────────────────
      locale: const Locale('sv', 'SE'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('sv', 'SE'),
        Locale('en', 'US'),
      ],

      // ── Temat ──────────────────────────────────────────────────────
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // ── Startroute ─────────────────────────────────────────────────
      home: onboardingDone
          ? const HomeScreen()
          : OnboardingScreen(
              onDone: () {},
            ),
    );
  }
}
