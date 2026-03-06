/// Ruttkort – visar en resa med alla etapper
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../ui/theme/app_theme.dart';

final _timeFmt = DateFormat('HH:mm');

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.route,
    required this.index,
    this.onSelect,
    this.onShowMap,
    this.selected = false,
    this.recommended = false,
  });

  final TransitRoute route;
  final int index;
  final VoidCallback? onSelect;
  final VoidCallback? onShowMap;
  final bool selected;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? AppTheme.brandBlue
              : cs.outline.withValues(alpha: 0.25),
          width: selected ? 2 : 1,
        ),
        color: selected
            ? AppTheme.brandBlue.withValues(alpha: 0.05)
            : theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────
                Row(
                  children: [
                    _IndexBadge(
                        index: index,
                        selected: selected,
                        recommended: recommended),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (route.departure != null)
                                Text(
                                  _timeFmt.format(route.departure!),
                                  style: theme.textTheme.titleMedium,
                                ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child:
                                    Icon(Icons.arrow_forward, size: 14),
                              ),
                              if (route.arrival != null)
                                Text(
                                  _timeFmt.format(route.arrival!),
                                  style: theme.textTheme.titleMedium,
                                ),
                              const Spacer(),
                              Text(
                                route.durationLabel,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${route.transfers} byte  •  '
                            '${route.price?.toStringAsFixed(0) ?? '–'} kr',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Etapper ───────────────────────────────────────────
                _LegTimeline(legs: route.legs),

                // ── Knappar ───────────────────────────────────────────
                if (onShowMap != null || onSelect != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (onShowMap != null)
                          TextButton.icon(
                            onPressed: onShowMap,
                            icon: const Icon(Icons.map_outlined, size: 16),
                            label: const Text('Visa karta'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (onSelect != null)
                          FilledButton(
                            onPressed: onSelect,
                            child: const Text('Välj'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({
    required this.index,
    required this.selected,
    required this.recommended,
  });

  final int index;
  final bool selected;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    if (recommended) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.successColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Bäst',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: selected
            ? AppTheme.brandBlue
            : AppTheme.brandBlue.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$index',
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.brandBlue,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegTimeline extends StatelessWidget {
  const _LegTimeline({required this.legs});

  final List<Leg> legs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: legs.asMap().entries.expand((e) {
        final leg = e.value;
        final isLast = e.key == legs.length - 1;
        final color = AppTheme.modeColor(leg.mode.name);
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppTheme.modeIcon(leg.mode.name),
                  size: 13,
                  color: color,
                ),
                if (leg.line != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    leg.line!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
                if (leg.delayMinutes > 0) ...[
                  const SizedBox(width: 3),
                  Text(
                    '+${leg.delayMinutes}min',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isLast)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
            ),
        ];
      }).toList(),
    );
  }
}
