import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/local_service.dart';
import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/local_service_provider.dart';
import '../../providers/poi_provider.dart';
import '../../providers/trail_provider.dart';
import '../poi/poi_detail_screen.dart';
import '../services/local_service_detail_screen.dart';
import '../trails/trail_detail_screen.dart';

class MapSearchResultsScreen extends StatefulWidget {
  final LatLng currentPosition;

  const MapSearchResultsScreen({
    super.key,
    required this.currentPosition,
  });

  @override
  State<MapSearchResultsScreen> createState() => _MapSearchResultsScreenState();
}

class _MapSearchResultsScreenState extends State<MapSearchResultsScreen> {
  static const Distance _distance = Distance();

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  _SearchCategory _category = _SearchCategory.all;
  List<_SearchItem> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadResults();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadResults);
  }

  Future<void> _loadResults() async {
    final trailProvider = context.read<TrailProvider>();
    final poiProvider = context.read<PoiProvider>();
    final localServiceProvider = context.read<LocalServiceProvider>();

    final rawQuery = _searchController.text.trim();
    final query = rawQuery.isEmpty ? null : rawQuery;

    setState(() => _isLoading = true);
    await Future.wait([
      trailProvider.loadTrails(refresh: true, search: query),
      poiProvider.loadPois(search: query),
      localServiceProvider.loadServices(search: query),
    ]);

    final newItems = <_SearchItem>[];

    for (final trail in trailProvider.trails) {
      if (trail.startLatitude == null || trail.startLongitude == null) continue;
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        widget.currentPosition,
        LatLng(trail.startLatitude!, trail.startLongitude!),
      );
      newItems.add(
        _SearchItem(
          type: _SearchCategory.trail,
          name: trail.name,
          subtitle: trail.description,
          distanceKm: distanceKm,
          icon: Icons.hiking,
          trail: trail,
        ),
      );
    }

    for (final poi in poiProvider.pois) {
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        widget.currentPosition,
        LatLng(poi.latitude, poi.longitude),
      );
      newItems.add(
        _SearchItem(
          type: _SearchCategory.poi,
          name: poi.name,
          subtitle: poi.typeDisplayName,
          distanceKm: distanceKm,
          icon: Icons.place,
          poi: poi,
        ),
      );
    }

    for (final service in localServiceProvider.services) {
      if (service.latitude == null || service.longitude == null) continue;
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        widget.currentPosition,
        LatLng(service.latitude!, service.longitude!),
      );
      newItems.add(
        _SearchItem(
          type: _SearchCategory.service,
          name: service.name,
          subtitle: service.categoryDisplayName,
          distanceKm: distanceKm,
          icon: Icons.storefront,
          service: service,
        ),
      );
    }

    newItems.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    if (!mounted) return;
    setState(() {
      _items = newItems;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((item) {
      if (_category == _SearchCategory.all) return true;
      return item.type == _category;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Recherche Carte')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search trail, POI, service...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _loadResults();
                        },
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _categoryChip('All', _SearchCategory.all),
                _categoryChip('Trail', _SearchCategory.trail),
                _categoryChip('POI', _SearchCategory.poi),
                _categoryChip('Service', _SearchCategory.service),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No result found'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(child: Icon(item.icon)),
                            title: Text(item.name),
                            subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text('${item.distanceKm.toStringAsFixed(1)} km'),
                            onTap: () => _openItem(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, _SearchCategory value) {
    final selected = _category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _category = value),
      ),
    );
  }

  void _openItem(_SearchItem item) {
    switch (item.type) {
      case _SearchCategory.trail:
        if (item.trail == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TrailDetailScreen(trail: item.trail!)),
        );
        return;
      case _SearchCategory.poi:
        if (item.poi == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(poi: item.poi!)),
        );
        return;
      case _SearchCategory.service:
        if (item.service == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LocalServiceDetailScreen(
              serviceId: item.service!.id,
              fallbackService: item.service!,
            ),
          ),
        );
        return;
      case _SearchCategory.all:
        return;
    }
  }
}

enum _SearchCategory { all, trail, poi, service }

class _SearchItem {
  final _SearchCategory type;
  final String name;
  final String subtitle;
  final double distanceKm;
  final IconData icon;
  final Trail? trail;
  final Poi? poi;
  final LocalService? service;

  _SearchItem({
    required this.type,
    required this.name,
    required this.subtitle,
    required this.distanceKm,
    required this.icon,
    this.trail,
    this.poi,
    this.service,
  });
}
