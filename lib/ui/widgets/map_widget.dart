/// Kartwidget med flutter_map och OpenStreetMap
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../config/env_config.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

class RouteMapWidget extends ConsumerWidget {
  const RouteMapWidget({
    super.key,
    this.route,
    this.center,
    this.zoom = 13.0,
    this.compact = false,
  });

  final TransitRoute? route;
  final LatLng? center;
  final double zoom;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveRoute = route ?? ref.watch(mapProvider).route;
    final effectiveCenter = center ??
        ref.watch(mapProvider).center ??
        const LatLng(59.8586, 17.6389); // Uppsala centrum
    final effectiveZoom =
        center != null ? zoom : ref.watch(mapProvider).zoom;
    final selectedLegIndex =
        compact ? null : ref.watch(selectedLegIndexProvider);

    final tileUrl = EnvConfig.instance.mapTileEndpoint;
    final attribution = EnvConfig.instance.mapAttribution;

    return ClipRRect(
      borderRadius:
          compact ? BorderRadius.circular(10) : BorderRadius.zero,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: effectiveCenter,
          initialZoom: effectiveZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          // ── OSM tile layer ────────────────────────────────────────────
          TileLayer(
            urlTemplate: tileUrl,
            subdomains: tileUrl.contains('{s}') ? const ['a', 'b', 'c'] : const [],
            userAgentPackageName: 'com.resaagenten.transit_agent',
            retinaMode: false,
          ),

          // ── Rutt-polylinjer ───────────────────────────────────────────
          if (effectiveRoute != null)
            PolylineLayer(
              polylines:
                  _buildPolylines(effectiveRoute, selectedLegIndex),
            ),

          // ── Markörer ──────────────────────────────────────────────────
          if (effectiveRoute != null)
            MarkerLayer(
              markers: _buildMarkers(context, effectiveRoute),
            ),

          // ── Attribution ───────────────────────────────────────────────
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(attribution),
            ],
          ),
        ],
      ),
    );
  }

  List<Polyline> _buildPolylines(
      TransitRoute route, int? selectedLegIndex) {
    final polylines = <Polyline>[];
    for (var i = 0; i < route.legs.length; i++) {
      final leg = route.legs[i];
      final points = leg.geometry.isNotEmpty
          ? leg.geometry
          : [leg.origin.position, leg.destination.position];
      final color = AppTheme.modeColor(leg.mode.name);
      final isHighlighted =
          selectedLegIndex == null || selectedLegIndex == i;
      final opacity = isHighlighted ? 1.0 : 0.25;
      final strokeWidth = isHighlighted
          ? (leg.mode == TransportMode.walk ? 4.0 : 6.0)
          : 3.0;
      polylines.add(Polyline(
        points: points,
        strokeWidth: strokeWidth,
        color: leg.mode == TransportMode.walk
            ? color.withValues(alpha: 0.7 * opacity)
            : color.withValues(alpha: opacity),
        pattern: leg.mode == TransportMode.walk
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
      ));
    }
    return polylines;
  }

  List<Marker> _buildMarkers(BuildContext context, TransitRoute route) {
    final markers = <Marker>[];
    if (route.origin != null) {
      markers.add(_buildMarker(
        route.origin!.position,
        Icons.trip_origin_rounded,
        AppTheme.successColor,
        route.origin!.name,
        context,
      ));
    }
    if (route.destination != null) {
      markers.add(_buildMarker(
        route.destination!.position,
        Icons.location_on_rounded,
        AppTheme.errorColor,
        route.destination!.name,
        context,
      ));
    }
    // Mellanstationer (byten)
    for (var i = 1; i < route.legs.length; i++) {
      final leg = route.legs[i];
      if (leg.mode != TransportMode.walk) {
        markers.add(_buildTransferMarker(leg.origin.position, context));
      }
    }
    return markers;
  }

  Marker _buildMarker(
    LatLng pos,
    IconData icon,
    Color color,
    String label,
    BuildContext context,
  ) =>
      Marker(
        point: pos,
        width: 36,
        height: 36,
        child: Tooltip(
          message: label,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      );

  Marker _buildTransferMarker(LatLng pos, BuildContext context) => Marker(
        point: pos,
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.brandBlue,
              width: 2,
            ),
          ),
        ),
      );
}

/// Komprimerad kartknapp som öppnar fullskärmsvyn.
class MapPreviewButton extends ConsumerWidget {
  const MapPreviewButton({super.key, required this.route});

  final TransitRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(mapProvider.notifier).showRoute(route),
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          children: [
            RouteMapWidget(route: route, compact: true),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_full_rounded,
                          size: 14, color: AppTheme.brandBlue),
                      SizedBox(width: 4),
                      Text(
                        'Visa karta',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brandBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
