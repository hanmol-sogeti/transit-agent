/// Riverpod-providers för ReseAgenten
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../mcp/mcp_client.dart';
import '../services/azure_openai_service.dart';
import '../services/trafiklab_service.dart';
import '../services/routing_service.dart';
import '../services/location_service.dart';
import '../services/booking_service.dart';

// ─── Tjänste-providers ───────────────────────────────────────────────────────

final trafiklabServiceProvider = Provider<TrafiklabService>(
  (ref) {
    final service = TrafiklabService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final azureOpenAiServiceProvider = Provider<AzureOpenAiService>(
  (ref) {
    final service = AzureOpenAiService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final routingServiceProvider = Provider<RoutingService>(
  (ref) {
    final service = RoutingService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final bookingServiceProvider = Provider<BookingService>(
  (ref) => BookingService(),
);

final mcpClientProvider = Provider<McpClient>(
  (ref) => McpClient(
    openAi: ref.watch(azureOpenAiServiceProvider),
    trafiklab: ref.watch(trafiklabServiceProvider),
    location: ref.watch(locationServiceProvider),
    booking: ref.watch(bookingServiceProvider),
  ),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override sharedPreferencesProvider'),
);

// ─── Användarprofil-provider ────────────────────────────────────────────────────────────

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final s = prefs.getString('user_profile');
    if (s == null) {
      // Demo-standardprofil
      return const UserProfile(
        name: 'Jon Doe',
        homeAddress: 'Dragabrunsgatan 45, Uppsala',
      );
    }
    return UserProfile.fromJsonString(s);
  }

  Future<void> save(UserProfile profile) async {
    state = profile;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('user_profile', profile.toJsonString());
    // Uppdatera systemmeddelandet i MCP-klienten omedelbart
    ref.read(mcpClientProvider).setUserProfile(profile);
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfile>(UserProfileNotifier.new);


class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    // Synkronisera användarprofil i MCP-klienten vid init (en gång)
    // Använd read (inte watch) för att undvika att chatt-historiken raderas
    // när profilen uppdateras.
    final profile = ref.read(userProfileProvider);
    ref.read(mcpClientProvider).setUserProfile(profile);
    return [];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final client = ref.read(mcpClientProvider);

    // Optimistisk uppdatering: lägg till ett "laddar" meddelande
    final loadingMsg = ChatMessage(
      id: 'loading',
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      isLoading: true,
    );
    state = [...client.history, loadingMsg];

    // Spara ruttcache-storlek innan anrop för att detektera nya rutter
    final routesBefore = client.cachedRoutes.map((r) => r.id).toSet();

    try {
      await client.sendMessage(text, onToolCall: (call) {
        // Uppdatera UI med verktygskörning
        state = [...client.history, loadingMsg];
      });
      state = List<ChatMessage>.from(client.history);

      // Auto-visa karta och bifoga rutter till assistant-meddelandet
      final newRoutes = client.cachedRoutes
          .where((r) => !routesBefore.contains(r.id))
          .toList();
      if (newRoutes.isNotEmpty) {
        // Bifoga rutter till sista assistant-meddelandet för inline-visning
        final msgs = List<ChatMessage>.from(state);
        final lastAsstIdx = msgs.lastIndexWhere(
          (m) => m.role == ChatRole.assistant && !m.isLoading,
        );
        if (lastAsstIdx >= 0) {
          msgs[lastAsstIdx] = msgs[lastAsstIdx].copyWith(routes: newRoutes);
          state = msgs;
        }
        ref.read(latestRoutesProvider.notifier).state = newRoutes;
        ref.read(selectedLegIndexProvider.notifier).state = null;
        // Visa karta i sidopanelen också
        ref.read(mapProvider.notifier).showRoute(newRoutes.first);
      }
    } catch (e) {
      final msg = e is OpenAiException ? e.message : e.toString();
      final errorMsg = ChatMessage(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        role: ChatRole.assistant,
        content: msg,
        timestamp: DateTime.now(),
        errorMessage: e.toString(),
      );
      state = [...client.history, errorMsg];
    }
  }

  void clearHistory() {
    ref.read(mcpClientProvider).clearHistory();
    ref.read(latestRoutesProvider.notifier).state = [];
    state = [];
  }
}

final chatProvider =
    NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

// ─── Latest routes provider (from most recent PlanRoute call) ────────────────

final latestRoutesProvider = StateProvider<List<TransitRoute>>(
  (ref) => [],
);

// ─── Selected leg index (for map highlight) ──────────────────────────────────

final selectedLegIndexProvider = StateProvider<int?>(
  (ref) => null,
);

// ─── Debug-panel provider ────────────────────────────────────────────────────

final toolCallLogProvider = Provider<List<McpToolCall>>(
  (ref) => ref.watch(mcpClientProvider).toolCallLog,
);

// ─── Onboarding-provider ─────────────────────────────────────────────────────

final onboardingDoneProvider = StateProvider<bool>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool('onboarding_done') ?? false;
  },
);

// ─── Kart-state provider ─────────────────────────────────────────────────────

class MapState {
  const MapState({
    this.route,
    this.center,
    this.zoom = 13.0,
    this.isVisible = false,
  });

  final TransitRoute? route;
  final LatLng? center;
  final double zoom;
  final bool isVisible;

  MapState copyWith({
    TransitRoute? route,
    LatLng? center,
    double? zoom,
    bool? isVisible,
  }) =>
      MapState(
        route: route ?? this.route,
        center: center ?? this.center,
        zoom: zoom ?? this.zoom,
        isVisible: isVisible ?? this.isVisible,
      );
}

class MapNotifier extends Notifier<MapState> {
  @override
  MapState build() => const MapState();

  void showRoute(TransitRoute route, {LatLng? center, double zoom = 13.0}) {
    state = MapState(
      route: route,
      center: center ?? route.origin?.position,
      zoom: zoom,
      isVisible: true,
    );
  }

  void hide() {
    state = state.copyWith(isVisible: false);
  }

  void updateZoom(double zoom) {
    state = state.copyWith(zoom: zoom);
  }
}

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

// ─── Boknings-state provider ─────────────────────────────────────────────────

final bookingListProvider = Provider<List<Booking>>(
  (ref) => ref.watch(bookingServiceProvider).sessionBookings,
);

final latestBookingProvider = Provider<Booking?>(
  (ref) => ref.watch(bookingServiceProvider).latestBooking,
);
