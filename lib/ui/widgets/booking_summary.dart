/// Bokningssammanfattning - kvitto-vy
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/models.dart';
import '../../ui/theme/app_theme.dart';

final _dtFmt = DateFormat('EEEE d MMMM HH:mm', 'sv_SE');
final _dateFmt = DateFormat('d MMMM yyyy HH:mm', 'sv_SE');

class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.booking,
    this.onCancel,
    this.compact = false,
  });

  final Booking booking;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isCancelled = booking.status == BookingStatus.cancelled;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? AppTheme.errorColor.withValues(alpha: 0.1)
                        : AppTheme.successColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCancelled
                        ? Icons.cancel_outlined
                        : Icons.check_circle_outline_rounded,
                    color: isCancelled
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCancelled ? 'Avbokad' : 'Bokning bekräftad',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isCancelled
                              ? AppTheme.errorColor
                              : AppTheme.successColor,
                        ),
                      ),
                      Text(
                        'Ref: ${booking.reference}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  booking.formattedPrice,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.brandBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Resedetaljer ──────────────────────────────────────────
            _DetailRow(
              icon: Icons.place_rounded,
              label: 'Från',
              value: booking.route.origin?.name ?? '–',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.location_on_rounded,
              label: 'Till',
              value: booking.route.destination?.name ?? '–',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.departure_board_rounded,
              label: 'Avgång',
              value: booking.route.departure != null
                  ? _dtFmt.format(booking.route.departure!)
                  : '–',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.flag_rounded,
              label: 'Ankomst',
              value: booking.route.arrival != null
                  ? _dtFmt.format(booking.route.arrival!)
                  : '–',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.swap_horiz_rounded,
              label: 'Byten',
              value: '${booking.route.transfers}',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.people_rounded,
              label: 'Passagerare',
              value: booking.passengers.map((p) => p.label).join(', '),
            ),
            if (booking.email != null) ...[
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Kvitto till',
                value: booking.email!,
              ),
            ],
            const Divider(height: 24),

            // ── QR-biljett ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'Din QR-biljett',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            AppTheme.brandBlue.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: 'resaagenten://booking/${booking.reference}',
                      version: QrVersions.auto,
                      size: compact ? 96.0 : 130.0,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    booking.reference,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 24),

            // ── Avbokning ─────────────────────────────────────────────
            if (!isCancelled && booking.cancellationDeadline != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppTheme.warningColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Avbokning möjlig till '
                        '${_dateFmt.format(booking.cancellationDeadline!)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (!compact && onCancel != null && !isCancelled)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Avboka'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.brandBlue),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
