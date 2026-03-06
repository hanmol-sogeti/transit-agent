import 'package:intl/intl.dart';

enum CheckStatus { pass, warn, fail, skip }

class CheckResult {
  final String name;
  final CheckStatus status;
  final String message;
  final String? detail;
  final Duration? duration;

  const CheckResult({
    required this.name,
    required this.status,
    required this.message,
    this.detail,
    this.duration,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'status': status.name,
    'message': message,
    if (detail != null) 'detail': detail,
    if (duration != null) 'durationMs': duration!.inMilliseconds,
  };

  String get statusIcon => switch (status) {
    CheckStatus.pass => '✓',
    CheckStatus.warn => '⚠',
    CheckStatus.fail => '✗',
    CheckStatus.skip => '–',
  };

  String get statusLabel => switch (status) {
    CheckStatus.pass => 'OK',
    CheckStatus.warn => 'VARNING',
    CheckStatus.fail => 'FEL',
    CheckStatus.skip => 'HOPPAD',
  };
}

class PreflightReport {
  final DateTime timestamp;
  final List<CheckResult> results;

  const PreflightReport({required this.timestamp, required this.results});

  bool get hasFailures => results.any((r) => r.status == CheckStatus.fail);

  int get passCount => results.where((r) => r.status == CheckStatus.pass).length;
  int get warnCount => results.where((r) => r.status == CheckStatus.warn).length;
  int get failCount => results.where((r) => r.status == CheckStatus.fail).length;
  int get skipCount => results.where((r) => r.status == CheckStatus.skip).length;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'summary': {
      'total': results.length,
      'pass': passCount,
      'warn': warnCount,
      'fail': failCount,
      'skip': skipCount,
      'hasFailures': hasFailures,
    },
    'results': results.map((r) => r.toJson()).toList(),
  };

  String toLog() {
    final buf = StringBuffer();
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    buf.writeln('ReseAgenten Preflight Log – ${fmt.format(timestamp)}');
    buf.writeln('=' * 60);
    for (final r in results) {
      final durationStr =
          r.duration != null ? ' (${r.duration!.inMilliseconds} ms)' : '';
      buf.writeln('[${r.statusLabel.padRight(7)}] ${r.name}$durationStr');
      buf.writeln('  ${r.message}');
      if (r.detail != null) {
        buf.writeln('  ${r.detail}');
      }
      buf.writeln();
    }
    buf.writeln('-' * 60);
    buf.writeln(
      'Totalt: $passCount OK, $warnCount varningar, $failCount fel, $skipCount hoppade',
    );
    return buf.toString();
  }

  String toHumanSummary() {
    final buf = StringBuffer();
    buf.writeln('\n--- Preflightresultat ---');
    for (final r in results) {
      buf.writeln('  ${r.statusIcon} ${r.name}: ${r.message}');
    }
    buf.writeln();
    if (hasFailures) {
      buf.writeln('RESULTAT: $failCount kontroll(er) MISSLYCKADES.');
      buf.writeln('Åtgärda felen ovan och kör preflighten igen.');
    } else if (warnCount > 0) {
      buf.writeln(
        'RESULTAT: Alla kritiska kontroller OK. $warnCount varning(ar) noterade.',
      );
    } else {
      buf.writeln('RESULTAT: Alla kontroller OK. Appen är redo att köras!');
    }
    return buf.toString();
  }
}
