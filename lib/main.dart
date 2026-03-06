import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'config/env_config.dart';
import 'preflight/preflight_runner.dart';
import 'providers/app_providers.dart';

final _log = Logger('main');

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  _setupLogging();

  // --preflight mode: run checks, write report, exit
  if (args.contains('--preflight')) {
    await _runPreflight();
    exit(0);
  }

  // Desktop window setup
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      title: 'ReseAgenten',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Load environment config
  EnvConfig? config;
  String? configError;
  try {
    config = await EnvConfig.load();
    _log.info('EnvConfig loaded successfully');
  } catch (e) {
    configError = e.toString();
    _log.severe('Failed to load EnvConfig: $configError');
  }

  // Load shared preferences
  final prefs = await SharedPreferences.getInstance();

  if (config == null) {
    runApp(ConfigErrorApp(error: configError ?? 'Okänt konfigurationsfel'));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ReseAgentenApp(),
    ),
  );
}

void _setupLogging() {
  Logger.root.level = Level.ALL;
  const secretWords = [
    'TRAFIKLAB_REALTIME_KEY',
    'TRAFIKLAB_STOPS_KEY',
    'TRAFIKLAB_ROUTE_KEY',
    'AZURE_OPENAI_KEY',
    'api-key',
    'Bearer ',
  ];

  Logger.root.onRecord.listen((record) {
    var msg = '[${record.level.name}] ${record.loggerName}: ${record.message}';

    // Redact any accidental secret leakage
    for (final secret in secretWords) {
      if (msg.contains(secret)) {
        msg = msg.replaceAll(RegExp('$secret[^\\s"\'&]*'), '$secret=***');
      }
    }

    // ignore: avoid_print
    print(msg);
    if (record.error != null) {
      // ignore: avoid_print
      print('  ERROR: ${record.error}');
    }
  });
}

Future<void> _runPreflight() async {
  // ignore: avoid_print
  print('=== ReseAgenten – Preflightkontroll ===\n');

  EnvConfig? config;
  try {
    config = await EnvConfig.load();
  } catch (e) {
    // ignore: avoid_print
    print('[FEL] Kan inte läsa envkonfig: $e');
    // ignore: avoid_print
    print('\nAbbryter – utan envkonfig kan inga nätverkstester köras.');
    exit(1);
  }

  final runner = PreflightRunner(config: config);
  final report = await runner.run();

  // Write JSON report
  final jsonFile = File('preflight_report.json');
  await jsonFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(report.toJson()),
  );

  // Write human-readable log
  final logFile = File('preflight_logs.txt');
  await logFile.writeAsString(report.toLog());

  // Print summary to stdout
  // ignore: avoid_print
  print(report.toHumanSummary());
  // ignore: avoid_print
  print('\nDetaljerad rapport: ${jsonFile.path}');
  // ignore: avoid_print
  print('Logg: ${logFile.path}');

  if (report.hasFailures) {
    exit(1);
  }
}

/// Felskärm som visas om konfigurationsfilen inte kan läsas.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.error, super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReseAgenten – Konfigurationsfel',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF8F6),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Color(0xFFB71C1C),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Konfigurationsfel',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ReseAgenten kunde inte läsa env-filen.\n'
                    'Kontrollera att filen finns på rätt plats och att alla '
                    'obligatoriska variabler är satta. Se README.md för detaljer.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF9A9A)),
                    ),
                    child: SelectableText(
                      error,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF7F0000),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
