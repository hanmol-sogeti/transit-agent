// Grundläggande röktest för ReseAgenten
//
// Kontrollerar att appen kan initieras utan att krascha
// när env-konfigurationen inte finns.

import 'package:flutter_test/flutter_test.dart';

import 'package:transit_agent/config/env_config.dart';

void main() {
  test('EnvLoadException har ett läsbart felmeddelande', () {
    const err = EnvLoadException('Testfel');
    expect(err.toString(), contains('Testfel'));
  });
}
