/// Boknings- och kvittotjänst för ReseAgenten
///
/// Simulerar ett fullständigt bokningsflöde för demo.
/// Lagrar ingenting persistent efter sessionen.
library;

import 'dart:math';
import 'package:logging/logging.dart';
import '../models/models.dart';

final _log = Logger('BookingService');

class BookingService {
  final List<Booking> _sessionBookings = [];

  /// Genomför en bokning och returnerar en bekräftad bokning med referens.
  Future<Booking> book(BookingRequest request) async {
    // Simulera bearbetningstid
    await Future.delayed(const Duration(milliseconds: 800));

    // Validera passagerare
    if (request.passengers.isEmpty) {
      throw BookingException('Minst en passagerare krävs för bokning.');
    }

    // Beräkna pris (priser är simulerade för demo)
    final price = _calculatePrice(request.passengers, request.route);
    final reference = _generateReference();
    final now = DateTime.now();
    final cancellationDeadline = _calculateCancellationDeadline(
      request.route.departure ?? now,
    );

    final booking = Booking(
      reference: reference,
      route: request.route,
      passengers: request.passengers,
      bookedAt: now,
      totalPrice: price,
      currency: 'SEK',
      email: request.email,
      cancellationDeadline: cancellationDeadline,
      status: BookingStatus.confirmed,
    );

    _sessionBookings.add(booking);
    _log.info('Bokning genomförd: ref=$reference (loggs säker)');
    return booking;
  }

  /// Avboka senaste bokning i sessionen.
  Future<Booking?> cancelLatest() async {
    if (_sessionBookings.isEmpty) return null;
    await Future.delayed(const Duration(milliseconds: 400));
    final last = _sessionBookings.last;
    final now = DateTime.now();
    if (last.cancellationDeadline != null &&
        now.isAfter(last.cancellationDeadline!)) {
      throw BookingException(
        'Avbokning inte möjlig – sista tid för avbokning har passerat.',
      );
    }
    final cancelled = Booking(
      reference: last.reference,
      route: last.route,
      passengers: last.passengers,
      bookedAt: last.bookedAt,
      totalPrice: last.totalPrice,
      currency: last.currency,
      email: last.email,
      cancellationDeadline: last.cancellationDeadline,
      status: BookingStatus.cancelled,
    );
    _sessionBookings[_sessionBookings.length - 1] = cancelled;
    return cancelled;
  }

  List<Booking> get sessionBookings => List.unmodifiable(_sessionBookings);
  Booking? get latestBooking =>
      _sessionBookings.isNotEmpty ? _sessionBookings.last : null;

  double _calculatePrice(List<Passenger> passengers, TransitRoute route) {
    const basePrice = 35.0;
    double total = 0;
    for (final p in passengers) {
      switch (p.type) {
        case PassengerType.adult:
          total += basePrice;
        case PassengerType.child:
          total += basePrice * 0.5;
        case PassengerType.senior:
          total += basePrice * 0.7;
        case PassengerType.youth:
          total += basePrice * 0.6;
      }
    }
    // Multisegment tillägg
    final transitLegs =
        route.legs.where((l) => l.mode != TransportMode.walk).length;
    if (transitLegs > 1) total += 10.0 * (transitLegs - 1);
    return double.parse(total.toStringAsFixed(2));
  }

  String _generateReference() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final code = List.generate(
      6,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    return 'RA-$code';
  }

  DateTime _calculateCancellationDeadline(DateTime departure) {
    // Avbokning möjlig upp till 30 min före avgång
    return departure.subtract(const Duration(minutes: 30));
  }
}

class BookingException implements Exception {
  const BookingException(this.message);
  final String message;

  @override
  String toString() => 'BookingException: $message';
}
