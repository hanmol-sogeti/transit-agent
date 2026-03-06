/// Kompakt ruttkort f\u00f6r inb\u00e4ddning direkt i chattbubblor
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/map_widget.dart';

final _timeFmt = DateFormat('HH:mm');

class InlineChatRouteCards extends ConsumerWidget {
  const InlineChatRouteCards({
    super.key,
    required this.routes,
  });

  final List<TransitRoute> routes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routes.isEmpty) { return const SizedBox.shrink(); }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
        for (var i = 0; i < routes.length; i++) ...[
          _InlineRouteCard(route: routes[i], index: i),
          if (i < routes.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _InlineRouteCard extends ConsumerWidget {
  const _InlineRouteCard({required this.route, required this.index});

  final TransitRoute route;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: tid + varaktighet ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _IndexBadge(index: index),
                const SizedBox(width: 8),
                if (route.departure != null)
                  Text(
                    _timeFmt.format(route.departure!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(Icons.arrow_forward_rounded, size: 14),
                ),
                if (route.arrival != null)
                  Text(
                    _timeFmt.format(route.arrival!),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Text(
              '${route.transfers} byte  \u2022  '
              '${route.price?.toStringAsFixed(0) ?? '\u2013'} kr',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),

          // ── Etapptidslinje ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _LegTimeline(legs: route.legs),
          ),

          // ── Kartf\u00f6rhandsvisning ──────────────────────────────────────
          if (route.origin?.position.latitude != 0 ||
              route.origin?.position.longitude != 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: MapPreviewButton(route: route),
            ),

          // ── Knappar ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref
                        .read(mapProvider.notifier)
                        .showRoute(route),
                    icon: const Icon(Icons.map_outlined, size: 15),
                    label: const Text('Visa karta'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final dep = route.departure != null
                          ? ' kl ${_timeFmt.format(route.departure!)}'
                          : '';
                      ref.read(chatProvider.notifier).sendMessage(
                            'Boka alternativ ${index + 1}$dep (route_id=${route.id})',
                          );
                    },
                    icon: const Icon(Icons.confirmation_number_outlined,
                        size: 15),
                    label: const Text('Boka'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final isFirst = index == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isFirst
            ? AppTheme.successColor
            : AppTheme.brandBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isFirst ? 'N\u00e4sta' : 'Alt ${index + 1}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isFirst ? Colors.white : AppTheme.brandBlue,
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
    if (legs.isEmpty) { return const SizedBox.shrink(); }
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: legs.asMap().entries.expand((e) {
        final leg = e.value;
        final isLast = e.key == legs.length - 1;
        final color = AppTheme.modeColor(leg.mode.name);
        return [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppTheme.modeIcon(leg.mode.name),
                    size: 12, color: color),
                if (leg.line != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    leg.line!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
                if (leg.delayMinutes > 0) ...[
                  const SizedBox(width: 2),
                  Text(
                    '+${leg.delayMinutes}m',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isLast)
            const Icon(Icons.chevron_right, size: 13, color: Colors.grey),
        ];
      }).toList(),
    );
  }
}
