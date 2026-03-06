/// Hem-skärm med navigeringsrail/drawer
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ui/screens/chat_screen.dart';
import '../../ui/screens/departure_board_screen.dart';
import '../../ui/screens/settings_screen.dart';
import '../../ui/widgets/booking_summary.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat_rounded),
      label: Text('Chatt'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.departure_board_outlined),
      selectedIcon: Icon(Icons.departure_board_rounded),
      label: Text('Avgångar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long_rounded),
      label: Text('Bokningar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings_rounded),
      label: Text('Inställningar'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final latestBooking = ref.watch(latestBookingProvider);

    return Scaffold(
      body: Row(
        children: [
          // ── NavigationRail ────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                right: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.15),
                ),
              ),
            ),
            child: NavigationRail(
              destinations: _destinations,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) =>
                  setState(() => _selectedIndex = i),
              backgroundColor: Colors.transparent,
              leading: const Padding(
                padding: EdgeInsets.only(top: 16, bottom: 8),
                child: Icon(
                  Icons.directions_transit_filled_rounded,
                  color: AppTheme.brandBlue,
                  size: 28,
                ),
              ),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme:
                  const IconThemeData(color: AppTheme.brandBlue),
              selectedLabelTextStyle: const TextStyle(
                color: AppTheme.brandBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // ── Huvudinnehåll ─────────────────────────────────────────────
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const ChatScreen(),
                const DepartureBoardScreen(),
                _BookingsTab(latestBooking: latestBooking),
                const SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab({this.latestBooking});

  final dynamic latestBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingListProvider);
    final bookingService = ref.read(bookingServiceProvider);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Inga bokningar ännu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Boka en resa via chatten för att se dina kvitton här.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mina bokningar'),
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (ctx, i) {
          final booking = bookings[bookings.length - 1 - i];
          return BookingSummaryCard(
            booking: booking,
            onCancel: booking.status.name == 'confirmed'
                ? () async {
                    try {
                      final cancelled =
                          await bookingService.cancelLatest();
                      if (cancelled != null) {
                        ref
                            .read(bookingListProvider.notifier)
                            .replaceByReference(
                              cancelled.reference,
                              cancelled,
                            );
                      }
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Bokning avbokad.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Avbokning misslyckades: $e'),
                          ),
                        );
                      }
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}
