import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/poi.dart';
import '../../models/trail.dart';
import '../../providers/poi_provider.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../services/map_offline_service.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../home/home_screen.dart';

class TrailNavigationScreen extends StatefulWidget {
  final Trail trail;

  const TrailNavigationScreen({
    super.key,
    required this.trail,
  });

  @override
  State<TrailNavigationScreen> createState() => _TrailNavigationScreenState();
}

class _TrailNavigationScreenState extends State<TrailNavigationScreen> {
  static const Distance _distance = Distance();

  StreamSubscription<Position>? _positionSub;
  final MapController _mapController = MapController();

  LatLng? _current;
  bool _offTrailAlert = false;
  List<Poi> _nearbyPois = [];

  LatLng? get _trailStart {
    final lat = widget.trail.startLatitude;
    final lng = widget.trail.startLongitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  List<LatLng> get _trailPoints {
    final points = <LatLng>[];
    if (widget.trail.geojson != null) {
      try {
        final features = widget.trail.geojson!['features'] as List;
        if (features.isNotEmpty) {
          final geometry = features[0]['geometry'];
          if (geometry['type'] == 'LineString') {
            final coords = geometry['coordinates'] as List;
            for (var coord in coords) {
              points.add(LatLng(coord[1], coord[0]));
            }
          }
        }
      } catch (_) {}
    }
    if (points.isEmpty && _trailStart != null) {
      points.add(_trailStart!);
    }
    return points;
  }

  @override
  void initState() {
    super.initState();
    _initializeNavigation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeNavigation() async {
    final poiProvider = context.read<PoiProvider>();
    await poiProvider.loadPois(trailId: widget.trail.id);

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen((position) {
      final current = LatLng(position.latitude, position.longitude);
      final nearby = poiProvider.pois.where((poi) {
        final poiPoint = LatLng(poi.latitude, poi.longitude);
        return _distance.as(LengthUnit.Meter, current, poiPoint) <= 350;
      }).toList();

      final target = _trailStart;
      final offTrail = target == null
          ? false
          : _distance.as(LengthUnit.Meter, current, target) > 800;

      if (!mounted) return;
      setState(() {
        _current = current;
        _nearbyPois = nearby;
        _offTrailAlert = offTrail;
      });

      _mapController.move(current, 15);
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final target = _trailStart;
    final trailPoints = _trailPoints;

    return Scaffold(
      appBar: const EcoPageHeader(title: 'Navigation & SOS'),
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.map,
        onTabSelected: (tab) {
          final index = switch (tab) {
            EcoShortcutTab.home => 0,
            EcoShortcutTab.map => 1,
            EcoShortcutTab.trails => 2,
            EcoShortcutTab.quiz => 4,
            EcoShortcutTab.services => 6,
            EcoShortcutTab.settings => 7,
          };
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
            (route) => false,
          );
        },
      ),
      body: current == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: current, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                      userAgentPackageName: 'com.ecoguide.app',
                      tileProvider: LocalFirstTileProvider(),
                    ),
                    if (trailPoints.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: trailPoints,
                            strokeWidth: 5,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: current,
                          width: 36,
                          height: 36,
                          child: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.navigation, color: Colors.white),
                          ),
                        ),
                        if (target != null)
                          Marker(
                            point: target,
                            width: 38,
                            height: 38,
                            child: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.flag, color: Colors.white),
                            ),
                          ),
                        ..._nearbyPois.map((poi) => _buildPoiMarker(poi)),
                      ],
                    ),
                  ],
                ),
                _buildTopDirectionCard(current, target),
                if (_offTrailAlert) _buildOffTrailAlert(),
                _buildNearbyPoiCard(),
                _buildBottomStats(current, target),
              ],
            ),
    );
  }

  Marker _buildPoiMarker(Poi poi) {
    return Marker(
      point: LatLng(poi.latitude, poi.longitude),
      width: 30,
      height: 30,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF101418),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.place, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildTopDirectionCard(LatLng current, LatLng? target) {
    final meter = target == null
        ? 0.0
        : _distance.as(LengthUnit.Meter, current, target);
    final rounded = meter > 1000 ? '${(meter / 1000).toStringAsFixed(1)} km' : '${meter.toStringAsFixed(0)} m';

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        color: const Color(0xFF4CAF50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFF2E7D32),
                child: Icon(Icons.turn_right, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rounded,
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Continuer sur le sentier principal',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOffTrailAlert() {
    return Positioned(
      top: 90,
      left: 16,
      right: 16,
      child: Card(
        color: const Color(0xFFFFEBEE),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Off-Trail Alert: vous etes eloigne du trajet recommande.'),
              ),
              FilledButton(
                onPressed: () {
                  if (_current != null) {
                    _mapController.move(_current!, 16);
                  }
                },
                child: const Text('Re-route'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyPoiCard() {
    if (_nearbyPois.isEmpty) {
      return const SizedBox.shrink();
    }

    final poi = _nearbyPois.first;
    return Positioned(
      left: 16,
      right: 16,
      bottom: 130,
      child: Card(
        color: const Color(0xFF1A1A1A),
        child: ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.park),
          ),
          title: Text(poi.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            poi.typeDisplayName,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: const Icon(Icons.radar, color: Colors.greenAccent),
        ),
      ),
    );
  }

  Widget _buildBottomStats(LatLng current, LatLng? target) {
    final meter = target == null
        ? 0.0
        : _distance.as(LengthUnit.Meter, current, target);
    final km = meter / 1000;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Card(
        color: const Color(0xFF151C22),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metric('1h 15m', 'Restant'),
                  _metric('${km.toStringAsFixed(1)} km', 'Distance'),
                  _metric('4.2 km/h', 'Allure'),
                  _metric('+120m', 'Elevation'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.flag),
                      label: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
