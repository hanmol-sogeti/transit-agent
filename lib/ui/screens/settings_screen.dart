/// Inställningspanel med konfigurationsinfo och debug-panel
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../config/env_config.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showDebug = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = EnvConfig.instance;
    final publicConfig = config.publicConfig();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inställningar'),
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Min profil ───────────────────────────────────────────────
          _SectionHeader(title: 'Min profil'),
          const _ProfileForm(),
          const Gap(20),

          // ── Om appen ─────────────────────────────────────────────────
          _SectionHeader(title: 'Om ReseAgenten'),
          _InfoCard(children: [
            _InfoRow(label: 'Appnamn', value: 'ReseAgenten'),
            _InfoRow(label: 'Version', value: '1.0.0'),
            _InfoRow(label: 'Plattform', value: 'Windows / macOS / Linux'),
            _InfoRow(label: 'Språk', value: 'Svenska'),
          ]),
          const Gap(20),

          // ── Konfiguration ────────────────────────────────────────────
          _SectionHeader(title: 'Konfiguration'),
          _InfoCard(
            children: publicConfig.entries
                .map((e) => _InfoRow(label: e.key, value: e.value))
                .toList(),
          ),
          const Gap(20),

          // ── Integritetspolicy ─────────────────────────────────────────
          _SectionHeader(title: 'Integritet'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined,
                          color: AppTheme.brandBlue, size: 18),
                      Gap(8),
                      Text(
                        'Dataskyddsmeddelande',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Gap(10),
                  Text(
                    'ReseAgenten samlar in och behandlar följande data:\n\n'
                    '• Platsdata – din GPS-position, '
                    'enbart för att hitta närmaste hållplats. '
                    'Platsen lagrars inte och delas inte vidare.\n\n'
                    '• Sökfrågor – dina fritextfrågor skickas till '
                    'Azure OpenAI och Trafiklab för att besvara din förfrågan. '
                    'Undvik att ange känsliga personuppgifter i chatten.\n\n'
                    '• Sessionsbokningar – bokningsdata lagras enbart '
                    'i minnet under sessionen och raderas vid avslut.\n\n'
                    'Inga lösenord eller betalningsuppgifter lagras.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),

          // ── Debug-panel ───────────────────────────────────────────────
          if (config.debugMcp) ...[
            Row(
              children: [
                _SectionHeader(title: 'Debug-panel'),
                const Spacer(),
                Switch(
                  value: _showDebug,
                  onChanged: (v) => setState(() => _showDebug = v),
                ),
              ],
            ),
            if (_showDebug) _DebugPanel(),
          ],
        ],
      ),
    );
  }
}

class _DebugPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(toolCallLogProvider);

    if (calls.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Inga verktygskörningar ännu.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_outlined,
                      size: 16, color: AppTheme.brandBlue),
                  const Gap(6),
                  Text(
                    '${calls.length} MCP-anrop',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...calls.reversed.take(20).map((call) => _ToolCallTile(call: call)),
          ],
        ),
      ),
    );
  }
}

class _ToolCallTile extends StatelessWidget {
  const _ToolCallTile({required this.call});

  final McpToolCall call;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Icon(
        call.succeeded
            ? Icons.check_circle_outline
            : Icons.error_outline,
        size: 16,
        color: call.succeeded ? AppTheme.successColor : AppTheme.errorColor,
      ),
      title: Text(
        call.toolName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        call.durationMs != null ? '${call.durationMs}ms' : '–',
        style: TextStyle(
          fontSize: 11,
          color: call.durationMs != null && call.durationMs! > 2000
              ? AppTheme.warningColor
              : Colors.grey,
        ),
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        if (call.error != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              call.error!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.errorColor,
                fontFamily: 'monospace',
              ),
            ),
          ),
        if (call.result != null)
          SelectableText(
            _truncate(call.result.toString(), 400),
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
          ),
      ],
    );
  }

  String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max)}…' : s;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.brandBlue,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: children
              .expand((c) => [c, const Divider(height: 1)])
              .take(children.length * 2 - 1)
              .toList(),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profilformul\u00e4r ─────────────────────────────────────────────────────────

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm();

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameCtrl = TextEditingController(text: profile.name);
    _addressCtrl = TextEditingController(text: profile.homeAddress);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = UserProfile(
      name: _nameCtrl.text.trim(),
      homeAddress: _addressCtrl.text.trim(),
    );
    await ref.read(userProfileProvider.notifier).save(updated);
    if (mounted) {
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) { setState(() => _saved = false); }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    color: AppTheme.brandBlue, size: 18),
                const Gap(8),
                Text(
                  'Personuppgifter',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
            const Gap(4),
            Text(
              'Anv\u00e4nds av ReseAgenten som standard-startpunkt och '
              'f\u00f6r personliga h\u00e4lsningar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const Gap(14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Ditt namn',
                hintText: 'T.ex. Jon Doe',
                prefixIcon:
                    Icon(Icons.badge_outlined, size: 18),
                isDense: true,
              ),
            ),
            const Gap(12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Hemadress',
                hintText: 'T.ex. Dragabrunsgatan 45, Uppsala',
                prefixIcon:
                    Icon(Icons.home_outlined, size: 18),
                isDense: true,
              ),
            ),
            const Gap(14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _saved
                      ? Row(
                          key: const ValueKey('saved'),
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.successColor, size: 16),
                            const Gap(4),
                            Text(
                              'Sparat!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const Gap(12),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Spara profil'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
