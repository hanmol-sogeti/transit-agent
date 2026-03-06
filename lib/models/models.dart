/// Kärnmodeller för ReseAgenten
library;

import 'dart:convert';
import 'package:latlong2/latlong.dart';

// ─── UserProfile ─────────────────────────────────────────────────────────────

class UserProfile {
  const UserProfile({
    this.name = '',
    this.homeAddress = '',
    this.homeStopId,
  });

  final String name;
  final String homeAddress;
  final String? homeStopId;

  bool get hasProfile => name.isNotEmpty || homeAddress.isNotEmpty;

  UserProfile copyWith({
    String? name,
    String? homeAddress,
    String? homeStopId,
  }) =>
      UserProfile(
        name: name ?? this.name,
        homeAddress: homeAddress ?? this.homeAddress,
        homeStopId: homeStopId ?? this.homeStopId,
      );

  static UserProfile fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        homeAddress: json['homeAddress'] as String? ?? '',
        homeStopId: json['homeStopId'] as String?,
      );

  static UserProfile fromJsonString(String s) {
    try {
      return UserProfile.fromJson(
          jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const UserProfile();
    }
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'homeAddress': homeAddress,
        if (homeStopId != null) 'homeStopId': homeStopId,
      };

  String toJsonString() => jsonEncode(toJson());
}

// ─── Stop ────────────────────────────────────────────────────────────────────
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.position,
    this.distanceMeters,
    this.platforms = const [],
    this.accessible = false,
    this.stopType = StopType.busStop,
  });

  final String id;
  final String name;
  final LatLng position;
  final double? distanceMeters;
  final List<String> platforms;
  final bool accessible;
  final StopType stopType;

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        id: json['gid'] as String? ?? json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        position: LatLng(
          (json['lat'] as num?)?.toDouble() ??
              (json['latitude'] as num?)?.toDouble() ??
              0.0,
          (json['lon'] as num?)?.toDouble() ??
              (json['longitude'] as num?)?.toDouble() ??
              0.0,
        ),
        distanceMeters: (json['distance'] as num?)?.toDouble(),
        accessible: json['wheelchair'] == true || json['accessible'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': position.latitude,
        'lon': position.longitude,
        if (distanceMeters != null) 'distance': distanceMeters,
        'accessible': accessible,
        'stopType': stopType.name,
      };
}

enum StopType { busStop, trainStation, tramStop, ferryTerminal, unknown }

// ─── Leg ─────────────────────────────────────────────────────────────────────

class Leg {
  const Leg({
    required this.origin,
    required this.destination,
    required this.departure,
    required this.arrival,
    required this.mode,
    this.line,
    this.direction,
    this.platform,
    this.geometry = const [],
    this.realtime = false,
    this.delayMinutes = 0,
  });

  final Stop origin;
  final Stop destination;
  final DateTime departure;
  final DateTime arrival;
  final TransportMode mode;
  final String? line;
  final String? direction;
  final String? platform;
  final List<LatLng> geometry;
  final bool realtime;
  final int delayMinutes;

  Duration get duration => arrival.difference(departure);

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'departure': departure.toIso8601String(),
        'arrival': arrival.toIso8601String(),
        'mode': mode.name,
        if (line != null) 'line': line,
        if (direction != null) 'direction': direction,
        if (platform != null) 'platform': platform,
        'realtime': realtime,
        'delayMinutes': delayMinutes,
      };
}

enum TransportMode { walk, bus, train, tram, subway, ferry, unknown }

// ─── Route ───────────────────────────────────────────────────────────────────

class TransitRoute {
  const TransitRoute({
    required this.id,
    required this.legs,
    required this.totalDuration,
    required this.transfers,
    this.price,
    this.co2Grams,
    this.accessibilityNote,
  });

  final String id;
  final List<Leg> legs;
  final Duration totalDuration;
  final int transfers;
  final double? price;
  final double? co2Grams;
  final String? accessibilityNote;

  DateTime? get departure =>
      legs.isNotEmpty ? legs.first.departure : null;
  DateTime? get arrival =>
      legs.isNotEmpty ? legs.last.arrival : null;
  Stop? get origin =>
      legs.isNotEmpty ? legs.first.origin : null;
  Stop? get destination =>
      legs.isNotEmpty ? legs.last.destination : null;
  bool get hasWheelchairAccess => accessibilityNote != null;

  /// Alla geometripunkter för rutten (alla etapper sammanslagna).
  List<LatLng> get fullGeometry =>
      legs.expand((l) => l.geometry).toList();

  String get durationLabel {
    final h = totalDuration.inHours;
    final m = totalDuration.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}min';
    return '${m}min';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'legs': legs.map((l) => l.toJson()).toList(),
        'totalDurationMinutes': totalDuration.inMinutes,
        'transfers': transfers,
        if (price != null) 'price': price,
        'departure': departure?.toIso8601String(),
        'arrival': arrival?.toIso8601String(),
      };
}

// ─── Booking ─────────────────────────────────────────────────────────────────

class BookingRequest {
  const BookingRequest({
    required this.route,
    required this.passengers,
    this.email,
    this.phoneNumber,
  });

  final TransitRoute route;
  final List<Passenger> passengers;
  final String? email;
  final String? phoneNumber;
}

class Passenger {
  const Passenger({
    required this.type,
    this.name,
    this.age,
    this.needsWheelchairSpace = false,
  });

  final PassengerType type;
  final String? name;
  final int? age;
  final bool needsWheelchairSpace;

  String get label {
    switch (type) {
      case PassengerType.adult:
        return 'Vuxen';
      case PassengerType.child:
        return 'Barn';
      case PassengerType.senior:
        return 'Senior';
      case PassengerType.youth:
        return 'Ungdom';
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        'needsWheelchairSpace': needsWheelchairSpace,
      };
}

enum PassengerType { adult, child, senior, youth }

class Booking {
  const Booking({
    required this.reference,
    required this.route,
    required this.passengers,
    required this.bookedAt,
    required this.totalPrice,
    required this.currency,
    this.email,
    this.cancellationDeadline,
    this.status = BookingStatus.confirmed,
  });

  final String reference;
  final TransitRoute route;
  final List<Passenger> passengers;
  final DateTime bookedAt;
  final double totalPrice;
  final String currency;
  final String? email;
  final DateTime? cancellationDeadline;
  final BookingStatus status;

  String get formattedPrice =>
      '${totalPrice.toStringAsFixed(2)} $currency';

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'route': route.toJson(),
        'passengers': passengers.map((p) => p.toJson()).toList(),
        'bookedAt': bookedAt.toIso8601String(),
        'totalPrice': totalPrice,
        'currency': currency,
        if (email != null) 'email': email,
        if (cancellationDeadline != null)
          'cancellationDeadline': cancellationDeadline!.toIso8601String(),
        'status': status.name,
      };
}

enum BookingStatus { confirmed, cancelled, pending }

// ─── Chat message ─────────────────────────────────────────────────────────────

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls = const [],
    this.isLoading = false,
    this.errorMessage,
    this.routes,
    this.suggestions,
    this.booking,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<McpToolCall> toolCalls;
  final bool isLoading;
  final String? errorMessage;
  final List<TransitRoute>? routes;
  /// AI-generated or fallback follow-up action chips.
  final List<String>? suggestions;
  /// Confirmed booking attached to this message (shown as inline ticket).
  final Booking? booking;

  ChatMessage copyWith({
    String? content,
    bool? isLoading,
    String? errorMessage,
    List<McpToolCall>? toolCalls,
    List<TransitRoute>? routes,
    List<String>? suggestions,
    Booking? booking,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        timestamp: timestamp,
        toolCalls: toolCalls ?? this.toolCalls,
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage ?? this.errorMessage,
        routes: routes ?? this.routes,
        suggestions: suggestions ?? this.suggestions,
        booking: booking ?? this.booking,
      );
}

enum ChatRole { user, assistant, system, tool }

// ─── MCP tool call ────────────────────────────────────────────────────────────

class McpToolCall {
  const McpToolCall({
    required this.toolName,
    required this.arguments,
    this.result,
    this.durationMs,
    this.error,
  });

  final String toolName;
  final Map<String, dynamic> arguments;
  final Map<String, dynamic>? result;
  final int? durationMs;
  final String? error;

  bool get succeeded => error == null;

  Map<String, dynamic> toJson() => {
        'toolName': toolName,
        'arguments': arguments,
        if (result != null) 'result': result,
        if (durationMs != null) 'durationMs': durationMs,
        if (error != null) 'error': error,
      };
}

// ─── Realtime departure ───────────────────────────────────────────────────────

class RealtimeDeparture {
  const RealtimeDeparture({
    required this.line,
    required this.direction,
    required this.scheduledTime,
    required this.stop,
    this.expectedTime,
    this.delayMinutes = 0,
    this.cancelled = false,
    this.platform,
    this.journeyId,
  });

  final String line;
  final String direction;
  final DateTime scheduledTime;
  final Stop stop;
  final DateTime? expectedTime;
  final int delayMinutes;
  final bool cancelled;
  final String? platform;
  final String? journeyId;

  bool get isOnTime => delayMinutes == 0;
  bool get isDelayed => delayMinutes > 0;

  String get delayLabel {
    if (cancelled) return 'Inställd';
    if (delayMinutes <= 0) return 'I tid';
    return '+${delayMinutes}min försenad';
  }

  Map<String, dynamic> toJson() => {
        'line': line,
        'direction': direction,
        'scheduledTime': scheduledTime.toIso8601String(),
        'stop': stop.toJson(),
        if (expectedTime != null)
          'expectedTime': expectedTime!.toIso8601String(),
        'delayMinutes': delayMinutes,
        'cancelled': cancelled,
        if (platform != null) 'platform': platform,
      };
}
