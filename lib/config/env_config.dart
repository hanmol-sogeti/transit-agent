/// ReseAgenten – Env-konfiguration
///
/// Läser alla nödvändiga variabler från env-filen vid uppstart.
/// Inga hemligheter skrivs till loggar.
library;

import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:logging/logging.dart';

final _log = Logger('EnvConfig');

/// Sökväg till env-filen.
const _envFilePath = r'C:\Users\hmoller\source\env\transit-ai.env';

/// Alla obligatoriska variabelnamn (måste finnas i env-filen).
const _requiredVars = <String>[
  // Trafiklab
  'TRAFIKLAB_KEY',
  // Azure OpenAI
  'AZURE_OPENAI_ENDPOINT',
  'AZURE_OPENAI_API_KEY',
  'AZURE_OPENAI_DEPLOYMENT',
  'AZURE_OPENAI_API_VERSION',
];

/// Variabler som innehåller känsliga värden – loggas ALDRIG.
const _secretVars = <String>{
  'TRAFIKLAB_KEY',
  'AZURE_OPENAI_API_KEY',
};

class EnvConfig {
  EnvConfig._();

  static EnvConfig? _instance;
  static EnvConfig get instance {
    if (_instance == null) {
      throw StateError(
        'EnvConfig har inte initierats. Anropa EnvConfig.load() vid uppstart.',
      );
    }
    return _instance!;
  }

  late final DotEnv _env;

  // ─── Trafiklab ──────────────────────────────────────────────────────────────
  /// Samma nyckel används för alla ResRobot-endpoints.
  String get trafiklabKey => _require('TRAFIKLAB_KEY');
  String get trafiklabRealtimeKey => trafiklabKey;
  String get trafiklabStopsKey => trafiklabKey;
  String get trafiklabRouteKey => trafiklabKey;

  // ─── Azure OpenAI ───────────────────────────────────────────────────────────
  String get azureOpenAiEndpoint => _require('AZURE_OPENAI_ENDPOINT');
  String get azureOpenAiKey => _require('AZURE_OPENAI_API_KEY');
  String get azureOpenAiModel => _require('AZURE_OPENAI_DEPLOYMENT');
  String get azureOpenAiApiVersion => _require('AZURE_OPENAI_API_VERSION');

  // ─── Karta (valfria – har inbyggda standardvärden) ──────────────────────────
  String get mapTileEndpoint =>
      _env['MAP_TILE_ENDPOINT'] ??
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  String get mapAttribution =>
      _env['MAP_ATTRIBUTION'] ?? '\u00a9 OpenStreetMap-bidragsgivare';

  // ─── Routing (valfri – standardvärde OSRM) ──────────────────────────────────
  String get routingEndpoint =>
      _env['ROUTING_ENGINE_ENDPOINT'] ??
      'https://router.project-osrm.org';

  // ─── Valfria ────────────────────────────────────────────────────────────────
  String get defaultSearchRadius =>
      _env['DEFAULT_SEARCH_RADIUS_METERS'] ?? '500';
  String get defaultRegion => _env['DEFAULT_REGION'] ?? 'Uppsala';
  bool get debugMcp => (_env['DEBUG_MCP'] ?? 'false').toLowerCase() == 'true';

  String _require(String key) {
    final value = _env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Saknad konfiguration: $key. Kontrollera env-filen.');
    }
    return value;
  }

  // ─── Initiering ─────────────────────────────────────────────────────────────

  /// Laddar env-filen och validerar att alla nödvändiga variabler finns.
  /// Kastar [EnvLoadException] vid fel.
  static Future<EnvConfig> load() async {
    final file = File(_envFilePath);
    if (!file.existsSync()) {
      throw EnvLoadException(
        'Env-filen hittades inte: $_envFilePath\n'
        'Skapa filen och lägg till nödvändiga variabler (se README.md).',
      );
    }

    final env = DotEnv(includePlatformEnvironment: true)..load([_envFilePath]);

    final missing = <String>[];
    for (final key in _requiredVars) {
      final value = env[key];
      if (value == null || value.isEmpty) missing.add(key);
    }
    if (missing.isNotEmpty) {
      throw EnvLoadException(
        'Saknade variabler i env-filen: ${missing.join(', ')}\n'
        'Lägg till dessa i $_envFilePath.',
      );
    }

    _log.info('Env-fil laddad. Variabler: ${_requiredVars.length} av ${_requiredVars.length} hittades.');

    // Logga icke-hemliga konfigurationsvärden för diagnostik.
    for (final key in _requiredVars) {
      if (!_secretVars.contains(key)) {
        _log.fine('Config $key = ${env[key]}');
      }
    }

    _instance = EnvConfig._();
    _instance!._env = env;
    return _instance!;
  }

  /// Returnerar en MAP med icke-hemliga konfigurationsvärden för visning i UI.
  Map<String, String> publicConfig() {
    final result = <String, String>{};
    for (final key in _requiredVars) {
      if (!_secretVars.contains(key)) {
        result[key] = _env[key] ?? '';
      }
    }
    result['DEFAULT_SEARCH_RADIUS_METERS'] = defaultSearchRadius;
    result['DEFAULT_REGION'] = defaultRegion;
    result['DEBUG_MCP'] = debugMcp.toString();
    return result;
  }

  /// Returnerar env-filens sökväg (icke-känslig).
  static String get envFilePath => _envFilePath;

  /// Returnerar alla förväntade variabelnamn.
  static List<String> get requiredVarNames => List.unmodifiable(_requiredVars);
}

class EnvLoadException implements Exception {
  const EnvLoadException(this.message);
  final String message;

  @override
  String toString() => 'EnvLoadException: $message';
}
