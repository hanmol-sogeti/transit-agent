/// MCP-verktyg: Config
library;

import '../../config/env_config.dart';
import 'mcp_tool.dart';

/// Config-verktyget exponerar icke-hemliga konfigurationsvärden för LLM.
class ConfigTool implements McpTool {
  @override
  String get name => 'Config';

  @override
  String get description =>
      'Hämtar aktuell appkonfiguration (inga hemligheter). '
      'Exempelvis region, sökradie, kartstil och debug-läge.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {},
        'required': [],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final config = EnvConfig.instance;
    return {
      ...config.publicConfig(),
      'app_name': 'ReseAgenten',
      'language': 'sv',
      'platforms': ['windows', 'macos', 'linux'],
    };
  }
}
