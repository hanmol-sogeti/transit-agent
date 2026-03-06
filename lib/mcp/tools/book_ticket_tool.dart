/// MCP-verktyg: BookTicket
library;

import 'package:logging/logging.dart';
import '../../models/models.dart';
import '../../services/booking_service.dart';
import 'mcp_tool.dart';

final _log = Logger('BookTicketTool');

class BookTicketTool implements McpTool {
  BookTicketTool(this._booking, this._resolveRoute, {this.onBooking});

  final BookingService _booking;
  final Future<TransitRoute?> Function(String routeId) _resolveRoute;
  final void Function(Booking booking)? onBooking;

  @override
  String get name => 'BookTicket';

  @override
  String get description =>
      'Boka en biljett för en vald resa. '
      'Returnerar bokningsreferens och kvittoinformation.';

  @override
  Map<String, dynamic> get parametersSchema => {
        'type': 'object',
        'properties': {
          'route_id': {
            'type': 'string',
            'description': 'Rutt-ID att boka (från PlanRoute).',
          },
          'passengers': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'type': {
                  'type': 'string',
                  'enum': ['adult', 'child', 'senior', 'youth'],
                  'description': 'Passagerartyp.',
                },
                'needs_wheelchair': {
                  'type': 'boolean',
                  'description': 'Behöver rullstolsplats.',
                },
              },
              'required': ['type'],
            },
            'description': 'Lista med passagerare.',
          },
          'email': {
            'type': 'string',
            'description': 'E-postadress för kvitto (valfritt).',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                'Måste vara true för att genomföra bokning. '
                'Användaren ska bekräfta innan detta sätts till true.',
          },
        },
        'required': ['route_id', 'passengers', 'confirmed'],
      };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final routeId = args['route_id']?.toString() ?? '';
    final confirmed = args['confirmed'] as bool? ?? false;
    final email = args['email']?.toString();

    if (!confirmed) {
      // Returnera förhandsvisning utan att boka
      final route = await _resolveRoute(routeId);
      if (route == null) {
        return {'error': 'Rutt $routeId hittades inte. Kör PlanRoute igen.'};
      }
      final passengers = _parsePassengers(args['passengers']);
      final price = _estimatePrice(passengers);
      return {
        'preview': true,
        'route_id': routeId,
        'departure': route.departure?.toIso8601String(),
        'arrival': route.arrival?.toIso8601String(),
        'duration_minutes': route.totalDuration.inMinutes,
        'transfers': route.transfers,
        'passengers': passengers.map((p) => {
              'type': p.type.name,
              'label': p.label,
              'needs_wheelchair': p.needsWheelchairSpace,
            }).toList(),
        'estimated_price_sek': price,
        'message':
            'Visa detta för användaren och be om bekräftelse innan bokning.',
        'cancellation_note':
            'Avbokning möjlig upp till 30 minuter före avgång.',
      };
    }

    _log.fine('BookTicket: routeId=$routeId bekräftad=true');
    final route = await _resolveRoute(routeId);
    if (route == null) {
      return {'error': 'Rutt $routeId hittades inte. Kör PlanRoute igen.'};
    }

    final passengers = _parsePassengers(args['passengers']);
    final request = BookingRequest(
      route: route,
      passengers: passengers,
      email: email,
    );

    try {
      final booking = await _booking.book(request);
      onBooking?.call(booking);
      return {
        'reference': booking.reference,
        'status': booking.status.name,
        'total_price_sek': booking.totalPrice,
        'currency': booking.currency,
        'passengers': booking.passengers.map((p) => p.label).toList(),
        'departure': booking.route.departure?.toIso8601String(),
        'arrival': booking.route.arrival?.toIso8601String(),
        'booked_at': booking.bookedAt.toIso8601String(),
        'cancellation_deadline': booking.cancellationDeadline?.toIso8601String(),
        'message': 'Bokning bekräftad! Referensnummer: ${booking.reference}',
      };
    } catch (e) {
      return {'error': 'Bokning misslyckades: $e'};
    }
  }

  List<Passenger> _parsePassengers(dynamic raw) {
    final list = raw as List<dynamic>? ?? [];
    return list.map((p) {
      final pm = p as Map<String, dynamic>;
      final typeStr = pm['type']?.toString() ?? 'adult';
      final type = PassengerType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => PassengerType.adult,
      );
      return Passenger(
        type: type,
        needsWheelchairSpace: pm['needs_wheelchair'] as bool? ?? false,
      );
    }).toList();
  }

  double _estimatePrice(List<Passenger> passengers) {
    const base = 35.0;
    double total = 0;
    for (final p in passengers) {
      switch (p.type) {
        case PassengerType.adult:
          total += base;
        case PassengerType.child:
          total += base * 0.5;
        case PassengerType.senior:
          total += base * 0.7;
        case PassengerType.youth:
          total += base * 0.6;
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }
}
