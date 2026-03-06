/// Snabbvalsrad av avgångstider – visas ovanför chattrutan när rutter finns
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

final _timeFmt = DateFormat('HH:mm');

class DepartureChipsBar extends ConsumerWidget {
  const DepartureChipsBar({super.key, required this.onChipTapped});

  /// Called with the full message text when a chip is tapped.
  final void Function(String text) onChipTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(latestRoutesProvider);
    if (routes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final now = DateTime.now();

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color:
                  theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
        ),
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppTheme.brandBlue,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Avgång:',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...routes.take(6).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final route = entry.value;
              final dep = route.departure;
              if (dep == null) return const SizedBox.shrink();

              final timeStr = _timeFmt.format(dep);
              final isNext = i == 0 && dep.isAfter(now);
              final minutesAway = dep.difference(now).inMinutes;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  avatar: Icon(
                    isNext
                        ? Icons.directions_bus_rounded
                        : Icons.access_time_rounded,
                    size: 14,
                    color: isNext
                        ? AppTheme.successColor
                        : AppTheme.brandBlue,
                  ),
                  label: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontWeight: isNext
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isNext
                              ? AppTheme.successColor
                              : null,
                        ),
                      ),
                      if (isNext && minutesAway >= 0 && minutesAway < 60)
                        Text(
                          'om ${minutesAway}min',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.successColor,
                          ),
                        )
                      else
                        Text(
                          '${route.transfers} byte  •  '
                          '${route.durationLabel}',
                          style: const TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                  onPressed: () => onChipTapped(
                    'Välj alternativ ${i + 1} som avgår kl $timeStr',
                  ),
                  backgroundColor: isNext
                      ? AppTheme.successColor.withValues(alpha: 0.08)
                      : null,
                  side: isNext
                      ? BorderSide(
                          color: AppTheme.successColor
                              .withValues(alpha: 0.4),
                        )
                      : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
