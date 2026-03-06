/// Klickbara uppföljningschips under assistentbubblor.
///
/// Visar AI-genererade suggestions om de finns, annars kontextanpassade
/// standardchips baserade på meddelandets innehåll.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../theme/app_theme.dart';

class SuggestionChipsRow extends ConsumerWidget {
  const SuggestionChipsRow({super.key, required this.message});

  final ChatMessage message;

  List<String> _fallbackChips() {
    // If routes were found, show route-action chips
    if (message.routes != null && message.routes!.isNotEmpty) {
      return ['Boka resa', 'Nästa avgång', 'Annan tid', 'Visa karta'];
    }
    final c = message.content.toLowerCase();
    if (c.contains('hållplats') || c.contains('avgång') || c.contains('linje')) {
      return ['Avgångstavla', 'Planera resa härifrån', 'Närmaste hållplatser'];
    }
    if (c.contains('boka') || c.contains('bokning') || c.contains('biljett')) {
      return ['Mina bokningar', 'Avboka', 'Ny resa'];
    }
    return ['Planera resa', 'Visa avgångar', 'Mina bokningar'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = (message.suggestions != null && message.suggestions!.isNotEmpty)
        ? message.suggestions!
        : _fallbackChips();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: chips.asMap().entries.map((entry) {
            final chip = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                right: entry.key < chips.length - 1 ? 6 : 0,
              ),
              child: _SuggestionChip(
                label: chip,
                onTap: () =>
                    ref.read(chatProvider.notifier).sendMessage(chip),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.brandBlue.withValues(alpha: 0.15)
              : AppTheme.brandBlue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.brandBlue.withValues(alpha: _pressed ? 0.6 : 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 10,
              color: AppTheme.brandBlue.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.brandBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
