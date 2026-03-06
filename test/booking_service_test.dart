/// Tester för BookingService – bokningslogik, prisberäkning, avbokning
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:transit_agent/models/models.dart';
import 'package:transit_agent/services/booking_service.dart';

// ─── Testhjälpare ────────────────────────────────────────────────────────────

final _stockholm = Stop(
  id: '740000001',
  name: 'Stockholm C',
  position: const LatLng(59.330, 18.059),
);

final _uppsala = Stop(
  id: '740000002',
  name: 'Uppsala C',
  position: const LatLng(59.858, 17.638),
);

Leg _makeLeg({
  required Stop origin,
  required Stop destination,
  required DateTime departure,
  required DateTime arrival,
  TransportMode mode = TransportMode.train,
}) =>
    Leg(
      origin: origin,
      destination: destination,
      departure: departure,
      arrival: arrival,
      mode: mode,
    );

TransitRoute _makeRoute(List<Leg> legs, {String id = 'route-1'}) =>
    TransitRoute(
      id: id,
      legs: legs,
      totalDuration: legs.fold(
        Duration.zero,
        (acc, l) => acc + l.duration,
      ),
      transfers: legs.length - 1,
    );

TransitRoute get _singleLegRoute {
  final dep = DateTime.now().add(const Duration(hours: 2));
  return _makeRoute([
    _makeLeg(
      origin: _stockholm,
      destination: _uppsala,
      departure: dep,
      arrival: dep.add(const Duration(hours: 1, minutes: 5)),
    ),
  ]);
}

TransitRoute get _multiLegRoute {
  final dep = DateTime.now().add(const Duration(hours: 2));
  final mid = dep.add(const Duration(minutes: 40));
  return _makeRoute([
    _makeLeg(
      origin: _stockholm,
      destination: _stockholm,
      departure: dep,
      arrival: mid,
      mode: TransportMode.bus,
    ),
    _makeLeg(
      origin: _stockholm,
      destination: _uppsala,
      departure: mid.add(const Duration(minutes: 10)),
      arrival: mid.add(const Duration(minutes: 50)),
      mode: TransportMode.train,
    ),
  ]);
}

/// Route where the departure has already passed (avbokning inte möjlig).
TransitRoute get _pastDepartureRoute {
  final dep = DateTime.now().subtract(const Duration(hours: 2));
  return _makeRoute([
    _makeLeg(
      origin: _stockholm,
      destination: _uppsala,
      departure: dep,
      arrival: dep.add(const Duration(hours: 1)),
    ),
  ]);
}

// ─── Tester ──────────────────────────────────────────────────────────────────

void main() {
  late BookingService service;

  setUp(() => service = BookingService());

  // ── Validering ─────────────────────────────────────────────────────────────

  group('book() – validering', () {
    test('kastar BookingException när passagerarlistan är tom', () async {
      expect(
        () => service.book(BookingRequest(
          route: _singleLegRoute,
          passengers: [],
        )),
        throwsA(isA<BookingException>()),
      );
    });

    test('BookingException har läsbart felmeddelande', () {
      const e = BookingException('Testfel');
      expect(e.toString(), contains('Testfel'));
      expect(e.toString(), startsWith('BookingException:'));
    });

    test('BookingException är en Exception', () {
      expect(const BookingException('x'), isA<Exception>());
    });
  });

  // ── Bokningsreferens ────────────────────────────────────────────────────────

  group('book() – referens', () {
    test('referens börjar med RA-', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(b.reference, startsWith('RA-'));
    });

    test('referens har 9 tecken (RA- + 6)', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(b.reference.length, 9);
    });

    test('två bokningar får unika referenser', () async {
      final b1 = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      final b2 = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(b1.reference, isNot(equals(b2.reference)));
    });
  });

  // ── Prisberäkning ───────────────────────────────────────────────────────────

  group('book() – prisberäkning', () {
    test('en vuxen: 35 SEK', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(b.totalPrice, 35.0);
      expect(b.currency, 'SEK');
    });

    test('en vuxen + ett barn: 52.50 SEK', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [
          const Passenger(type: PassengerType.adult),
          const Passenger(type: PassengerType.child),
        ],
      ));
      expect(b.totalPrice, 52.5);
    });

    test('senior: 70 % av vuxenpris = 24.50 SEK', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.senior)],
      ));
      expect(b.totalPrice, closeTo(24.5, 0.01));
    });

    test('ungdom: 60 % av vuxenpris = 21 SEK', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.youth)],
      ));
      expect(b.totalPrice, closeTo(21.0, 0.01));
    });

    test('tvåetappsrutt lägger till 10 SEK tillägg', () async {
      final b = await service.book(BookingRequest(
        route: _multiLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      // 35 (adult) + 10 (1 extra transit leg) = 45
      expect(b.totalPrice, 45.0);
    });
  });

  // ── Bokningsstatus ──────────────────────────────────────────────────────────

  group('book() – status och data', () {
    test('bokningsstatus är confirmed', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
        email: 'test@example.com',
      ));
      expect(b.status, BookingStatus.confirmed);
    });

    test('email sparas i bokningen', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
        email: 'kund@example.com',
      ));
      expect(b.email, 'kund@example.com');
    });

    test('avbokningsgräns är 30 min före avgång', () async {
      final route = _singleLegRoute;
      final b = await service.book(BookingRequest(
        route: route,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      final expected = route.departure!.subtract(const Duration(minutes: 30));
      expect(
        b.cancellationDeadline!.difference(expected).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('formattedPrice innehåller SEK', () async {
      final b = await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(b.formattedPrice, contains('SEK'));
      expect(b.formattedPrice, contains('35'));
    });

    test('bokning sparas i sessionBookings', () async {
      expect(service.sessionBookings, isEmpty);
      await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(service.sessionBookings.length, 1);
    });
  });

  // ── Avbokning ───────────────────────────────────────────────────────────────

  group('cancelLatest()', () {
    test('returnerar null när listan är tom', () async {
      expect(await service.cancelLatest(), isNull);
    });

    test('avbokar senaste bokning med status cancelled', () async {
      await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      final cancelled = await service.cancelLatest();
      expect(cancelled, isNotNull);
      expect(cancelled!.status, BookingStatus.cancelled);
    });

    test('kastar BookingException om avbokningsgränsen har passerat', () async {
      await service.book(BookingRequest(
        route: _pastDepartureRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(
        () => service.cancelLatest(),
        throwsA(isA<BookingException>()),
      );
    });

    test('latestBooking returnerar sista bokning', () async {
      expect(service.latestBooking, isNull);
      await service.book(BookingRequest(
        route: _singleLegRoute,
        passengers: [const Passenger(type: PassengerType.adult)],
      ));
      expect(service.latestBooking, isNotNull);
    });
  });

  // ── Passenger.label ─────────────────────────────────────────────────────────

  group('Passenger.label', () {
    test('adult → Vuxen', () {
      expect(
        const Passenger(type: PassengerType.adult).label,
        'Vuxen',
      );
    });
    test('child → Barn', () {
      expect(
        const Passenger(type: PassengerType.child).label,
        'Barn',
      );
    });
    test('senior → Senior', () {
      expect(
        const Passenger(type: PassengerType.senior).label,
        'Senior',
      );
    });
    test('youth → Ungdom', () {
      expect(
        const Passenger(type: PassengerType.youth).label,
        'Ungdom',
      );
    });
  });
}
