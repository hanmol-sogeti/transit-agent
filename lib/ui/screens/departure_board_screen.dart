/// Live avgångstavla – söker hållplats och visar realtidsavgångar
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/trafiklab_service.dart';
import '../../ui/theme/app_theme.dart';

final _timeFmt = DateFormat('HH:mm');

class DepartureBoardScreen extends ConsumerStatefulWidget {
  const DepartureBoardScreen({super.key});

  @override
  ConsumerState<DepartureBoardScreen> createState() =>
      _DepartureBoardScreenState();
}

class _DepartureBoardScreenState
    extends ConsumerState<DepartureBoardScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  List<Stop> _stopSuggestions = [];
  Stop? _selectedStop;
  List<RealtimeDeparture> _departures = [];

  bool _loadingStops = false;
  bool _loadingDepartures = false;
  String? _error;
  Timer? _refreshTimer;
  Timer? _debounce;
  DateTime _lastRefresh = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _refreshTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  TrafiklabService get _svc => ref.read(trafiklabServiceProvider);

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _stopSuggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _searchStops(q));
  }

  Future<void> _searchStops(String q) async {
    setState(() => _loadingStops = true);
    try {
      final stops = await _svc.searchLocation(q);
      if (mounted) setState(() => _stopSuggestions = stops);
    } catch (_) {
      if (mounted) setState(() => _stopSuggestions = []);
    } finally {
      if (mounted) setState(() => _loadingStops = false);
    }
  }

  Future<void> _selectStop(Stop stop) async {
    _refreshTimer?.cancel();
    setState(() {
      _selectedStop = stop;
      _stopSuggestions = [];
      _searchController.text = stop.name;
      _focusNode.unfocus();
    });
    await _fetchDepartures();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchDepartures(),
    );
  }

  Future<void> _fetchDepartures() async {
    if (_selectedStop == null) return;
    setState(() {
      _loadingDepartures = true;
      _error = null;
    });
    try {
      final deps = await _svc.departures(
        _selectedStop!.id,
        maxResults: 30,
      );
      if (mounted) {
        setState(() {
          _departures = deps;
          _lastRefresh = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDepartures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avgångstavla'),
        backgroundColor: AppTheme.brandBlue,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          if (_selectedStop != null && _loadingDepartures)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else if (_selectedStop != null)
            IconButton(
              onPressed: _fetchDepartures,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Uppdatera',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Sökfält ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.cardColor,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Sök hållplats…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _loadingStops
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _stopSuggestions = [];
                                _selectedStop = null;
                                _departures = [];
                              });
                            },
                          )
                        : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // ── Förslag ───────────────────────────────────────────────────
          if (_stopSuggestions.isNotEmpty)
            Container(
              color: theme.cardColor,
              child: Column(
                children: [
                  const Divider(height: 1),
                  ..._stopSuggestions.map(
                    (s) => ListTile(
                      leading: Icon(
                        _stopIcon(s.stopType),
                        color: AppTheme.brandBlue,
                        size: 20,
                      ),
                      title: Text(s.name),
                      subtitle: s.distanceMeters != null
                          ? Text('${s.distanceMeters!.toInt()} m')
                          : null,
                      dense: true,
                      onTap: () => _selectStop(s),
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),

          // ── Avgångar ──────────────────────────────────────────────────
          Expanded(
            child: _buildBody(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThemeData theme) {
    if (_selectedStop == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.departure_board_rounded,
              size: 64,
              color: AppTheme.brandBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'Sök en hållplats ovan',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Realtidsavgångar uppdateras var 30:e sekund.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 40, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _fetchDepartures,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Försök igen'),
            ),
          ],
        ),
      );
    }

    if (_loadingDepartures && _departures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_departures.isEmpty) {
      return Center(
        child: Text(
          'Inga avgångar hittades för ${_selectedStop!.name}.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                _stopIcon(_selectedStop!.stopType),
                size: 18,
                color: AppTheme.brandBlue,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedStop!.name,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                'Uppdaterad ${_timeFmt.format(_lastRefresh)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _departures.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 56),
            itemBuilder: (ctx, i) =>
                _DepartureRow(departure: _departures[i]),
          ),
        ),
      ],
    );
  }

  IconData _stopIcon(StopType type) {
    switch (type) {
      case StopType.trainStation:
        return Icons.train_rounded;
      case StopType.tramStop:
        return Icons.tram_rounded;
      case StopType.ferryTerminal:
        return Icons.directions_boat_rounded;
      default:
        return Icons.directions_bus_rounded;
    }
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.departure});
  final RealtimeDeparture departure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dep = departure;
    final now = DateTime.now();
    final effectiveTime = dep.expectedTime ?? dep.scheduledTime;
    final minsAway = effectiveTime.difference(now).inMinutes;

    Color lineColor = AppTheme.modeColor('bus');
    final mode = _guessMode(dep.line);
    lineColor = AppTheme.modeColor(mode);

    Color timeColor;
    String timeLabel;
    if (dep.cancelled) {
      timeColor = AppTheme.errorColor;
      timeLabel = 'Inställd';
    } else if (minsAway <= 0) {
      timeColor = AppTheme.warningColor;
      timeLabel = 'Nu';
    } else if (minsAway < 60) {
      timeColor = minsAway < 5
          ? AppTheme.warningColor
          : theme.colorScheme.onSurface;
      timeLabel = '$minsAway min';
    } else {
      timeColor = theme.colorScheme.onSurface;
      timeLabel = _timeFmt.format(effectiveTime);
    }

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: lineColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: lineColor.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Text(
          dep.line,
          style: TextStyle(
            fontSize: dep.line.length > 3 ? 9 : 12,
            fontWeight: FontWeight.w800,
            color: lineColor,
          ),
        ),
      ),
      title: Text(
        dep.direction,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: dep.platform != null
          ? Text(
              'Plattform ${dep.platform}',
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            timeLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: timeColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dep.isDelayed)
            Text(
              _timeFmt.format(dep.scheduledTime),
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }

  String _guessMode(String line) {
    final num = int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
    if (line.toUpperCase().startsWith('T')) { return 'tram'; }
    if (line.toUpperCase().startsWith('J') ||
        line.toUpperCase().startsWith('R') ||
        line.toUpperCase().startsWith('X')) { return 'train'; }
    if (num != null && num >= 100) { return 'train'; }
    return 'bus';
  }
}
