/// Bas-interface för alla MCP-verktyg
library;

abstract interface class McpTool {
  /// Verktygetsnamn (används som funktionsnamn i OpenAI-anrop).
  String get name;

  /// Beskrivning på svenska, visas för LLM.
  String get description;

  /// JSON Schema för parametrarna.
  Map<String, dynamic> get parametersSchema;

  /// Kör verktyget med givna argument och returnera ett resultat.
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args);
}
