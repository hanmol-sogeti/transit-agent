/// Chattskärm – huvudsida för ReseAgenten
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/chat_bubble.dart';
import '../../ui/widgets/departure_chips_bar.dart';
import '../../ui/widgets/map_widget.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _sending = false;

  static const _suggestions = [
    'Hitta närmaste busshållplats',
    'Visa rutter från Flogsta till Uppsala Central',
    'Boka biljett från Flogsta kl 08.15',
    'Är linje 2 försenad just nu?',
    'Visa realtidsavgångar Uppsala C',
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    await ref.read(chatProvider.notifier).sendMessage(text);
    setState(() => _sending = false);
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    final mapState = ref.watch(mapProvider);
    final theme = Theme.of(context);

    // Scroll vid nya meddelanden
    ref.listen(chatProvider, (prev, _) => _scrollToBottom());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // ── Chattkolumn ─────────────────────────────────────────────
          Expanded(
            flex: mapState.isVisible ? 1 : 2,
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: messages.isEmpty
                      ? _buildWelcome(context)
                      : _buildMessageList(context, messages),
                ),
                _buildInputArea(context),
              ],
            ),
          ),

          // ── Kartkolumn ──────────────────────────────────────────────
          if (mapState.isVisible)
            Expanded(
              flex: 1,
              child: _buildMapPanel(context, mapState),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.brandBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_transit_filled_rounded,
              color: Colors.white, size: 24),
          const Gap(10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ReseAgenten',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Kollektivtrafikassistent för Sverige',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Rensa konversation?'),
                  content: const Text(
                      'Historiken och alla hittade rutter raderas.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Avbryt'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ref.read(chatProvider.notifier).clearHistory();
                        ref.read(mapProvider.notifier).hide();
                      },
                      child: const Text('Rensa'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 20),
            tooltip: 'Rensa konversation',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Gap(32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_bus_rounded,
              size: 40,
              color: AppTheme.brandBlue,
            ),
          ),
          const Gap(20),
          Text(
            'Hej! Jag är ReseAgenten.',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Gap(8),
          Text(
            'Jag hjälper dig hitta busshållplatser, planera resor\n'
            'och boka biljetter i hela Sverige.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const Gap(32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _suggestions
                .map((s) => ActionChip(
                      label: Text(s),
                      onPressed: () => _sendMessage(s),
                      avatar: const Icon(Icons.tips_and_updates_outlined,
                          size: 14),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(
      BuildContext context, List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (ctx, i) {
        final msg = messages[i];
        return ChatBubble(message: msg, isLast: i == messages.length - 1);
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DepartureChipsBar(onChipTapped: _sendMessage),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
        children: [
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    !HardwareKeyboard.instance.isShiftPressed) {
                  _sendMessage(_textController.text);
                }
              },
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Skriv ditt meddelande… (Enter för att skicka)',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const Gap(8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _sending
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : FilledButton(
                    key: const ValueKey('send'),
                    onPressed: () => _sendMessage(_textController.text),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Icon(Icons.send_rounded, size: 20),
                  ),
          ),
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildMapPanel(BuildContext context, MapState mapState) {
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: AppTheme.brandBlue),
              const Gap(8),
              const Text(
                'Karta',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(mapProvider.notifier).hide(),
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Stäng karta',
              ),
            ],
          ),
        ),
        Expanded(
          child: mapState.route != null
              ? RouteMapWidget(
                  route: mapState.route,
                  zoom: mapState.zoom,
                )
              : const Center(
                  child: Text('Ingen rutt vald.'),
                ),
        ),
        if (mapState.route != null && mapState.route!.legs.isNotEmpty)
          _LegDetailsPanel(route: mapState.route!),
      ],
    );
  }
}

/// Horisontell scroller med etappkort under kartan.
class _LegDetailsPanel extends ConsumerWidget {
  const _LegDetailsPanel({required this.route});
  final TransitRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIdx = ref.watch(selectedLegIndexProvider);
    final theme = Theme.of(context);

    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Etapper — tryck för att markera',
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              itemCount: route.legs.length,
              itemBuilder: (ctx, i) {
                final leg = route.legs[i];
                final isSelected = selectedIdx == null || selectedIdx == i;
                final color = AppTheme.modeColor(leg.mode.name);
                return GestureDetector(
                  onTap: () {
                    final notifier =
                        ref.read(selectedLegIndexProvider.notifier);
                    notifier.state = notifier.state == i ? null : i;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 150,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.1)
                          : theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? color.withValues(alpha: 0.5)
                            : theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppTheme.modeIcon(leg.mode.name),
                              size: 14,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            if (leg.line != null)
                              Text(
                                leg.line!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            if (leg.delayMinutes > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '+${leg.delayMinutes}m',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.warningColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          leg.origin.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '→ ${leg.destination.name}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '${DateFormat('HH:mm').format(leg.departure)}–'
                          '${DateFormat('HH:mm').format(leg.arrival)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        if (leg.platform != null)
                          Text(
                            'Plattform ${leg.platform}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brandBlue,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
